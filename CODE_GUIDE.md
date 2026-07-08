# Calender コード解説

## アーキテクチャ概要

```
web/main.dart (2087行)
  └── lib/schedule.dart (169行)  ← データモデル・ビジネスロジック
```

フレームワークを使わず、Dart の `dart:html` ライブラリのみで DOM を直接操作するシングルページアプリケーション (SPA) です。

---

## 1. データモデル (`lib/schedule.dart`)

### 1.1 `ScheduleEvent`

```dart
class ScheduleEvent {
  String title;         // 予定タイトル
  String description;   // 詳細説明
  DateTime? date;       // 開始日時
  DateTime? endDate;    // 終了日時 (時間範囲を持つ場合)
  int? weekday;         // 曜日: 1=月曜, 7=日曜 (授業向け)
  int? period;          // 時限: 1〜5限 (授業向け)
  String? icon;         // 絵文字アイコン (🗑️ など)
  bool showIconOnly;    // カレンダー上でアイコンのみ表示するか
  String? note;         // メモ
  RecurringSchedule? origin; // 生成元の固定スケジュール参照
}
```

**設計上のポイント:**
- `weekday` と `period` は「大学生の時間割」用。`date` を持たずに曜日と時限で予定を表現する。
- `date` と `endDate` は「特定日時の予定」用。時間範囲指定が可能。
- `origin` は固定スケジュール (`RecurringSchedule`) から自動生成されたイベントが、元データを辿れるようにするための参照。これにより、生成済みイベントの編集時に元の `RecurringSchedule` にも変更を反映できる。

### 1.2 `RecurringSchedule`

```dart
class RecurringSchedule {
  String title;
  String description;
  int weekday;        // 曜日: 1=月曜, 7=日曜
  int hour;           // 開始時 (デフォルト 8)
  int minute;         // 開始分 (デフォルト 0)
  int? weekOfMonth;   // 第n週 (null=毎週, 1〜4=第1〜4週)
  String icon;
  bool enabled;
  String? note;
}
```

**固定スケジュールの考え方:**
- `weekOfMonth` が `null` → **毎週その曜日に**イベントを生成
- `weekOfMonth = 2` → **第2 ○曜日** にのみイベントを生成
- 例: 「第2水曜日にゴミ出し」「毎週月曜3限に線形代数」

### 1.3 `generateRecurringEvents`

```dart
List<ScheduleEvent> generateRecurringEvents(int year, int month) {
  // 指定された月内で、RecurringSchedule の条件に合う全 ScheduleEvent を動的生成
}
```

`RecurringSchedule` のリストから、指定月に該当する `ScheduleEvent` を動的に生成します。カレンダー表示のたびに呼ばれるため、固定スケジュールの変更は即座に次回のレンダリングに反映されます。

### 1.4 グローバルデータ

```dart
final List<ScheduleEvent> monthlyEvents = [];       // 月表示カレンダー用の手動予定
final List<ScheduleEvent> classSchedule = [];       // 週間授業用の予定
final List<RecurringSchedule> recurringSchedules = []; // 固定スケジュール設定
```

3つのグローバルリストで全てのデータを管理。IndexedDB との同期はこの3つに対して行われます。

---

## 2. 永続化 (`web/main.dart` 前半)

### 2.1 `DatabaseService`

```dart
class DatabaseService {
  static const String dbName = 'CalendarAppDB';
  static const int dbVersion = 1;
  idb.Database? _db;
}
```

IndexedDB をラップしたサービス。3つの Object Store を持つ:

| Store名 | 対応データ |
|---|---|
| `monthly_events` | 月表示の手動予定 |
| `class_schedule` | 週間授業の予定 |
| `recurring_schedules` | 固定スケジュール設定 |

**保存 (`saveAll`):**
各ストアを `clear()` → 全件 `add()` のシンプルな全置換方式。

**読み込み (`loadAll`):**
アプリ起動時に `openCursor` で全件取得し、それぞれのリストに復元。

---

## 3. メインロジック (`web/main.dart`)

### 3.1 エントリポイント

```dart
void main() async {
  setupSwipeGestures();    // スワイプ操作のイベントリスナ
  setupThemeToggle();      // テーマ切替 (Light/Dark/Auto)
  await dbService.init();
  await dbService.loadAll();  // 起動時にデータを復元
  renderCurrentPage();     // 現在のタブを描画
  renderViewTabs();        // タブバーを描画
}
```

### 3.2 テーマ管理

```dart
String _currentTheme = 'auto';  // 'auto' | 'light' | 'dark'
```

3状態をローテーションするテーマ切替:
- `auto`: OSの設定に従う (`prefers-color-scheme` メディアクエリ)
- `light`: 強制ライトモード
- `dark`: 強制ダークモード

CSS 変数は `:root` (ライト) と `[data-theme="dark"]` (ダーク) で二重定義され、JavaScript 側で `<html>` 要素の `data-theme` 属性を切り替えることで実現。

### 3.3 月表示 (`renderMonthView`)

画面構成:
```
┌──────────────────────────┐
│  calendar-section        │  ← height: 100dvh (画面全体)
│  ┌────────────────────┐  │
│  │ calendar-header    │  │  ← 年月 + ナビゲーションボタン
│  │ ◀ 2026年 7月 ▶ ⚙ ☁│  │
│  ├────────────────────┤  │
│  │ calendar-grid      │  │  ← flex: 1 でヘッダー以外を埋める
│  │ 月 火 水 木 金 土 日│  │
│  │  1  2  3  4  5  6  7│
│  │  ...               │  │
│  └────────────────────┘  │
├──────────────────────────┤
│  schedule-section         │  ← スクロール可能な予定一覧
│  スケジュール一覧          │
│  7日(土) 19:00 - 夕食     │
│  8日(日) 10:00 - 会議     │
│  ...                     │
└──────────────────────────┘
```

**特筆すべき点:**
- `calendar-section` は `height: 100dvh` で画面全体を占有し、カレンダーグリッドは `flex: 1` で残りのスペースを均等に分割する。
- `calendar-grid` は CSS Grid (`repeat(7, 1fr)`) で実装。
- 先頭に空セルを追加して曜日の開始位置をオフセットする:
  ```dart
  for (int i = 1; i < startWeekday; i++) {
    grid.children.add(DivElement()..classes.addAll(['calendar-cell', 'empty']));
  }
  ```

### 3.4 カレンダーグリッド (`renderCalendarGrid`)

曜日ラベル行には、その曜日に設定された固定スケジュールも表示:
```dart
final schedulesForDay = recurringSchedules.where((s) => s.weekday == weekday).toList();
```

各日のセルには手動予定のチップを表示:
```dart
if (manualEvents.isNotEmpty) {
  final eventChip = DivElement()..classes.add('event-chip');
  eventChip.append(SpanElement()..text = '${manualEvents.first.icon} ${manualEvents.first.title}');
}
```

### 3.5 スケジュール一覧 (`renderMonthlyEventSummary`)

アジェンダ表示 (日付ごとのイベント一覧)。Google カレンダー風に、過去の予定は表示せず今日以降の予定のみ表示する:
```dart
if (date.isBefore(today)) continue;
```

各イベントカードには色分けが適用される (`getEventCardClass`):
```dart
String getEventCardClass(ScheduleEvent event) {
  final title = event.title.toLowerCase();
  if (title.contains('食事') || title.contains('夕食')) return 'bg-food';
  if (title.contains('フライト') || title.contains('飛行機')) return 'bg-flight';
  if (title.contains('アルバイト') || title.contains('シフト')) return 'color-orange';
  // ...
}
```

### 3.6 タイムライン (`renderDayTimeline`)

**時間軸**: 0:00〜23:00、1時間=40px (`hourHeight = 40`)

```
    00:00 ─────────────
    01:00 ─────────────
    02:00 ─────────────
         ┌──────────────┐
    09:00│ 9:00-10:30   │ timeline-event-block (color-blue)
         │ 英会話レッスン │
         └──────────────┘
    10:00 ─────────────
    ...
```

**ドラッグ選択機能:**

`timeline-interaction-overlay` を `pointer-events: auto` で重ね、`onMouseDown` / `onMouseMove` / `document.onMouseUp` でドラッグ操作を検出。

```dart
interactionOverlay.onMouseDown.listen((e) {
  dragStartMinutes = getMinutesFromY(e.offset.y.toInt());
});
// ...
document.onMouseUp.listen((e) {
  if (startMin == endMin) endMin = startMin + 60; // クリックだけなら1時間枠
  _showQuickAddDialog(date, startMin, endMin);
});
```

ドラッグ中は `drag-indicator` (半透明青枠) と `drag-start-marker` (開始時刻ラベル付き破線) を描画して視覚的フィードバックを提供。

### 3.7 ボトムシート (Bottom Sheet)

全ダイアログはボトムシートとして実装:

```
┌──────────────────────────┐
│ overlay-backdrop (半透明) │
│                          │
│  ┌────────────────────┐  │
│  │ ═══ (ハンドル)     │  │
│  │ 日付詳細        ✕  │  │
│  │                    │  │
│  │ タイムライン/フォーム│  │
│  │                    │  │
│  └────────────────────┘  │
└──────────────────────────┘
```

CSS で Google Material 風のスライドアップアニメーション:
```css
.bottom-sheet {
  transform: translateY(100%);
  animation: slideUpBottomSheet 0.28s cubic-bezier(0.16, 1, 0.3, 1) forwards;
}
```

### 3.8 ホイールピッカー (`createPickerWheel`)

```dart
Element createPickerWheel({
  required int value,
  required int min,
  required int max,
  required int step,
  required void Function(int) onChange,
  String Function(int)? formatLabel,
})
```

iOS 風のスクロールホイールピッカーを純粋な DOM 操作で実装:
- 3行分の表示領域 (`visibleH = itemH * 3`)
- 上下にパディングと半透明グラデーションマスクを重ねて両端のフェードアウト表現
- `scrollend` イベントで最も近い値にスナップ
- マウスホイールにも対応 (`onMouseWheel` で `scrollBy`)

### 3.9 週間授業ビュー

```dart
void renderClassWeekView() {
  // 時間割テーブル: 行=時限(1〜5限), 列=曜日(月〜金)
}
```

`classSchedule` リストを `weekday` と `period` でフィルタしてテーブルに配置。空きコマには `+` ボタンを表示し、クリックで新規授業追加ダイアログを開く。

### 3.10 同期・バックアップ (`showSyncDialog`)

2系統のバックアップを提供:

1. **Cloud Sync**: 任意の API エンドポイントに POST で送信、GET で取得
   ```dart
   await HttpRequest.request(url, method: 'POST', sendData: jsonEncode(payload), ...);
   ```
2. **File Backup**: JSON ファイルをダウンロード/アップロード
   ```dart
   final blob = Blob([jsonStr], 'application/json');
   final url = Url.createObjectUrlFromBlob(blob);
   ```

インポート時は `applyImportData` で全リストをクリア後に入れ替え、IndexedDB に保存して画面再描画。

---

## 4. スタイル設計 (`web/styles.css`)

- CSS カスタムプロパティ (変数) を活用し、Light/Dark テーマを `:root` と `[data-theme="dark"]` で切り替え
- `prefers-color-scheme: dark` メディアクエリ + `:root:not([data-theme="light"])` で Auto モード対応
- 44px 最小タッチターゲット、Google Material Design 風の半透明ガラスモーフィズムヘッダー
- オーロラ背景エフェクト (`glow-orb`) 用のぼかし円 (パフォーマンスのため2個のみ)

---

## 5. ビルド・開発環境

### Dart → JS

```bash
dart compile js web/main.dart -o web/main.dart.js
```

Dart の `web` コンパイルターゲットで JavaScript に変換。出力された `.js` ファイルを `index.html` から読み込む。

### Dev server (bun)

`package.json` の `dev` スクリプトは `nodemon` (Dart 変更監視) と `browser-sync` (静的サーバ + ライブリロード) を `concurrently` で並列起動。

### Nix flake

Nix による再現可能な開発環境とビルドパイプライン。以下を提供:
- `devShells.default`: Dart, bun, Node.js, Java, Gradle, Android SDK を含む開発シェル
- `packages.default`: コンパイル済み web/ ディレクトリ
- `apps.apk`: `nix run .#apk` で APK をビルド

---

## 6. 主要な関数一覧

| 関数 | 行数 | 説明 |
|---|---|---|
| `main()` | 226 | エントリポイント、初期化と初回描画 |
| `setupThemeToggle()` | 241 | テーマ切替ボタンの初期化と `localStorage` 永続化 |
| `renderMonthView()` | 375 | 月表示の全画面描画 |
| `renderCalendarGrid()` | 443 | カレンダーグリッド (7×6) の生成 |
| `renderMonthlyEventSummary()` | 544 | アジェンダ形式の予定一覧 |
| `showDayDetails()` | 639 | 日付詳細のボトムシート表示 |
| `showEditEventDialog()` | 703 | 予定編集・メモ追加のダイアログ |
| `showSettingsDialog()` | 911 | 固定スケジュール設定のダイアログ |
| `renderDayTimeline()` | 1140 | タイムライン (0-23時) の描画とドラッグ操作 |
| `_showQuickAddDialog()` | 1328 | タイムラインドラッグ時の予定追加 |
| `renderClassWeekView()` | 1560 | 週間授業ビューの描画 |
| `renderClassScheduleTable()` | 1593 | 時間割テーブル (5限×5曜日) |
| `showSyncDialog()` | 1857 | 同期・バックアップ用ダイアログ |
| `uploadToCloud()` | 1978 | Cloud API への POST 送信 |
| `downloadFromCloud()` | 2003 | Cloud API からの GET 取得 |
| `exportToJson()` | 2022 | JSON ファイルダウンロード |
| `importFromJson()` | 2042 | JSON ファイルアップロードと復元 |
