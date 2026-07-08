# Calender コード解説 — Dart 未経験者向け

> このガイドは Dart を書いたことがない人を想定して、一歩ずつ丁寧に説明します。  
> コードの各行を見ていけば、このアプリの仕組みが理解できるはずです。

---

## はじめに — Dart ってどんな言語？

Dart は Google が作ったプログラミング言語です。JavaScript や TypeScript に似た文法を持ちます。
このアプリでは Dart を Web 用に使い、最終的に JavaScript に変換してブラウザで動かしています。

### 最低限知っておけばよい Dart の文法

```dart
// 変数宣言
var name = '太郎';          // 型推論。String型だと自動で判断される
String name2 = '太郎';      // 型を明示することもできる
int age = 20;               // 整数
double height = 170.5;      // 小数
bool isActive = true;       // 真偽値

// null許容型（? をつけると null を入れられる）
String? nickname = null;    // ? がないと null は入れられない

// クラス（TypeScript の class とほぼ同じ）
class Person {
  String name;               // フィールド（プロパティ）
  int age;

  Person({                  // コンストラクタ
    required this.name,     // required = 必須引数
    required this.age,
  });
}

// メソッド（関数）
void greet(String name) {    // void = 戻り値なし
  print('こんにちは、$name');  // $変数名 で文字列に埋め込める
}

// ラムダ式（arrow function）
final add = (int a, int b) => a + b;

// リスト
final numbers = [1, 2, 3];
numbers.add(4);
numbers.where((n) => n > 2).toList();  // [3, 4] フィルタ

// オプショナル引数（= でデフォルト値）
void log(String msg, {String level = 'info'}) { /* ... */ }
```

---

## 全体像

このアプリのコードはたった **2ファイル** です。

| ファイル | 役割 |
|---|---|
| `lib/schedule.dart` (169行) | データの定義と計算ロジック |
| `web/main.dart` (2087行) | UI（画面）のすべて |

なぜ2ファイルだけで動くのか？  
→ フレームワーク（Reactなど）を一切使わず、Dartが標準で持っている `dart:html` というライブラリで直接HTMLを組み立てているからです。

---

## 起動からの動作フロー

アプリが起動してから最初の画面が表示されるまでの流れを、一歩ずつ追ってみましょう。

### 全体フロー図

```
ユーザーが web/index.html を開く
          │
          ▼
  ┌───────────────────────────────────────┐
  │ ① HTML の読み込み                       │
  │   • styles.css を読み込む（テーマ色設定）│
  │   • Lucide アイコンCDN を読み込む       │
  │   • main.dart.js の実行開始             │
  └───────────────────────────────────────┘
          │
          ▼
  ┌───────────────────────────────────────┐
  │ ② main() 関数が呼ばれる                 │
  │   (web/main.dart のエントリポイント)     │
  └───────────────────────────────────────┘
          │
          ▲              ▲              ▲
          │              │              │
  ┌───────┴──┐  ┌────────┴──────┐ ┌───┴──────────────┐
  │③ スワイプ  │  │④ テーマ設定  │ │⑤ DB初期化と読込   │
  │ 操作の準備 │  │              │ │                  │
  │           │  │ localStorage │ │ IndexedDB を開く  │
  │ onTouch   │  │ から前回の   │ │ ↓                │
  │ Start/Move│  │ テーマを読込 │ │ 3ストアから       │
  │ /End の   │  │ ↓            │ │ 全予定データを    │
  │ リスナを  │  │ <html> に    │ │ リストに復元      │
  │ 登録      │  │ data-theme   │ │                  │
  │           │  │ 属性を設定   │ │ await で完了を    │
  │           │  │              │ │ 待つ             │
  └─────┬─────┘  └──────┬───────┘ └────────┬─────────┘
        │               │                 │
        └───────────────┼─────────────────┘
                        │ 3つが完了したら次へ
                        ▼
          ┌───────────────────────────────────────┐
          │ ⑥ 画面の初回描画                        │
          │                                       │
          │  renderCurrentPage()                  │
          │  → currentPage の値 (初期値=0) を確認  │
          │  → 0 なので renderMonthView() を呼ぶ   │
          └───────────────────────────────────────┘
                        │
                        ▼
          ┌───────────────────────────────────────┐
          │ ⑦ renderMonthView()                  │
          │                                       │
          │  1. #appContent の中身を空にする        │
          │  2. calendar-section を作る            │
          │     ├ ヘッダー（◀ 2026年7月 ▶ ⚙ ☁）  │
          │     └ renderCalendarGrid(年, 月)       │
          │         ├ 7曜日のラベル行               │
          │         ├ 空セルで曜日オフセット         │
          │         └ 1日〜末日の全セル             │
          │  3. schedule-section を作る            │
          │     └ renderMonthlyEventSummary()     │
          │         ├ 予定を日付でグループ化         │
          │         ├ 今日以降の予定だけを列挙       │
          │         └ 各予定をカード表示             │
          └───────────────────────────────────────┘
                        │
                        ▼
          ┌───────────────────────────────────────┐
          │ ⑧ renderViewTabs()                   │
          │                                       │
          │  #viewTabs にタブを描画                │
          │  [ 📅 月表示 ] [ 🕐 時間割 ]           │
          │  現在 currentPage=0 なので月表示が     │
          │  アクティブ（青くハイライト）           │
          └───────────────────────────────────────┘
                        │
                        ▼
          ┌───────────────────────────────────────┐
          │ ⑨ refreshLucideIcons()               │
          │                                       │
          │  Lucide ライブラリに全 <i data-lucide> │
          │  タグを SVG アイコンに置換させる        │
          └───────────────────────────────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │ 表示完了 🎉      │
              │ 月表示カレンダー  │
              │ が画面に出る     │
              └─────────────────┘
```

### main() 関数のコードと各行の解説

```dart
// ❶ この関数がすべての起点。ブラウザが main.dart.js を読み込むと自動で呼ばれる
void main() async {

  // ❷ スワイプ操作の準備
  //    スマホで左右にスワイプしたときのイベントリスナを登録する
  //    onTouchStart: 指が触れたX座標を記録
  //    onTouchMove:  左右方向の移動かどうか判定
  //    onTouchEnd:   50px以上動いていたら月移動と判定
  setupSwipeGestures();

  // ❸ テーマ切替ボタンの準備
  //    localStorage から前回のテーマ設定 ('auto'/'light'/'dark') を読み込み
  //    <html> 要素の data-theme 属性に反映
  //    #themeToggle ボタンにクリックリスナを登録（auto→light→dark→auto...）
  setupThemeToggle();

  // ❹ IndexedDB を初期化
  //    CalendarAppDB という名前のデータベースを開く
  //    バージョン番号を見て、初回なら3つの Object Store を作成
  //    await = この処理が終わるまで次の行に進まない
  await dbService.init();

  // ❺ 保存データを読み込んでリストに復元
  //    3つの Object Store から全レコードを取得
  //    monthlyEvents, classSchedule, recurringSchedules に詰め直す
  //    データがなければ空リストのまま進む
  await dbService.loadAll();

  // ❻ 現在のタブに応じた画面を描画
  //    初期値 currentPage = 0 → renderMonthView() が呼ばれる
  renderCurrentPage();

  // ❼ ヘッダー内のタブバーを描画
  //    [月表示] [時間割] の2タブ。月表示がアクティブ表示になる
  renderViewTabs();
}
```

### 各段階で使われる主なデータ

| 段階 | 使うデータ / 関数 | 説明 |
|---|---|---|
| ② main() | — | エントリポイント |
| ③ スワイプ | `onTouchStart/Move/End` | スマホ操作の受付開始 |
| ④ テーマ | `localStorage['theme']`, `applyTheme()` | 前回のテーマを復元 |
| ⑤ DB初期化 | `DatabaseService.init()` | IndexedDB に接続 |
| ⑤ データ読込 | `DatabaseService.loadAll()` | 全予定を復元 |
| ⑥ 画面判定 | `currentPage` (初期値=0) | どの画面を出すか |
| ⑦ 月表示 | `renderMonthView()` | カレンダー＋予定一覧 |
| ⑦ カレンダー | `renderCalendarGrid()` | 7列の日付グリッド |
| ⑦ 予定一覧 | `renderMonthlyEventSummary()` | 日付ごとのイベント表示 |
| ⑧ タブ | `renderViewTabs()` | ヘッダータブの表示 |
| ⑨ アイコン | `refreshLucideIcons()` | SVGアイコンの置換 |

### 画面切り替え時の流れ

ボタンやスワイプで画面が切り替わる流れも同じパターンです。

```
ユーザー操作
（タブクリック / 月移動 / 設定変更 / 予定追加 ...）
        │
        ▼
  対応する関数が呼ばれる（switchToPage, adjustMonth, showSettingsDialog など）
        │
        ▼
  必要ならデータを書き換える（monthlyEvents, recurringSchedules など）
        │
        ▼
  必要なら dbService.saveAll() で IndexedDB に保存
        │
        ▼
  renderMonthView() または renderClassWeekView() を呼んで画面を再描画
        │
        ▼
  refreshLucideIcons() でアイコンを再描画
```

この「データ変更 → 保存 → 画面再描画」のサイクルが、アプリ全体で一貫して使われているパターンです。

---

## ファイル1: `lib/schedule.dart` — 「予定」を表すデータ構造

### 2種類の予定データ

このアプリには**2種類の予定**があります。

#### ① ふつうの予定 — `ScheduleEvent`

「7月8日 19:00 から 21:00 まで友人と食事」のような、一度きりの予定です。

```dart
class ScheduleEvent {
  String title;               // 例: "友人と食事"
  String description;         // 例: "渋谷のイタリアン"
  DateTime? date;             // 開始日時（例: 2026-07-08 19:00）
  DateTime? endDate;          // 終了日時（例: 2026-07-08 21:00）
  int? weekday;               // 曜日（1=月〜7=日）※授業用
  int? period;                // 時限（1〜5限）※授業用
  String? icon;               // 絵文字アイコン（例: "🍴"）
  bool showIconOnly;          // カレンダーにアイコンだけ表示するか
  String? note;               // メモ（自由入力）
  RecurringSchedule? origin;  // どの固定予定から自動生成されたか
}
```

> **`?` の意味**: `DateTime?` と書くと「DateTime または null」を表します。日時が未設定の予定も扱えるようにするためです。

#### ② くりかえしの予定 — `RecurringSchedule`

「毎週月曜の3限に線形代数の授業」「第2水曜はゴミの日」のような定期的な予定です。

```dart
class RecurringSchedule {
  String title;            // 例: "線形代数"
  String description;      // 例: "101教室"
  int weekday;             // 曜日（1=月〜7=日）
  int hour;                // 開始時（例: 9）
  int minute;              // 開始分（例: 0）
  int? weekOfMonth;        // 第n週（null=毎週, 1=第1週, 2=第2週...）
  String icon;
  bool enabled;            // ON/OFF
  String? note;            // メモ
}
```

**`weekOfMonth` の使い方:**

| `weekOfMonth` の値 | 意味 | 例（月曜の場合） |
|---|---|---|
| `null` | 毎週 | 毎週月曜 |
| `1` | 第1週 | その月の最初の月曜 |
| `2` | 第2週 | その月の2番目の月曜 |
| `3` | 第3週 | その月の3番目の月曜 |
| `4` | 第4週 | その月の4番目の月曜 |

### 予定を自動生成する関数 — `generateRecurringEvents`

```dart
List<ScheduleEvent> generateRecurringEvents(int year, int month) {
```

引数に「年」と「月」を渡すと、その月にある繰り返し予定の実際の日付を計算して、日付入りの `ScheduleEvent` をまとめて返します。

たとえば `generateRecurringEvents(2026, 7)` と呼ぶと：
- 「毎週月曜 3限」→ 7月の全月曜（7/6, 7/13, 7/20, 7/27）の4件
- 「第2水曜 ゴミ出し」→ 7/8 の1件
をまとめて返します。

**処理の流れ:**
```
1. その月の日数を調べる（28〜31日）
2. recurringSchedules を1つずつ見ていく
   ├── weekOfMonth が null（毎週）
   │   └→ その月の全曜日をチェックし、曜日が合う日すべてに予定を作る
   └── weekOfMonth が指定あり（第n週）
       └→ その月の第n週目の該当曜日にだけ予定を作る
3. 作った予定のリストを返す
```

---

## ファイル2: `web/main.dart` — UIのすべて

### アプリ起動時 (`main` 関数)

```dart
void main() async {
  setupSwipeGestures();         // ← スマホのスワイプ操作を有効化
  setupThemeToggle();           // ← ダークモード切替ボタンの初期化
  await dbService.init();       // ← IndexedDB（ブラウザ内蔵DB）を開く
  await dbService.loadAll();    // ← 保存してあった予定を読み込む
  renderCurrentPage();          // ← 画面を描画
  renderViewTabs();             // ← 上部のタブ（月表示/時間割）を描画
}
```

`await` は「この処理が終わるまで待つ」という意味です。データベースの読み込みが終わってから画面を描画する、という順序を保証しています。

### 予定データは3つのリストで管理

```dart
final List<ScheduleEvent> monthlyEvents = [];      // 月表示に出す手動の予定
final List<ScheduleEvent> classSchedule = [];      // 週間授業の時間割
final List<RecurringSchedule> recurringSchedules = []; // くりかえし予定の設定
```

この3つのリストが**アプリの全データ**です。ここに対して追加・編集・削除を行い、変更のたびに IndexedDB に保存します。

### 画面は2ページ

| ページ | 関数 | 説明 |
|---|---|---|
| 月表示 | `renderMonthView()` | カレンダー + 予定一覧 |
| 週間授業 | `renderClassWeekView()` | 時間割テーブル |

ページ切替は `switchToPage(0)` / `switchToPage(1)` で行います。

```dart
void switchToPage(int page) {
  currentPage = page;
  renderCurrentPage();   // 該当ページを再描画
  renderViewTabs();      // タブのアクティブ表示を更新
}
```

---

## 月表示の中身

### カレンダーグリッド (`renderCalendarGrid`)

カレンダー部分は CSS Grid で 7列×（曜日ラベル行＋6週分）のマス目になっています。

**セル（日付のマス）をどう作っているか:**

```dart
// まず、その月の1日が何曜日かを計算
final firstDay = DateTime(year, month, 1);
final startWeekday = firstDay.weekday;  // 1=月曜, 7=日曜

// 1日より前の曜日は空セルで埋める（カレンダーの見た目を揃える）
for (int i = 1; i < startWeekday; i++) {
  grid.children.add(DivElement()..classes.addAll(['calendar-cell', 'empty']));
}

// 1日から末日までのセルを作る
for (int day = 1; day <= daysInMonth; day++) {
  final date = DateTime(year, month, day);
  final cell = DivElement()..classes.add('calendar-cell');

  // 日付番号を表示
  cell.children.add(DivElement()..text = '$day');

  // 今日の日付ならハイライト
  if (isToday) cell.classes.add('today');

  // クリックでその日の詳細を表示
  cell.onClick.listen((_) => showDayDetails(date, fixedEvents, manualEvents));

  grid.children.add(cell);
}
```

### 予定一覧 (`renderMonthlyEventSummary`)

カレンダーの下にある「スケジュール一覧」です。日付ごとに予定をグループ化して表示します。

```dart
// 予定を日付でグループ化する
final eventsByDay = <int, List<ScheduleEvent>>{};  // Map<日付, 予定リスト>
for (final event in allEvents) {
  if (event.date != null) {
    final day = event.date!.day;
    eventsByDay.putIfAbsent(day, () => []).add(event);
  }
}

// 今日より前の日付の予定は表示しない
if (date.isBefore(today)) continue;
```

### 予定カードの色分け (`getEventCardClass`)

タイトルに含まれるキーワードでカードの色を自動判定します。

```dart
String getEventCardClass(ScheduleEvent event) {
  final title = event.title.toLowerCase();  // 小文字にして判定
  if (title.contains('食事') || title.contains('夕食')) return 'bg-food';     // オレンジ系
  if (title.contains('フライト') || title.contains('飛行機')) return 'bg-flight'; // 青系
  if (title.contains('アルバイト') || title.contains('ゴミ')) return 'color-orange';
  if (title.contains('ゼミ') || title.contains('レポート')) return 'color-purple';
  return 'color-blue';  // デフォルト
}
```

---

## タイムライン（1日の時間軸表示）

日付のセルをクリックすると出てくる詳細画面の中心部分です。

### 仕組み

```dart
const hourHeight = 40;  // 1時間 = 40ピクセル

// 0:00 〜 23:00 の時間線を引く
for (int hour = 0; hour <= 23; hour++) {
  final topPos = hour * hourHeight;  // 上からの位置 (px)
  // 横線を引く
  timelineBg.children.add(DivElement()
    ..style.top = '${topPos}px');
  // 時間ラベル (00:00, 01:00, ...) を表示
  timelineBg.children.add(DivElement()
    ..style.top = '${topPos}px'
    ..text = '${hour.toString().padLeft(2, '0')}:00');
}
```

予定ブロックの位置計算:
```dart
// 例: 9:30開始 → 9 * 60 + 30 = 570分
final startMinutes = start.hour * 60 + start.minute;
// 画面上の位置 (0時からのピクセル数)
final topPos = (startMinutes - 0) * hourHeight / 60;
// 例: 570 * 40 / 60 = 380px の位置
```

### ドラッグで予定を作る

タイムライン上でマウスをドラッグすると、その時間帯に予定を追加できます。

```
マウスダウン → 開始時刻を記録
マウス移動   → 終了時刻を更新、選択範囲を青く表示
マウスアップ → ダイアログを開いて予定の詳細を入力
```

```dart
// クリック位置のY座標 → 時刻（分）に変換
int getMinutesFromY(int localY) {
  final hourOffset = localY / hourHeight;          // 何時間目の位置か
  final totalMinutes = (hourOffset * 60).round();   // 分に変換
  final snapped = ((totalMinutes + 7) ~/ 15) * 15;   // 15分単位に丸める
  return 0 * 60 + snapped;
}

// ドラッグで範囲を作ったあと
if (startMin == endMin) endMin = startMin + 60;  // クリックだけなら1時間にする
_showQuickAddDialog(date, startMin, endMin);     // 予定追加ダイアログ
```

---

## ボトムシート（下から出てくるダイアログ）

このアプリの設定画面や予定編集はすべて「ボトムシート」で実装されています。
画面下からスライドして出てくるパネルです。

**構造:**
```
<div class="overlay-backdrop">   ← 背景を半透明で覆う（クリックで閉じる）
  <div class="bottom-sheet">    ← 白いパネル（下からスライドアップ）
    タイトル + 閉じるボタン
    フォーム / 設定項目
  </div>
</div>
```

**アニメーション (CSS):**
```css
.bottom-sheet {
  transform: translateY(100%);   /* 初期状態: 画面の下に隠れている */
  animation: slideUp 0.28s forwards;  /* 0.28秒で上にスライド */
}
@keyframes slideUp {
  to { transform: translateY(0); }  /* 最終位置: 画面下端に表示 */
}
```

閉じるときは `backdrop.remove()` で要素ごとDOMから取り除きます。

---

## データの保存と読み込み

### IndexedDB を使う理由

ブラウザを閉じてもデータが消えないように、ブラウザ内蔵の IndexedDB というデータベースを使っています。
localStorage より大量のデータを構造的に保存できます。

**保存の流れ:**
```dart
Future<void> saveAll() async {
  // monthly_events ストアを空にしてから全件追加（上書き保存）
  final store1 = db.transaction('monthly_events', 'readwrite').objectStore('monthly_events');
  await store1.clear();
  for (final event in monthlyEvents) {
    store1.add(event.toJson());  // オブジェクトをJSONに変換して保存
  }
  // class_schedule も同様
  // recurring_schedules も同様
}
```

**読み込みの流れ:**
```dart
Future<void> loadAll() async {
  final store1 = db.transaction('monthly_events', 'readonly').objectStore('monthly_events');
  await store1.openCursor(autoAdvance: true).forEach((cursor) {
    records.add(cursor.value);  // 全レコードを取得
  });
  // JSONをオブジェクトに戻して monthlyEvents リストに入れ直す
  for (final r in records) {
    monthlyEvents.add(ScheduleEvent.fromJson(r));
  }
}
```

保存/読み込みのタイミング:
- **保存**: 予定の追加・編集・削除のたびに即時保存
- **読み込み**: アプリ起動時のみ

### バックアップ機能

JSONファイルとしてエクスポート/インポートもできます。

```dart
// エクスポート: ブラウザにファイルをダウンロードさせる
void exportToJson() {
  final jsonStr = jsonEncode({      // 3つのデータを1つのJSONにまとめる
    'monthly_events': monthlyEvents.map((e) => e.toJson()).toList(),
    'class_schedule': classSchedule.map((e) => e.toJson()).toList(),
    'recurring_schedules': recurringSchedules.map((e) => e.toJson()).toList(),
  });
  final blob = Blob([jsonStr], 'application/json');     // JSONファイル作成
  final url = Url.createObjectUrlFromBlob(blob);         // ダウンロードURL生成
  AnchorElement()..href = url..download = 'calendar_backup.json'..click();
}
```

---

## テーマ（ダークモード）

```dart
String _currentTheme = 'auto';  // 初期値。OSの設定に従う

void applyTheme(String theme) {
  // <html> 要素に data-theme="dark" や data-theme="light" をセット
  document.documentElement?.setAttribute('data-theme', theme);
}
```

CSS側ではこの属性を見て色を切り替えています。

```css
/* ライトモード（デフォルト） */
:root {
  --bg-primary: #ffffff;      /* 背景: 白 */
  --text-primary: #1a1c2e;    /* 文字: 濃いグレー */
}

/* ダークモード */
[data-theme="dark"] {
  --bg-primary: #0f1117;      /* 背景: ほぼ黒 */
  --text-primary: #e8eaf0;    /* 文字: 明るいグレー */
}
```

テーマ切替ボタンを押すと `auto → light → dark → auto → ...` とローテーションします。

---

## 時間割（週間授業ビュー）

```dart
void renderClassWeekView() {
  // テーブル（表）を作る
  final table = TableElement();
  // 1行目: 見出し (限数, 月, 火, 水, 木, 金)
  // 2〜6行目: 各時限の内容
  for (int period = 1; period <= 5; period++) {
    for (int weekday = 1; weekday <= 5; weekday++) {
      // classSchedule リストから「この曜日のこの時限」の予定を検索
      final events = classSchedule.where(
        (event) => event.weekday == weekday && event.period == period
      ).toList();

      if (events.isEmpty) {
        // 予定がない → + ボタン（クリックで新規追加ダイアログ）
        cell.children.add(DivElement()..classes.add('empty-slot'));
      } else {
        // 予定がある → 授業名と詳細を表示（クリックで編集ダイアログ）
        cell.children.add(DivElement()..classes.add('schedule-pill'));
      }
    }
  }
}
```

---

## スワイプ操作

```dart
void setupSwipeGestures() {
  content.onTouchStart.listen((e) {
    startX = e.touches.first.client.x;  // 指が触れたX座標を記録
  });

  content.onTouchEnd.listen((e) {
    final deltaX = e.changedTouches.first.client.x - startX;  // 移動量
    if (deltaX.abs() > 50) {  // 50px以上動かしたらスワイプと判定
      if (deltaX > 0) {
        adjustMonth(-1);  // 右スワイプ → 前月
      } else {
        adjustMonth(1);   // 左スワイプ → 次月
      }
    }
  });
}
```

---

## コードの依存関係まとめ

```
index.html  ← ブラウザが最初に読むファイル
  ├── styles.css         ← 見た目
  ├── lucide CDN          ← アイコン (カレンダー、歯車、雲など)
  └── main.dart.js        ← Dart をコンパイルした JavaScript

main.dart.js のもと:
  web/main.dart          ← UIロジック全般
    └── lib/schedule.dart ← データモデル

ビルドツール:
  package.json → dart compile js でコンパイル
  flake.nix    → Nix 環境で同じことをする
```

---

## おまけ: Dart → JavaScript コンパイルとは

Dart はブラウザで直接実行できません。そのため `dart compile js` コマンドで JavaScript に変換します。

```
[Dartのソースコード]  →  dart compile js  →  [JavaScriptファイル]
   main.dart                                      main.dart.js
```

変換後の JavaScript は人間が読むには難しいですが、元の Dart コードと同じ動作をします。
このアプリの配布物は `web/index.html` と変換後の `main.dart.js` のセットです。
