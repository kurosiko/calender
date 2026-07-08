"""Generate PowerPoint presentation for Calender project."""

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
import os

# Brand colors
BLUE = RGBColor(0x1A, 0x73, 0xE8)
DARK_BLUE = RGBColor(0x06, 0x2E, 0x6F)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
LIGHT_GRAY = RGBColor(0xF5, 0xF7, 0xFA)
DARK_GRAY = RGBColor(0x1A, 0x1C, 0x2E)
MID_GRAY = RGBColor(0x5F, 0x64, 0x70)
GREEN = RGBColor(0x0F, 0x9D, 0x58)
PURPLE = RGBColor(0xAB, 0x47, 0xBC)
ORANGE = RGBColor(0xF4, 0xB4, 0x00)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Calender_Overview.pptx")
OUT = os.path.abspath(OUT)

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)


def add_bg(slide, color=WHITE):
    bg = slide.background
    fill = bg.fill
    fill.solid()
    fill.fore_color.rgb = color


def add_shape_bg(slide, left, top, width, height, color, radius=None):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = color
    shape.line.fill.background()
    shape.shadow.inherit = False
    return shape


def add_textbox(slide, left, top, width, height, text, font_size=18, bold=False, color=DARK_GRAY, alignment=PP_ALIGN.LEFT, font_name="Yu Gothic"):
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(font_size)
    p.font.bold = bold
    p.font.color.rgb = color
    p.font.name = font_name
    p.alignment = alignment
    return txBox


def add_bullet_list(slide, left, top, width, height, items, font_size=16, color=DARK_GRAY):
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True
    for i, item in enumerate(items):
        if i == 0:
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        p.text = item
        p.font.size = Pt(font_size)
        p.font.color.rgb = color
        p.font.name = "Yu Gothic"
        p.space_after = Pt(6)
        p.level = 0
    return txBox


def slide_number(slide, num):
    add_textbox(slide, Inches(12.2), Inches(7.0), Inches(1), Inches(0.4),
                str(num), font_size=10, color=MID_GRAY, alignment=PP_ALIGN.RIGHT)


def add_card(slide, left, top, w, h, title, body_lines, accent_color=BLUE):
    shape = add_shape_bg(slide, left, top, w, h, WHITE)
    # Left accent bar
    bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, left, top + Inches(0.05), Inches(0.06), h - Inches(0.1))
    bar.fill.solid()
    bar.fill.fore_color.rgb = accent_color
    bar.line.fill.background()
    add_textbox(slide, left + Inches(0.3), top + Inches(0.15), w - Inches(0.5), Inches(0.4),
                title, font_size=15, bold=True, color=DARK_GRAY)
    add_bullet_list(slide, left + Inches(0.3), top + Inches(0.6), w - Inches(0.5), h - Inches(0.8),
                    body_lines, font_size=12, color=MID_GRAY)


# ============================================================
# Slide 1: Title
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])  # blank
add_bg(slide, BLUE)

add_textbox(slide, Inches(1.5), Inches(1.5), Inches(10), Inches(1.5),
            "Calender", font_size=64, bold=True, color=WHITE)
add_textbox(slide, Inches(1.5), Inches(3.0), Inches(10), Inches(1),
            "Dart 製シンプルスケジュール管理アプリ", font_size=28, color=RGBColor(0xD3, 0xE3, 0xFD))
add_textbox(slide, Inches(1.5), Inches(4.2), Inches(10), Inches(0.6),
            "月表示カレンダー + 週間授業スケジュール（大学生向け）", font_size=18, color=RGBColor(0xA4, 0xBB, 0xF8))

add_textbox(slide, Inches(1.5), Inches(5.8), Inches(5), Inches(0.4),
            "kurosiko / 2026", font_size=14, color=RGBColor(0x8A, 0xB4, 0xF8))

# Right icon square
icon_box = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(10), Inches(1.8), Inches(2.5), Inches(2.5))
icon_box.fill.solid()
icon_box.fill.fore_color.rgb = WHITE
icon_box.line.fill.background()

# Simple calendar icon using shapes
for i in range(3):
    row_y = Inches(0.35 + i * 0.55)
    for j in range(3):
        dot = slide.shapes.add_shape(MSO_SHAPE.OVAL,
                                     Inches(10.5 + j * 0.55), Inches(2.5 + row_y), Inches(0.3), Inches(0.3))
        dot.fill.solid()
        dot.fill.fore_color.rgb = BLUE
        dot.line.fill.background()

slide_number(slide, 1)

# ============================================================
# Slide 2: Agenda / 目次
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(5), Inches(0.7),
            "目次", font_size=36, bold=True, color=DARK_GRAY)

agenda_items = [
    ("01", "プロジェクト概要", "カレンダーアプリとしての全体像"),
    ("02", "技術スタック", "Dart, CSS, IndexedDB, Nix"),
    ("03", "アーキテクチャ", "2ファイル構成とデータの流れ"),
    ("04", "データモデル", "ScheduleEvent / RecurringSchedule"),
    ("05", "UI 画面構成", "月表示 + 週間授業 + ボトムシート"),
    ("06", "月表示の仕組み", "CSS Grid カレンダー"),
    ("07", "タイムライン", "ドラッグ操作による予定追加"),
    ("08", "データ永続化", "IndexedDB + JSONバックアップ"),
    ("09", "ビルドパイプライン", "Dart→JS→APK の流れ"),
    ("10", "まとめ", "プロジェクトの全体像"),
]
for i, (num, title, desc) in enumerate(agenda_items):
    y = Inches(1.6 + i * 0.55)
    add_textbox(slide, Inches(1.5), y, Inches(0.8), Inches(0.4),
                num, font_size=18, bold=True, color=BLUE)
    add_textbox(slide, Inches(2.4), y, Inches(3), Inches(0.4),
                title, font_size=16, bold=True, color=DARK_GRAY)
    add_textbox(slide, Inches(2.4), y + Inches(0.25), Inches(5), Inches(0.3),
                desc, font_size=11, color=MID_GRAY)

slide_number(slide, 2)

# ============================================================
# Slide 3: プロジェクト概要
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "プロジェクト概要", font_size=36, bold=True, color=DARK_GRAY)

add_card(slide, Inches(1), Inches(1.5), Inches(5.5), Inches(2.5),
         "Calender とは？", [
             "Dart で開発したシングルページ Web アプリケーション",
             "大学生の時間割管理を目的に設計",
             "月表示カレンダーと週間授業スケジュールの2画面",
             "フレームワーク未使用、純粋な dart:html DOM 操作",
             "ブラウザ単体で動作（PWA対応、スマホに追加可能）",
         ], BLUE)

add_card(slide, Inches(7), Inches(1.5), Inches(5.5), Inches(2.5),
         "主な機能", [
             "月表示: カレンダー + 予定一覧（アジェンダ表示）",
             "週間授業: 月〜金・1〜5限の時間割テーブル",
             "タイムライン: 1日の時間軸上で予定を確認・追加",
             "固定スケジュール: 毎週/第n週の定期予定",
             "テーマ切替: Light / Dark / Auto",
         ], GREEN)

add_card(slide, Inches(1), Inches(4.3), Inches(11.5), Inches(2.5),
         "ファイル構成（全コード 約2,250行）", [
             "lib/schedule.dart (169行) — データモデル: ScheduleEvent, RecurringSchedule, 予定自動生成ロジック",
             "web/main.dart (2,087行) — UI全般: カレンダー, タイムライン, 時間割, 設定, 同期, IndexedDB操作",
             "web/styles.css (2,064行) — スタイル: Light/Darkテーマ, レスポンシブ, アニメーション",
             "web/index.html (42行) — HTMLテンプレート + LucideアイコンCDN読み込み",
         ], PURPLE)

slide_number(slide, 3)

# ============================================================
# Slide 4: 技術スタック
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "技術スタック", font_size=36, bold=True, color=DARK_GRAY)

techs = [
    ("Dart", "言語", "Web用に JS へコンパイル\nSDK 3.11.6 (mise で管理)", BLUE),
    ("IndexedDB", "データ保存", "ブラウザ内蔵DB\nアプリ終了後もデータ保持", GREEN),
    ("CSS Custom Props", "スタイル", "Light/Dark/Auto テーマ\nレスポンシブ (360px〜)", PURPLE),
    ("Lucide", "アイコン", "SVG アイコンライブラリ\nCDN 経由で読み込み", ORANGE),
    ("Nix Flake", "ビルド/環境", "再現可能な開発環境\nnix build / nix run .#apk", DARK_BLUE),
    ("Gradle + WebView", "APK 出力", "Android WebView ラッパー\nWeb 資産を assets に配置", MID_GRAY),
]

for i, (name, role, desc, color) in enumerate(techs):
    col = i % 3
    row = i // 3
    x = Inches(1 + col * 4)
    y = Inches(1.5 + row * 2.8)
    shape = add_shape_bg(slide, x, y, Inches(3.7), Inches(2.5), LIGHT_GRAY)
    # top accent
    bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, y, Inches(3.7), Inches(0.05))
    bar.fill.solid()
    bar.fill.fore_color.rgb = color
    bar.line.fill.background()
    add_textbox(slide, x + Inches(0.3), y + Inches(0.2), Inches(3.1), Inches(0.4),
                name, font_size=20, bold=True, color=color)
    add_textbox(slide, x + Inches(0.3), y + Inches(0.7), Inches(3.1), Inches(0.3),
                role, font_size=12, bold=True, color=MID_GRAY)
    add_textbox(slide, x + Inches(0.3), y + Inches(1.1), Inches(3.1), Inches(1.2),
                desc, font_size=14, color=DARK_GRAY)

slide_number(slide, 4)

# ============================================================
# Slide 5: アーキテクチャ全体像
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "アーキテクチャ全体像", font_size=36, bold=True, color=DARK_GRAY)

# Three columns
cols = [
    ("データモデル\n(169行)", BLUE, [
        "ScheduleEvent",
        "  title, date, endDate",
        "  weekday, period",
        "  icon, note, origin",
        "",
        "RecurringSchedule",
        "  weekday, hour, minute",
        "  weekOfMonth",
        "",
        "generateRecurringEvents()",
        "  → 月ごとに自動生成",
    ]),
    ("UI ロジック\n(2,087行)", GREEN, [
        "月表示",
        "  カレンダーグリッド",
        "  予定一覧（アジェンダ）",
        "  タイムライン（日別詳細）",
        "",
        "週間授業",
        "  時間割テーブル",
        "  授業追加・編集",
        "",
        "設定系",
        "  固定スケジュール設定",
        "  同期・バックアップ",
        "  テーマ切替",
        "  スワイプ操作",
    ]),
    ("永続化層", PURPLE, [
        "IndexedDB",
        "  CalendarAppDB",
        "  3つの Object Store",
        "  monthly_events",
        "  class_schedule",
        "  recurring_schedules",
        "",
        "バックアップ",
        "  Cloud API (POST/GET)",
        "  JSON File (Export/Import)",
    ]),
]

for i, (title, color, items) in enumerate(cols):
    x = Inches(1 + i * 4)
    shape = add_shape_bg(slide, x, Inches(1.5), Inches(3.7), Inches(5.3), LIGHT_GRAY)
    bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, Inches(1.5), Inches(3.7), Inches(0.05))
    bar.fill.solid()
    bar.fill.fore_color.rgb = color
    bar.line.fill.background()
    add_textbox(slide, x + Inches(0.3), Inches(1.7), Inches(3.1), Inches(0.8),
                title, font_size=16, bold=True, color=color)

    lines = []
    for item in items:
        if item == "":
            lines.append("")
        else:
            lines.append(item)
    add_bullet_list(slide, x + Inches(0.25), Inches(2.6), Inches(3.2), Inches(4),
                    lines, font_size=12, color=DARK_GRAY)

# arrows between columns
for i in range(2):
    x = Inches(4.8 + i * 4)
    arrow = slide.shapes.add_shape(MSO_SHAPE.RIGHT_ARROW, x, Inches(3.5), Inches(0.4), Inches(0.4))
    arrow.fill.solid()
    arrow.fill.fore_color.rgb = MID_GRAY
    arrow.line.fill.background()

slide_number(slide, 5)

# ============================================================
# Slide 6: データモデル詳細
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "データモデル", font_size=36, bold=True, color=DARK_GRAY)

# ScheduleEvent card
add_card(slide, Inches(1), Inches(1.5), Inches(5.5), Inches(3),
         "ScheduleEvent — ふつうの予定", [
             "title:       予定のタイトル（例: 友人と食事）",
             "description: 詳細説明",
             "date:        開始日時 (DateTime?)",
             "endDate:     終了日時（時間範囲指定が可能）",
             "weekday:     曜日 1=月〜7=日（授業用）",
             "period:      時限 1〜5限（授業用）",
             "icon:        絵文字アイコン（例: 🍴）",
             "note:        自由メモ",
             "origin:      生成元の RecurringSchedule への参照",
         ], BLUE)

# RecurringSchedule card
add_card(slide, Inches(7), Inches(1.5), Inches(5.5), Inches(3),
         "RecurringSchedule — くりかえし予定", [
             "title:       予定のタイトル",
             "weekday:     曜日（1=月〜7=日）",
             "hour / minute: 開始時刻（デフォルト 8:00）",
             "weekOfMonth: 第n週 (null=毎週, 1=第1週〜4=第4週)",
             "icon:        絵文字アイコン",
             "enabled:     ON/OFF 切り替え",
             "note:        メモ",
             "",
             '例: {title:"線形代数", weekday:1, period:3}',
             '    → 毎週月曜3限に予定を自動生成',
         ], GREEN)

# generateRecurringEvents explanation
add_card(slide, Inches(1), Inches(4.8), Inches(11.5), Inches(2),
         "generateRecurringEvents(year, month) の動作", [
             "1. その月の日数を調べる（28〜31日）",
             "2. recurringSchedules の各項目に対して、その曜日と週指定に合う全日付を計算",
             "3. 各日付に ScheduleEvent を作成し、origin に元の RecurringSchedule への参照を設定",
             "4. できた全イベントのリストを返す → カレンダー表示のたびに毎回呼ばれる",
         ], ORANGE)

slide_number(slide, 6)

# ============================================================
# Slide 7: UI — 月表示
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "UI: 月表示（renderMonthView）", font_size=36, bold=True, color=DARK_GRAY)

# screen layout diagram
# calendar section
add_shape_bg(slide, Inches(1), Inches(1.5), Inches(5.5), Inches(4.5), RGBColor(0xE3, 0xF0, 0xFD))
add_textbox(slide, Inches(1.2), Inches(1.6), Inches(5), Inches(0.4),
            "📅 Calendar Section (height: 100dvh)", font_size=13, bold=True, color=DARK_BLUE)
# header bar
add_shape_bg(slide, Inches(1.3), Inches(2.1), Inches(5), Inches(0.6), WHITE)
add_textbox(slide, Inches(1.5), Inches(2.2), Inches(4), Inches(0.4),
            "◀  2026年 7月  ▶  ⚙  ☁", font_size=12, color=DARK_GRAY)
# grid area
add_shape_bg(slide, Inches(1.3), Inches(2.9), Inches(5), Inches(2.9), WHITE)
add_textbox(slide, Inches(1.5), Inches(3.0), Inches(4.8), Inches(2.5),
            "Calendar Grid (7列×6行)\n\n月 火 水 木 金 土 日\n 1  2  3  4  5  6  7\n 8  9 10 11 12 13 14\n...\n\nCSS Grid: repeat(7, 1fr)", font_size=11, color=MID_GRAY)

# schedule section
add_shape_bg(slide, Inches(7), Inches(1.5), Inches(5.5), Inches(4.5), RGBColor(0xE6, 0xF4, 0xEA))
add_textbox(slide, Inches(7.2), Inches(1.6), Inches(5), Inches(0.4),
            "📋 Schedule Section (scroll)", font_size=13, bold=True, color=RGBColor(0x0A, 0x7C, 0x47))
add_shape_bg(slide, Inches(7.3), Inches(2.1), Inches(5), Inches(3.7), WHITE)
add_textbox(slide, Inches(7.5), Inches(2.2), Inches(4.5), Inches(3.3),
            "スケジュール一覧\n\n7/7 (月) ─┬ 9:00 線形代数\n         └ 13:00 英語\n\n7/8 (火) ─┬ 10:30 ゼミ\n          └ 19:00 夕食\n\n7/11 (金) ─ 15:00 面談\n\n（過去の予定は非表示）", font_size=11, color=MID_GRAY)

# Bottom: key points
add_card(slide, Inches(1), Inches(6.2), Inches(11.5), Inches(0.9),
         "月表示のポイント", [
             "Calendar Section は height: 100dvh で画面全体を占有 / Grid は flex:1 で残りを均等分割",
         ], BLUE)

slide_number(slide, 7)

# ============================================================
# Slide 8: UI — タイムライン
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "UI: タイムライン（renderDayTimeline）", font_size=36, bold=True, color=DARK_GRAY)

add_card(slide, Inches(1), Inches(1.5), Inches(5.5), Inches(2.5),
         "タイムラインの仕組み", [
             "時間軸: 0:00 〜 23:00（hourHeight = 40px）",
             "各時間にグリッド線 + 時間ラベル（00:00, 01:00, ...）",
             "予定ブロックを絶対配置で描画",
             "  top = 開始時刻の分数 / 60 × hourHeight",
             "  height = 分数の長さ / 60 × hourHeight",
             '例: 9:30〜11:00 → top=380px, height=60px',
         ], BLUE)

add_card(slide, Inches(7), Inches(1.5), Inches(5.5), Inches(2.5),
         "ドラッグで予定追加", [
             "timeline-interaction-overlay を重ねて操作を検出",
             "onMouseDown  → 開始時刻を記録",
             "onMouseMove  → 選択範囲を青くハイライト",
             "onMouseUp    → 予定追加ダイアログ表示",
             "15分単位にスナップ（位置を丸める）",
             "クリックだけ → 自動で1時間の範囲を作る",
         ], GREEN)

add_card(slide, Inches(1), Inches(4.3), Inches(11.5), Inches(2.8),
         "イベントカードの色分け（getEventCardClass）", [
             'タイトルに「食事」「夕食」       → bg-food     (オレンジ系)',
             'タイトルに「フライト」「旅行」    → bg-flight   (青系)',
             'タイトルに「アルバイト」「シフト」→ color-orange (オレンジ)',
             'タイトルに「ゼミ」「レポート」    → color-purple (紫)',
             'タイトルに「英語」「数学」        → color-green  (緑)',
             '上記いずれにも該当しない           → color-blue   (青・デフォルト)',
         ], PURPLE)

slide_number(slide, 8)

# ============================================================
# Slide 9: データ永続化
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "データ永続化とバックアップ", font_size=36, bold=True, color=DARK_GRAY)

add_card(slide, Inches(1), Inches(1.5), Inches(5.5), Inches(2.5),
         "IndexedDB — DatabaseService", [
             "DB名: CalendarAppDB (version 1)",
             "3つの Object Store を管理",
             "  • monthly_events — 月表示用手動予定",
             "  • class_schedule — 週間授業の予定",
             "  • recurring_schedules — 固定スケジュール設定",
             "保存: clear() → 全件 add() の全置換方式",
             "読込: アプリ起動時に openCursor で全件取得",
             "保存タイミング: 追加・編集・削除のたびに即時",
         ], BLUE)

add_card(slide, Inches(7), Inches(1.5), Inches(5.5), Inches(2.5),
         "Cloud Sync (showSyncDialog)", [
             "同期先 API URL を入力",
             "保存: POST で JSON データを送信",
             "復元: GET でデータを取得し上書き",
             "API の認証等は利用者側で用意",
         ], GREEN)

add_card(slide, Inches(1), Inches(4.3), Inches(11.5), Inches(1.8),
         "JSON ファイルバックアップ", [
             "エクスポート: 3つのデータを1つのJSONにまとめ、Blob を作ってダウンロード (calendar_backup.json)",
             "インポート:   FileReader で読み込み → jsonDecode → applyImportData() でリストに反映 → IndexedDB 保存 → 画面更新",
         ], ORANGE)

# Data flow mini diagram
add_card(slide, Inches(1), Inches(6.3), Inches(11.5), Inches(0.9),
         "データの流れ", [
             "app起動 → IndexedDB 読込 → 3つのグローバルリスト → UI描画  /  編集 → リスト更新 → IndexedDB 保存 → UI再描画",
         ], PURPLE)

slide_number(slide, 9)

# ============================================================
# Slide 10: ビルドパイプライン
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "ビルドパイプライン", font_size=36, bold=True, color=DARK_GRAY)

# Web build flow
add_shape_bg(slide, Inches(1), Inches(1.5), Inches(11.5), Inches(1.5), LIGHT_GRAY)
add_textbox(slide, Inches(1.3), Inches(1.6), Inches(5), Inches(0.4),
            "🌐 Web ビルド", font_size=16, bold=True, color=BLUE)

add_textbox(slide, Inches(1.3), Inches(2.1), Inches(11), Inches(0.8),
            "Dart ソース → dart compile js → main.dart.js → web/ 一式を静的ホスティング\n"
            "開発時: bun run dev → nodemon(Dart監視) + browser-sync(ライブリロード) の並列起動",
            font_size=13, color=DARK_GRAY)

# APK build flow
add_shape_bg(slide, Inches(1), Inches(3.3), Inches(11.5), Inches(1.5), LIGHT_GRAY)
add_textbox(slide, Inches(1.3), Inches(3.4), Inches(5), Inches(0.4),
            "📱 APK ビルド", font_size=16, bold=True, color=GREEN)

add_textbox(slide, Inches(1.3), Inches(3.9), Inches(11), Inches(0.8),
            "1. dart compile js で web 資産を生成\n"
            "2. web/ 一式を android/app/src/main/assets/ にコピー\n"
            "3. ANDROID_SDK_ROOT を設定して gradle assembleDebug 実行 → calender.apk",
            font_size=13, color=DARK_GRAY)

# Nix flake
add_shape_bg(slide, Inches(1), Inches(5.1), Inches(11.5), Inches(1), LIGHT_GRAY)
add_textbox(slide, Inches(1.3), Inches(5.2), Inches(5), Inches(0.4),
            "❄ Nix Flake が提供するもの", font_size=16, bold=True, color=PURPLE)

add_textbox(slide, Inches(1.3), Inches(5.7), Inches(11), Inches(0.4),
            "devShells.default（Dart, Bun, Node.js, Java, Gradle, Android SDK） | packages.default（ビルド済みweb/） | apps.apk / apps.serve / apps.dev",
            font_size=12, color=DARK_GRAY)

# Deployment targets
add_card(slide, Inches(1), Inches(6.3), Inches(3.5), Inches(0.8),
         "配信先", ["ブラウザ (静的ホスティング)", "PWA (スマホに追加)"], BLUE)
add_card(slide, Inches(5), Inches(6.3), Inches(3.5), Inches(0.8),
         "APK 配布", ["Android WebView ラッパー", "Gradle でデバッグビルド"], GREEN)
add_card(slide, Inches(9), Inches(6.3), Inches(3.5), Inches(0.8),
         "開発環境", ["Nix flake (再現可能)", "mise (ツールバージョン管理)"], PURPLE)

slide_number(slide, 10)

# ============================================================
# Slide 11: 画面構成まとめ
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "画面構成とユーザーフロー", font_size=36, bold=True, color=DARK_GRAY)

# Main two tabs
add_card(slide, Inches(1), Inches(1.5), Inches(5.5), Inches(2.8),
         "タブ1: 月表示", [
             "Calendar Grid (画面全体) + 予定一覧 (下スクロール)",
             "← → ボタン or スワイプで月移動",
             "セルクリック → ボトムシートで日付詳細表示",
             "  タイムライン（0-23時）で時間を視覚確認",
             "  ドラッグで予定をクイック追加",
             "  カードクリックで予定編集・メモ追加",
         ], BLUE)

add_card(slide, Inches(7), Inches(1.5), Inches(5.5), Inches(2.8),
         "タブ2: 週間授業", [
             "時間割テーブル (5限×5曜日)",
             "空きコマ → +ボタン → 授業追加ダイアログ",
             "登録済み授業 → クリック → 編集ダイアログ",
             "授業名・教室・メモを編集可能",
             "削除ボタンで授業を時間割から除去",
         ], GREEN)

# Settings & Sync
add_card(slide, Inches(1), Inches(4.6), Inches(5.5), Inches(2.5),
         "設定ダイアログ（⚙）", [
             "固定スケジュールの一覧と編集",
             "曜日・開始時刻（iOS風ホイールピッカー）",
             "週指定（毎週 / 第1〜4週）",
             "「アイコンのみ表示」チェックボックス",
             "新規固定スケジュールの追加フォーム",
             "削除ボタン",
         ], ORANGE)

add_card(slide, Inches(7), Inches(4.6), Inches(5.5), Inches(2.5),
         "同期・バックアップ（☁）", [
             "Cloud Sync: API URLを指定してPOST/GET",
             "File Backup: JSONのエクスポート/インポート",
             "3つのデータストアを一括して扱う",
             "インポート後は自動でIndexedDB保存 + 再描画",
         ], PURPLE)

slide_number(slide, 11)

# ============================================================
# Slide 12: 特筆すべき技術的ポイント
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, WHITE)
add_textbox(slide, Inches(1), Inches(0.5), Inches(10), Inches(0.7),
            "特筆すべき技術的ポイント", font_size=36, bold=True, color=DARK_GRAY)

highlights = [
    ("フレームワーク不使用", "React, Vue, Flutter 等を一切使わず、dart:html の DOM API のみで SPA を構築。全コードが自明で依存ゼロ。", BLUE),
    ("固定スケジュールの動的生成", "RecurringSchedule から月ごとに ScheduleEvent を自動生成。origin 参照で生成元への変更反映を実現。", GREEN),
    ("HTML/CSSのみのホイールピッカー", "overflow-y: scroll + scrollend イベントでiOS風ピッカーを実装。外部ライブラリ不要。", PURPLE),
    ("タイムラインドラッグ", "overlay要素 + MouseEvent でドラッグ範囲選択。15分単位スナップ + 開始位置マーカーで直感的操作。", ORANGE),
    ("CSS変数によるテーマ", ":root と [data-theme=\"dark\"] で全色を変数管理。prefers-color-scheme メディアクエリで Auto 対応。", BLUE),
    ("Nix による再現可能ビルド", "flake.nix で Dart SDK, Android SDK, Gradle を含む完全な開発環境を宣言的に定義。", DARK_BLUE),
]

for i, (title, desc, color) in enumerate(highlights):
    y = Inches(1.5 + i * 0.95)
    shape = add_shape_bg(slide, Inches(1), y, Inches(11.5), Inches(0.85), LIGHT_GRAY)
    bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1), y, Inches(0.06), Inches(0.85))
    bar.fill.solid()
    bar.fill.fore_color.rgb = color
    bar.line.fill.background()
    add_textbox(slide, Inches(1.3), y + Inches(0.08), Inches(3), Inches(0.35),
                title, font_size=15, bold=True, color=color)
    add_textbox(slide, Inches(1.3), y + Inches(0.42), Inches(10.7), Inches(0.35),
                desc, font_size=12, color=MID_GRAY)

slide_number(slide, 12)

# ============================================================
# Slide 13: まとめ
# ============================================================
slide = prs.slides.add_slide(prs.slide_layouts[6])
add_bg(slide, BLUE)

add_textbox(slide, Inches(1.5), Inches(1.5), Inches(10), Inches(1),
            "まとめ", font_size=48, bold=True, color=WHITE)

summary_points = [
    "Dart だけで作った大学生向けスケジュール管理アプリ",
    "2ファイル・約2,250行のミニマルな設計",
    "月表示カレンダー + 週間授業時間割の2画面構成",
    "固定スケジュールの自動生成で定期予定を効率的に管理",
    "タイムラインドラッグで直感的な予定追加",
    "IndexedDB 永続化 + JSON/Cloud バックアップ",
    "Nix flake による再現可能な開発環境とAPKビルド",
    "フレームワーク未使用・依存ゼロの純粋 DOM 操作",
]

for i, pt in enumerate(summary_points):
    y = Inches(2.8 + i * 0.55)
    dot = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(2), y + Inches(0.05), Inches(0.15), Inches(0.15))
    dot.fill.solid()
    dot.fill.fore_color.rgb = WHITE
    dot.line.fill.background()
    add_textbox(slide, Inches(2.4), y, Inches(9), Inches(0.4),
                pt, font_size=16, color=RGBColor(0xD3, 0xE3, 0xFD))

add_textbox(slide, Inches(1.5), Inches(6.8), Inches(10), Inches(0.4),
            "https://github.com/kurosiko/calender", font_size=12, color=RGBColor(0x8A, 0xB4, 0xF8),
            alignment=PP_ALIGN.RIGHT)

slide_number(slide, 13)

# Save
prs.save(OUT)
print(f"Saved: {OUT}")
print(f"Slides: {len(prs.slides)}")
