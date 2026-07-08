# Calender

Dart で作ったシンプルなスケジュール管理アプリです。  
月表示カレンダー + 週間授業スケジュール（大学生向け）を一つのアプリで提供します。

> **コードの詳しい解説**は [CODE_GUIDE.md](./CODE_GUIDE.md) を参照してください。  
> Dart を書いたことがない人でも理解できるよう、一歩ずつ噛み砕いて説明しています。

## 機能

- **月表示モード**: 1ヶ月分の予定をカレンダーに表示。毎日の予定をタイムラインで確認・追加・編集可能
- **週間授業モード**: 月〜金・1〜5限の時間割を表形式で一覧表示
- **固定スケジュール**: 毎週/第n週の定期予定を設定可能（cog アイコンで表示）
- **予定編集・メモ**: 各予定にメモを追加・編集可能
- **データ永続化**: IndexedDB に予定データを保存（ブラウザを閉じても保持）
- **テーマ切替**: Light / Dark / Auto に対応
- **スワイプ操作**: モバイルで左右スワイプによる月移動
- **クラウド同期**: 任意の API エンドポイントへのバックアップ・復元
- **ファイルバックアップ**: JSON ファイルへのエクスポート・インポート
- **PWA対応**: スマホのホーム画面に追加可能（manifest.json + アイコン）
- **日本祝日対応**: 日本の祝日を土日と同様に表示
- **APKビルド対応**: Android WebView アプリとして APK を生成可能

## スクリーンショット

| 月表示 | 週間授業 | タイムライン |
|--------|---------|------------|
| (TODO) | (TODO) | (TODO) |

## プロジェクト構成

```
calender/
├── lib/
│   └── schedule.dart          # データモデル (ScheduleEvent, RecurringSchedule)
├── web/
│   ├── index.html             # アプリのエントリポイント
│   ├── styles.css             # 全スタイル (Light/Dark テーマ)
│   ├── main.dart              # UI制御・表示ロジック (2087行)
│   ├── manifest.json          # PWA マニフェスト
│   ├── assets/                # アイコン画像
│   │   ├── icon.svg
│   │   ├── icon-192x192.png
│   │   ├── icon-512x512.png
│   │   ├── food_event_bg.png
│   │   └── flight_event_bg.png
│   └── dev/                   # 開発用テスト・検証ページ
│       ├── test_dart.html
│       ├── test_static.html
│       ├── test_drag.html
│       ├── verify.html
│       └── ...
├── android/
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradle.properties
│   └── app/
│       ├── build.gradle.kts
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── java/com/calender/app/MainActivity.java
├── scripts/
│   └── generate_icons.py      # アイコン生成スクリプト (PIL)
├── pubspec.yaml               # Dart パッケージ定義
├── package.json               # Dev環境 (browser-sync, nodemon, concurrently)
├── flake.nix                  # Nix ビルド/開発環境定義
├── mise.toml                  # ツールバージョン管理 (dart, bun)
└── .gitignore
```

## フローチャート

### 画面遷移 (UI Navigation)

```mermaid
flowchart TD
    START(["アプリ起動"]) --> LOAD[("IndexedDB から<br>データロード")]
    LOAD --> MONTH["月表示<br>(renderMonthView)"]
    LOAD --> WEEK["週間授業<br>(renderClassWeekView)"]

    MONTH --> CAL["カレンダーグリッド<br>(renderCalendarGrid)"]
    MONTH --> AGENDA["スケジュール一覧<br>(renderMonthlyEventSummary)"]

    CAL -- "セルクリック" --> DAY_DETAIL["日付詳細ボトムシート<br>(showDayDetails)"]
    AGENDA -- "カードクリック" --> EDIT_EVENT["予定編集ダイアログ<br>(showEditEventDialog)"]

    DAY_DETAIL --> TIMELINE["タイムライン表示<br>(renderDayTimeline)"]
    DAY_DETAIL --> ADD_FORM["予定新規作成<br>(renderAddEventForm)"]

    TIMELINE -- "ドラッグ選択" --> QUICK_ADD["クイック追加<br>(_showQuickAddDialog)"]
    TIMELINE -- "ブロッククリック" --> EDIT_EVENT

    EDIT_EVENT --> SAVE_EDIT["タイトル/説明/メモ編集 → 保存"]
    SAVE_EDIT --> MONTH

    WEEK --> TABLE["週間時間割テーブル<br>(renderClassScheduleTable)"]
    TABLE -- "空きコマ" --> ADD_CLASS["授業追加<br>(showAddClassEventDialog)"]
    TABLE -- "授業pill" --> EDIT_CLASS["授業編集<br>(showEditClassEventDialog)"]

    MONTH -- "設定ボタン" --> SETTINGS["固定スケジュール設定<br>(showSettingsDialog)"]
    MONTH -- "同期ボタン" --> SYNC["同期・バックアップ<br>(showSyncDialog)"]
    WEEK -- "設定/同期" --> SETTINGS
    WEEK -- "設定/同期" --> SYNC

    SYNC --> UPLOAD["クラウドへ保存 (POST)"]
    SYNC --> DOWNLOAD["クラウドから復元 (GET)"]
    SYNC --> EXPORT["JSONエクスポート"]
    SYNC --> IMPORT["JSONインポート"]
    UPLOAD --> MONTH
    DOWNLOAD --> MONTH
    IMPORT --> MONTH
```

### データモデルと永続化

```mermaid
flowchart LR
    subgraph DATA["データモデル (lib/schedule.dart)"]
        SE["ScheduleEvent<br>title, description<br>date, endDate<br>weekday, period<br>icon, note, origin"]
        RS["RecurringSchedule<br>title, description<br>weekday, hour, minute<br>weekOfMonth, icon<br>enabled, note"]
        SE -- "origin 参照" --> RS
    end

    subgraph STORAGE["永続化層 (IndexedDB)"]
        IDB[("DatabaseService<br>CalendarAppDB")]
        STORE1["monthly_events"]
        STORE2["class_schedule"]
        STORE3["recurring_schedules"]
        IDB --> STORE1
        IDB --> STORE2
        IDB --> STORE3
    end

    subgraph SYNC_LAYER["同期層"]
        CLOUD["Cloud API<br>(POST/GET)"]
        FILE["JSON File<br>(Export/Import)"]
    end

    SE --> STORE1
    SE --> STORE2
    RS --> STORE3

    STORE1 --> CLOUD
    STORE2 --> CLOUD
    STORE3 --> CLOUD
    STORE1 --> FILE
    STORE2 --> FILE
    STORE3 --> FILE

    CLOUD -- "復元" --> STORE1
    CLOUD -- "復元" --> STORE2
    CLOUD -- "復元" --> STORE3
    FILE -- "復元" --> STORE1
    FILE -- "復元" --> STORE2
    FILE -- "復元" --> STORE3
```

### ビルドパイプライン

```mermaid
flowchart TD
    SRC["Dart ソース<br>lib/*.dart / web/main.dart"] --> COMPILE["dart compile js<br>web/main.dart"]
    COMPILE --> JS["web/main.dart.js"]

    subgraph WEB_OUT["Web 配信物 (nix build .#default)"]
        HTML["index.html"]
        CSS["styles.css"]
        JS2["main.dart.js"]
        ASSETS["assets/ (icons)"]
        MANIFEST["manifest.json"]
    end

    JS --> JS2
    HTML --> WEB_OUT
    CSS --> WEB_OUT
    ASSETS --> WEB_OUT
    MANIFEST --> WEB_OUT

    WEB_OUT --> BROWSER["ブラウザ表示"]

    subgraph APK["Android APK (nix run .#apk)"]
        WEBVIEW["Android WebView"]
        GRADLE["Gradle assembleDebug"]
    end

    WEB_OUT -- "assets にコピー" --> WEBVIEW
    WEBVIEW --> GRADLE
    GRADLE --> APK_FILE["calender.apk"]
```

## 実行方法

### ブラウザ (Dart → JS コンパイル)

```bash
# Dart SDK をインストール後
dart pub get
dart compile js web/main.dart -o web/main.dart.js
```

`web/index.html` をブラウザで開きます。

### 開発サーバー

```bash
# package.json の dev スクリプトを使用
bun install
bun run dev
```

### Nix (NixOS / Nix environment)

```bash
# 開発シェルに入る
nix develop

# Web ビルド
nix build .#default

# APK ビルド (Android)
nix run .#apk

# 開発サーバー起動
nix run .#dev
```

## 技術スタック

- **言語**: Dart (Web用に JavaScript へコンパイル)
- **UI**: 純粋な Dart HTML DOM API (フレームワーク未使用)
- **データ保存**: IndexedDB (ブラウザ)
- **アイコン**: Lucide (SVG アイコンライブラリ)
- **PWA対応**: Service Worker / Manifest
- **APK**: Android WebView (Gradle ビルド)
- **開発環境**: Nix flake / mise / bun / browser-sync
- **テーマ**: CSS カスタムプロパティ (Light/Dark/Auto)
