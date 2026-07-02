import 'dart:html';
import 'dart:async';
import 'dart:indexed_db' as idb;
import 'dart:convert';
import 'dart:js' as js;
import 'package:calender/schedule.dart';

class DatabaseService {
  static const String dbName = 'CalendarAppDB';
  static const int dbVersion = 1;
  idb.Database? _db;

  Future<void> init() async {
    if (window.indexedDB == null) {
      print('IndexedDB is not supported on this browser.');
      return;
    }
    try {
      _db = await window.indexedDB!.open(dbName, version: dbVersion,
          onUpgradeNeeded: (idb.VersionChangeEvent e) {
        final db = e.target.result as idb.Database;
        final storeNames = db.objectStoreNames;
        if (storeNames == null || !storeNames.contains('monthly_events')) {
          db.createObjectStore('monthly_events', keyPath: 'id', autoIncrement: true);
        }
        if (storeNames == null || !storeNames.contains('class_schedule')) {
          db.createObjectStore('class_schedule', keyPath: 'id', autoIncrement: true);
        }
        if (storeNames == null || !storeNames.contains('recurring_schedules')) {
          db.createObjectStore('recurring_schedules', keyPath: 'id', autoIncrement: true);
        }
      });
    } catch (e) {
      print('IndexedDB initialization failed: $e');
    }
  }

  Future<void> saveAll() async {
    if (_db == null) return;
    try {
      // 1. monthly_events
      final txn1 = _db!.transaction('monthly_events', 'readwrite');
      final store1 = txn1.objectStore('monthly_events');
      await store1.clear();
      for (int i = 0; i < monthlyEvents.length; i++) {
        final json = monthlyEvents[i].toJson()..['id'] = i;
        store1.add(json);
      }
      await txn1.completed;

      // 2. class_schedule
      final txn2 = _db!.transaction('class_schedule', 'readwrite');
      final store2 = txn2.objectStore('class_schedule');
      await store2.clear();
      for (int i = 0; i < classSchedule.length; i++) {
        final json = classSchedule[i].toJson()..['id'] = i;
        store2.add(json);
      }
      await txn2.completed;

      // 3. recurring_schedules
      final txn3 = _db!.transaction('recurring_schedules', 'readwrite');
      final store3 = txn3.objectStore('recurring_schedules');
      await store3.clear();
      for (int i = 0; i < recurringSchedules.length; i++) {
        final json = recurringSchedules[i].toJson()..['id'] = i;
        store3.add(json);
      }
      await txn3.completed;
    } catch (e) {
      print('Failed to save to IndexedDB: $e');
    }
  }

  Future<void> loadAll() async {
    if (_db == null) return;
    try {
      // 1. monthly_events
      final txn1 = _db!.transaction('monthly_events', 'readonly');
      final store1 = txn1.objectStore('monthly_events');
      final List<dynamic> records1 = [];
      await store1.openCursor(autoAdvance: true).forEach((cursor) {
        records1.add(cursor.value);
      });
      await txn1.completed;
      if (records1.isNotEmpty) {
        monthlyEvents.clear();
        for (final r in records1) {
          monthlyEvents.add(ScheduleEvent.fromJson(Map<String, dynamic>.from(r as Map)));
        }
      }

      // 2. class_schedule
      final txn2 = _db!.transaction('class_schedule', 'readonly');
      final store2 = txn2.objectStore('class_schedule');
      final List<dynamic> records2 = [];
      await store2.openCursor(autoAdvance: true).forEach((cursor) {
        records2.add(cursor.value);
      });
      await txn2.completed;
      if (records2.isNotEmpty) {
        classSchedule.clear();
        for (final r in records2) {
          classSchedule.add(ScheduleEvent.fromJson(Map<String, dynamic>.from(r as Map)));
        }
      }

      // 3. recurring_schedules
      final txn3 = _db!.transaction('recurring_schedules', 'readonly');
      final store3 = txn3.objectStore('recurring_schedules');
      final List<dynamic> records3 = [];
      await store3.openCursor(autoAdvance: true).forEach((cursor) {
        records3.add(cursor.value);
      });
      await txn3.completed;
      if (records3.isNotEmpty) {
        recurringSchedules.clear();
        for (final r in records3) {
          recurringSchedules.add(RecurringSchedule.fromJson(Map<String, dynamic>.from(r as Map)));
        }
      }
    } catch (e) {
      print('Failed to load from IndexedDB: $e');
    }
  }
}

final dbService = DatabaseService();


final content = querySelector('#appContent') as Element;

// Lucide アイコンシステム
void refreshLucideIcons() {
  try {
    (js.context['refreshLucideIcons'] as js.JsFunction).apply([]);
  } catch (_) {}
}

Element svgIcon(String name, {double size = 22, List<String> extraClasses = const []}) {
  final span = SpanElement()
    ..classes.addAll(['icon', 'icon-${name}', ...extraClasses])
    ..setAttribute('aria-hidden', 'true');
  final i = Element.tag('i')
    ..setAttribute('data-lucide', name);
  span.append(i);
  span.style.width = '${size}px';
  span.style.height = '${size}px';
  return span;
}

void setThemeIcon(ButtonElement btn, String theme) {
  final name = theme == 'light' ? 'sun' : (theme == 'dark' ? 'moon' : 'sun-moon');
  btn.children.clear();
  btn.append(svgIcon(name, size: 20));
  btn.setAttribute('aria-label', 'テーマ: $name');
  refreshLucideIcons();
}

ButtonElement makeCloseButton() {
  return ButtonElement()
    ..classes.add('close-btn')
    ..title = '閉じる'
    ..setAttribute('aria-label', '閉じる')
    ..append(svgIcon('x', size: 20));
}

int selectedYear = now.year;
int selectedMonth = now.month;
int currentPage = 0; // 0: 月表示, 1: 週間授業

// イベントの背景やカラーを割り当てるヘルパー
String getEventCardClass(ScheduleEvent event) {
  final title = event.title.toLowerCase();
  if (title.contains('食事') || title.contains('夕食') || title.contains('ランチ') || title.contains('ディナー') || title.contains('面談') || title.contains('友人と')) {
    return 'bg-food';
  } else if (title.contains('フライト') || title.contains('飛行機') || title.contains('旅行') || title.contains('バルセロナ')) {
    return 'bg-flight';
  }
  
  // デフォルトカラー分類
  if (title.contains('アルバイト') || title.contains('シフト') || title.contains('ゴミ')) {
    return 'color-orange';
  } else if (title.contains('ゼミ') || title.contains('レポート') || title.contains('自習')) {
    return 'color-purple';
  } else if (title.contains('英語') || title.contains('線形代数') || title.contains('物理') || title.contains('プログラミング')) {
    return 'color-green';
  }
  
  return 'color-blue';
}

String formatTime(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

// 日本の祝日判定関数
bool isJapaneseHoliday(DateTime date) {
  final year = date.year;
  final month = date.month;
  final day = date.day;
  final weekday = date.weekday;

  if (month == 1 && day == 1) return true;
  if (month == 1 && weekday == 1 && (day >= 8 && day <= 14)) return true;
  if (month == 2 && day == 11) return true;
  if (month == 3 && (day == 20 || day == 21)) return true;
  if (month == 4 && day == 29) return true;
  if (month == 5 && day == 3) return true;
  if (month == 5 && day == 4) return true;
  if (month == 5 && day == 5) return true;
  if (month == 7 && weekday == 1 && (day >= 15 && day <= 21)) return true;
  if (month == 8 && day == 11) return true;
  if (month == 9 && weekday == 1 && (day >= 15 && day <= 21)) return true;
  if (month == 9 && (day == 22 || day == 23)) return true;
  if (month == 10 && weekday == 1 && (day >= 8 && day <= 14)) return true;
  if (month == 11 && day == 3) return true;
  if (month == 11 && day == 23) return true;
  if (month == 12 && day == 23) return true;
  
  return false;
}

void main() async {
  setupSwipeGestures();
  setupThemeToggle();

  // IndexedDBの初期化とデータロード
  await dbService.init();
  await dbService.loadAll();

  renderCurrentPage();
  renderViewTabs();
}

// ===== テーマ管理 =====
String _currentTheme = 'auto';

void setupThemeToggle() {
  final saved = window.localStorage['theme'];
  _currentTheme = (saved == 'light' || saved == 'dark' || saved == 'auto') ? saved as String : 'auto';
  applyTheme(_currentTheme);

  final btn = querySelector('#themeToggle');
  if (btn == null) return;
  btn.onClick.listen((_) {
    String next;
    if (_currentTheme == 'auto') {
      next = 'light';
    } else if (_currentTheme == 'light') {
      next = 'dark';
    } else {
      next = 'auto';
    }
    _currentTheme = next;
    applyTheme(next);
    window.localStorage['theme'] = next;
  });
}

void applyTheme(String theme) {
  final doc = document.documentElement;
  if (doc == null) return;
  if (theme == 'auto') {
    doc.setAttribute('data-theme', 'auto');
  } else {
    doc.setAttribute('data-theme', theme);
  }
  updateThemeIcon(theme);
}

void updateThemeIcon(String theme) {
  final btn = querySelector('#themeToggle');
  if (btn == null) return;
  if (btn is ButtonElement) {
    setThemeIcon(btn, theme);
  }
}

void setupSwipeGestures() {
  double startX = 0;
  double startY = 0;
  bool isHorizontalSwipe = false;
  
  content.onTouchStart.listen((e) {
    final touch = e.touches!.first;
    startX = touch.client.x.toDouble();
    startY = touch.client.y.toDouble();
    isHorizontalSwipe = false;
  });
  
  content.onTouchMove.listen((e) {
    if (e.touches!.isEmpty) return;
    final touch = e.touches!.first;
    final deltaX = touch.client.x - startX;
    final deltaY = touch.client.y - startY;
    
    if (!isHorizontalSwipe && (deltaX.abs() > deltaY.abs() * 2)) {
      isHorizontalSwipe = true;
      e.preventDefault();
    }
  });
  
  content.onTouchEnd.listen((e) {
    if (!isHorizontalSwipe) return;
    
    final touch = e.changedTouches!.first;
    final deltaX = touch.client.x - startX;
    final deltaY = touch.client.y - startY;
    
    if (deltaX.abs() > 50 && deltaX.abs() > deltaY.abs()) {
      if (currentPage == 0) {
        if (deltaX > 0) {
          adjustMonth(-1);
        } else {
          adjustMonth(1);
        }
      
      } else if (currentPage == 1 && deltaX > 0) {
        switchToPage(0);
      }
    }
  });
  
  content.onMouseDown.listen((e) {
  
  });
  
  content.onScroll.listen((e) {
  
  });
}

// ===== タブ切り替え =====
void switchToPage(int page) {
  if (currentPage == page) return;
  currentPage = page;
  renderCurrentPage();
  renderViewTabs();
}

void renderCurrentPage() {
  if (currentPage == 0) {
    renderMonthView();
  } else {
    renderClassWeekView();
  }
}

// ヘッダー内タブバー (lucide アイコン)
void renderViewTabs() {
  final container = querySelector('#viewTabs');
  if (container == null) return;
  container.children.clear();

  final tabs = [
    {'icon': 'calendar-days', 'label': '月表示'},
    {'icon': 'clock', 'label': '時間割'},
  ];

  for (int i = 0; i < tabs.length; i++) {
    final tab = ButtonElement()..classes.add('view-tab');
    tab.append(svgIcon(tabs[i]['icon']!, size: 20));
    tab.append(SpanElement()..text = tabs[i]['label']);
    if (i == currentPage) tab.classes.add('active');
    final page = i;
    tab.onClick.listen((_) => switchToPage(page));
    container.append(tab);
  }
  refreshLucideIcons();
}

void renderMonthView() {
  content.children.clear();

  // カレンダーセクション（画面1画面に収まる固定エリア）
  final calendarSection = DivElement()..classes.addAll(['calendar-section', 'fade-in']);

  final header = DivElement()..classes.add('calendar-header');
  final title = HeadingElement.h2()
    ..append(SpanElement()..classes.add('year')..text = '$selectedYear年')
    ..append(SpanElement()..classes.add('month')..text = '$selectedMonth');
  final controls = DivElement()..classes.add('calendar-controls');

  final prevButton = ButtonElement()
    ..classes.add('nav-button')
    ..title = '前月'
    ..setAttribute('aria-label', '前月');
  prevButton.append(svgIcon('chevron-left', size: 24));
  prevButton.onClick.listen((_) => adjustMonth(-1));

  final nextButton = ButtonElement()
    ..classes.add('nav-button')
    ..title = '次月'
    ..setAttribute('aria-label', '次月');
  nextButton.append(svgIcon('chevron-right', size: 24));
  nextButton.onClick.listen((_) => adjustMonth(1));

  final settingsButton = ButtonElement()
    ..classes.add('settings-button')
    ..title = '設定'
    ..setAttribute('aria-label', '設定');
  settingsButton.append(svgIcon('settings', size: 22));
  settingsButton.onClick.listen((_) => showSettingsDialog());

  final syncButton = ButtonElement()
    ..classes.add('settings-button')
    ..title = '同期・バックアップ'
    ..setAttribute('aria-label', '同期・バックアップ');
  syncButton.append(svgIcon('cloud', size: 22));
  syncButton.onClick.listen((_) => showSyncDialog());

  controls.children.addAll([prevButton, nextButton, settingsButton, syncButton]);
  header.children.addAll([title, controls]);

  calendarSection.children.add(header);
  calendarSection.children.add(renderCalendarGrid(selectedYear, selectedMonth));

  content.children.add(calendarSection);

  // スケジュール一覧セクション（下に分離、縦スクロール・グリッド付き）
  final scheduleSection = DivElement()..classes.addAll(['schedule-section', 'fade-in']);
  scheduleSection.children.add(renderMonthlyEventSummary());
  content.children.add(scheduleSection);

  refreshLucideIcons();
}

void adjustMonth(int delta) {
  selectedMonth += delta;
  if (selectedMonth < 1) {
    selectedMonth = 12;
    selectedYear -= 1;
  } else if (selectedMonth > 12) {
    selectedMonth = 1;
    selectedYear += 1;
  }
  renderMonthView();
}

Element renderCalendarGrid(int year, int month) {
  final grid = DivElement()..classes.add('calendar-grid');
  final weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  for (int i = 0; i < weekdayLabels.length; i++) {
    final label = weekdayLabels[i];
    final labelCell = DivElement()..classes.add('day-label');
    
    // その曜日に設定されている固定スケジュールを抽出
    final weekday = i + 1;
    final schedulesForDay = recurringSchedules.where((s) => s.weekday == weekday).toList();
    
    if (schedulesForDay.isNotEmpty) {
      final container = DivElement()..classes.add('day-label-fixed-container');
      for (final s in schedulesForDay) {
        final itemDiv = DivElement()
          ..classes.add('day-label-fixed-item')
          ..title = '${s.title}: ${s.description}';
        itemDiv.append(svgIcon('cog', size: 12));
        if (!s.showIconOnly) {
          itemDiv.append(SpanElement()..text = s.title);
        }
        container.children.add(itemDiv);
      }
      labelCell.children.add(container);
    }
    
    labelCell.children.add(SpanElement()..text = label);
    
    if (i == 5) {
      labelCell.classes.add('saturday');
    } else if (i == 6) {
      labelCell.classes.add('sunday');
    }
    grid.children.add(labelCell);
  }

  final firstDay = DateTime(year, month, 1);
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final startWeekday = firstDay.weekday == 7 ? 7 : firstDay.weekday;
  final fixedEventsForMonth = getFixedEventsForMonth(year, month);
  final manualEventsForMonth = getManualEventsForMonth(year, month);

  for (int i = 1; i < startWeekday; i++) {
    final emptyCell = DivElement()..classes.addAll(['calendar-cell', 'empty']);
    grid.children.add(emptyCell);
  }

  for (int day = 1; day <= daysInMonth; day++) {
    final date = DateTime(year, month, day);
    final weekday = date.weekday;
    final fixedEvents = fixedEventsForMonth.where((event) => event.date != null && event.date!.day == day).toList();
    final manualEvents = manualEventsForMonth.where((event) => event.date != null && event.date!.day == day).toList();

    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isHoliday = isJapaneseHoliday(date);
    final cell = DivElement()..classes.add('calendar-cell');
    if (isToday) cell.classes.add('today');
    if (fixedEvents.isNotEmpty) cell.classes.add('has-fixed-event');
    
    if (weekday == 6) {
      cell.classes.add('saturday');
    } else if (weekday == 7 || isHoliday) {
      cell.classes.add('sunday');
    }

    final number = DivElement()..classes.add('date-number')..text = '$day';
    cell.children.add(number);

    if (manualEvents.isNotEmpty) {
      final eventChip = DivElement()..classes.add('event-chip');
      if (manualEvents.first.icon != null && manualEvents.first.icon!.isNotEmpty) {
        eventChip.append(SpanElement()..text = '${manualEvents.first.icon} ${manualEvents.first.title}');
      } else {
        eventChip.append(svgIcon('pin', size: 14));
        eventChip.append(SpanElement()..text = ' ${manualEvents.first.title}');
      }
      cell.children.add(eventChip);
    }

    cell.onClick.listen((_) {
      showDayDetails(date, fixedEvents, manualEvents);
    });

    grid.children.add(cell);
  }

  return grid;
}

List<ScheduleEvent> getManualEventsForMonth(int year, int month) {
  return monthlyEvents.where((event) {
    return event.date != null && event.date!.year == year && event.date!.month == month;
  }).toList();
}

List<ScheduleEvent> getFixedEventsForMonth(int year, int month) {
  return generateRecurringEvents(year, month);
}

// Googleカレンダー風アジェンダビュー (画像1の完全再現)
Element renderMonthlyEventSummary() {
  final fixedEvents = getFixedEventsForMonth(selectedYear, selectedMonth);
  final manualEvents = getManualEventsForMonth(selectedYear, selectedMonth);

  final summary = DivElement()..classes.add('event-list');
  summary.children.add(HeadingElement.h3()..text = 'スケジュール一覧');

  if (fixedEvents.isEmpty && manualEvents.isEmpty) {
    summary.children.add(ParagraphElement()..classes.add('no-events')..text = '今月の予定はありません。');
    return summary;
  }

  // 日付ごとにイベントをグループ化
  final eventsByDay = <int, List<ScheduleEvent>>{};

  for (final event in [...fixedEvents, ...manualEvents]) {
    if (event.date != null) {
      final day = event.date!.day;
      eventsByDay.putIfAbsent(day, () => []).add(event);
    }
  }

  // 日付順にソートして描画
  final sortedDays = eventsByDay.keys.toList()..sort();
  final weekdayLabelsShort = ['月', '火', '水', '木', '金', '土', '日'];

  for (final day in sortedDays) {
    final date = DateTime(selectedYear, selectedMonth, day);
    final today = DateTime(now.year, now.month, now.day);
    
    // 今日より前の日付（過去の予定）は表示しない
    if (date.isBefore(today)) continue;

    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final group = DivElement()..classes.add('agenda-group');
    if (isToday) group.classes.add('is-today');

    final dateCol = DivElement()..classes.add('agenda-date');
    dateCol.children.add(SpanElement()..classes.add('agenda-day-name')..text = weekdayLabelsShort[date.weekday - 1]);
    dateCol.children.add(SpanElement()..classes.add('agenda-day-num')..text = '$day');
    group.children.add(dateCol);

    final eventsCol = DivElement()..classes.add('agenda-events');
    final dayEvents = eventsByDay[day]!..sort((a, b) => a.date!.compareTo(b.date!));

    for (final event in dayEvents) {
      final isFixed = fixedEvents.contains(event);
      final cardClass = getEventCardClass(event);
      
      final card = DivElement()..classes.addAll(['event-card', cardClass]);
      
      final titleRow = DivElement()..classes.add('event-title-row');
      if (isFixed) titleRow.append(svgIcon('cog', size: 14));
      if (event.icon != null && event.icon!.isNotEmpty) titleRow.append(SpanElement()..text = '${event.icon} ');
      titleRow.append(SpanElement()..text = event.title);
      card.children.add(titleRow);

      String timeText;
      if (event.hasTimeRange) {
        timeText = '${formatTime(event.date!.hour * 60 + event.date!.minute)} 〜 ${formatTime(event.endDate!.hour * 60 + event.endDate!.minute)}';
      } else {
        timeText = formatTime(event.date!.hour * 60 + event.date!.minute);
      }
      
      card.children.add(ParagraphElement()..text = '$timeText - ${event.description}');
      
      // メモが存在する場合はカード内に表示
      if (event.note != null && event.note!.isNotEmpty) {
        final noteRow = DivElement()..classes.add('event-note');
        noteRow.append(svgIcon('sticky-note', size: 12));
        noteRow.append(SpanElement()..text = ' ${event.note!}');
        card.children.add(noteRow);
      }

      // クリック時に予定編集・メモ追加ダイアログを表示するイベントリスナーを追加
      card.onClick.listen((_) {
        showEditEventDialog(event);
      });

      eventsCol.children.add(card);
    }
    
    group.children.add(eventsCol);
    summary.children.add(group);
  }

  // もし今日以降のイベントが1つも無かった場合
  if (summary.children.length == 1) {
    summary.children.add(ParagraphElement()..classes.add('no-events')..text = '以降の予定はありません。');
  }

  return summary;
}

// ボトムシートによる日付詳細とタイムライン (画像2の再現)
void showDayDetails(DateTime date, List<ScheduleEvent> fixedEvents, List<ScheduleEvent> manualEvents) {
  final backdrop = DivElement()..classes.addAll(['overlay-backdrop', 'fade-in']);
  final sheet = DivElement()..classes.add('bottom-sheet');

  final header = DivElement()..classes.add('sheet-header');
  header.children.add(HeadingElement.h3()..text = '${date.month}月${date.day}日のタイムライン');
  
  final closeButton = makeCloseButton();
  closeButton.onClick.listen((_) => backdrop.remove());
  header.children.add(closeButton);

  sheet.children.add(header);

  // --- 【新機能】今日の予定クイック編集用リストをタイムラインの上部に設置 ---
  final allEvents = [...fixedEvents, ...manualEvents];
  if (allEvents.isNotEmpty) {
    final quickList = DivElement()..classes.add('day-events-quick-list');
    quickList.children.add(DivElement()
      ..classes.add('day-events-quick-list-title')
      ..text = '登録済みの予定（クリックして編集/メモ追加）');
      
    for (final event in allEvents) {
      final isFixed = fixedEvents.contains(event);
      final cardClass = getEventCardClass(event);

      final card = DivElement()
        ..classes.addAll(['event-card', cardClass, 'compact']);

      final titleRow = DivElement()..classes.add('event-title-row');
      if (isFixed) titleRow.append(svgIcon('cog', size: 14));
      if (event.icon != null && event.icon!.isNotEmpty) titleRow.append(SpanElement()..text = '${event.icon} ');
      titleRow.append(SpanElement()..text = event.title);
      card.children.add(titleRow);
      
      if (event.note != null && event.note!.isNotEmpty) {
        final noteRow = DivElement()..classes.add('event-note');
        noteRow.append(svgIcon('sticky-note', size: 12));
        noteRow.append(SpanElement()..text = ' ${event.note!}');
        card.children.add(noteRow);
      }
      
      card.onClick.listen((_) {
        backdrop.remove(); // 予定詳細を一度閉じる
        showEditEventDialog(event);
      });
      quickList.children.add(card);
    }
    sheet.children.add(quickList);
  }
  // -----------------------------------------------------------------

  sheet.children.add(renderDayTimeline(date, fixedEvents, manualEvents));
  sheet.children.add(renderAddEventForm(date));

  backdrop.onClick.listen((event) {
    if (event.target == backdrop) backdrop.remove();
  });

  backdrop.children.add(sheet);
  document.body?.children.add(backdrop);
  refreshLucideIcons();
}

// 予定の編集・メモ追加用のスライドダイアログ (ボトムシート)
void showEditEventDialog(ScheduleEvent event) {
  final backdrop = DivElement()..classes.addAll(['overlay-backdrop', 'fade-in']);
  final sheet = DivElement()..classes.add('bottom-sheet');

  final header = DivElement()..classes.add('sheet-header');
  header.children.add(HeadingElement.h3()..text = '予定の編集・メモ追加');
  
  final closeButton = makeCloseButton();
  closeButton.onClick.listen((_) => backdrop.remove());
  header.children.add(closeButton);
  sheet.children.add(header);

  // 予定タイトル入力
  final titleInput = InputElement()
    ..type = 'text'
    ..placeholder = '予定タイトル'
    ..value = event.title
    ..classes.addAll(['text-input', 'title-input']);

  // 詳細・説明入力
  final descInput = TextAreaElement()
    ..placeholder = '詳細・説明'
    ..value = event.description
    ..classes.add('textarea-input')
    ..style.marginTop = '12px';

  // メモ入力 (新機能)
  final memoTitle = ParagraphElement()
    ..text = 'この予定のメモ (プライベートノート)'
    ..classes.add('form-section-label');

  final memoInput = TextAreaElement()
    ..placeholder = 'ここに追加のメモやタスクを入力できます...'
    ..value = event.note ?? ''
    ..classes.add('textarea-input')
    ..style.minHeight = '80px';

  // 保存ボタン
  final saveButton = ButtonElement()
    ..text = '保存する'
    ..classes.addAll(['save-btn', 'block']);

  saveButton.onClick.listen((_) {
    final title = titleInput.value?.trim() ?? '';
    if (title.isEmpty) {
      window.alert('タイトルを入力してください。');
      return;
    }

    // インプレースで直接オブジェクトを書き換える
    event.title = title;
    event.description = descInput.value?.trim() ?? '';
    event.note = memoInput.value?.trim();

    // 固定スケジュールの生成元 (RecurringSchedule) も同期して更新する
    if (event.origin != null) {
      event.origin!.title = title;
      event.origin!.description = descInput.value?.trim() ?? '';
      event.origin!.note = memoInput.value?.trim();
    }

    dbService.saveAll();
    renderMonthView(); // カレンダーメインビューを再描画
    backdrop.remove(); // 編集ダイアログを閉じる

    // シームレスに元の日にち詳細タイムラインを再表示
    if (event.date != null) {
      final date = event.date!;
      final fixed = getFixedEventsForMonth(date.year, date.month).where((ev) => ev.date != null && ev.date!.day == date.day).toList();
      final manual = getManualEventsForMonth(date.year, date.month).where((ev) => ev.date != null && ev.date!.day == date.day).toList();
      showDayDetails(date, fixed, manual);
    }
  });

  sheet.children.addAll([
    titleInput,
    descInput,
    memoTitle,
    memoInput,
    saveButton
  ]);

  // 手動で追加した予定であれば、削除ボタンも表示する
  final isFixed = event.origin != null;
  if (!isFixed) {
    final deleteButton = ButtonElement()
      ..text = '予定を削除'
      ..classes.addAll(['save-btn', 'danger', 'block'])
      ..style.marginTop = '8px';
    
    deleteButton.onClick.listen((_) {
      if (window.confirm('この予定を削除してもよろしいですか？')) {
        monthlyEvents.remove(event);
        dbService.saveAll();
        renderMonthView();
        backdrop.remove();

        // 削除後にタイムラインを再オープン
        if (event.date != null) {
          final date = event.date!;
          final fixed = getFixedEventsForMonth(date.year, date.month).where((ev) => ev.date != null && ev.date!.day == date.day).toList();
          final manual = getManualEventsForMonth(date.year, date.month).where((ev) => ev.date != null && ev.date!.day == date.day).toList();
          showDayDetails(date, fixed, manual);
        }
      }
    });
    sheet.children.add(deleteButton);
  }

  backdrop.onClick.listen((e) {
    if (e.target == backdrop) backdrop.remove();
  });

  backdrop.children.add(sheet);
  document.body?.children.add(backdrop);
}
// 縦スクロール型ピッカー
// overflow-y: scroll で自然にスクロール + scrollTop で位置制御
Element createPickerWheel({
  required int value,
  required int min,
  required int max,
  required int step,
  required void Function(int) onChange,
  String Function(int)? formatLabel,
}) {
  final fmt = formatLabel ?? ((int v) => v.toString().padLeft(2, '0'));
  const itemH = 34;
  const visibleH = itemH * 3;
  final itemCount = (max - min) ~/ step + 1;
  final padH = visibleH ~/ 2 - itemH ~/ 2;

  final outer = DivElement()..classes.add('picker-wheel-outer');
  final track = DivElement()..classes.add('picker-wheel-track');

  final topPad = DivElement()..style.height = '${padH}px';
  final botPad = DivElement()..style.height = '${padH}px';
  final topSnap = DivElement()
    ..classes.add('picker-wheel-snap')
    ..style.height = '${padH}px';
  final botSnap = DivElement()
    ..classes.add('picker-wheel-snap')
    ..style.height = '${padH}px';
  track.append(topPad);
  track.append(topSnap);

  final List<DivElement> items = [];
  for (int i = 0; i < itemCount; i++) {
    final v = min + i * step;
    final item = DivElement()
      ..classes.add('picker-wheel-item')
      ..text = fmt(v)
      ..style.height = '${itemH}px';
    items.add(item);
    track.append(item);
  }
  track.append(botSnap);
  track.append(botPad);

  final highlight = DivElement()..classes.add('picker-wheel-highlight');
  outer.children.addAll([highlight, track]);

  int _scrollToIdx(int idx) => padH + idx * itemH;
  int _idxFromScroll(int sy) => ((sy + visibleH ~/ 2 - padH) / itemH).round().clamp(0, itemCount - 1) as int;

  bool _settling = false;
  Timer? settleTimer;
  Timer? _wheelTimer;

  void _updateSelection(int idx) {
    items.forEach((it) => it.classes.remove('selected'));
    items[idx].classes.add('selected');
  }

  void settle() {
    if (_settling) return;
    _settling = true;
    final idx = _idxFromScroll(track.scrollTop);
    track.scrollTop = _scrollToIdx(idx);
    _updateSelection(idx);
    final v = min + idx * step;
    settleTimer?.cancel();
    settleTimer = Timer(const Duration(milliseconds: 150), () => onChange(v));
    Timer(const Duration(milliseconds: 250), () { _settling = false; });
  }

  track.addEventListener('scrollend', (Event _) => settle());

  final initIdx = (value - min) ~/ step;
  Timer.run(() {
    track.scrollTop = _scrollToIdx(initIdx);
    _updateSelection(initIdx);
  });

  outer.onMouseWheel.listen((e) {
    e.preventDefault();
    track.scrollBy(0, e.deltaY);
    _updateSelection(_idxFromScroll(track.scrollTop));
    _wheelTimer?.cancel();
    _wheelTimer = Timer(const Duration(milliseconds: 200), () { settle(); });
  });

  outer.style.width = '52px';
  outer.style.height = '${visibleH}px';

  return outer;
}
// ボトムシートによる固定スケジュール設定
void showSettingsDialog() {
  final backdrop = DivElement()..classes.addAll(['overlay-backdrop', 'fade-in']);
  final sheet = DivElement()..classes.add('bottom-sheet');

  final header = DivElement()..classes.add('sheet-header');
  header.children.add(HeadingElement.h3()..text = '固定スケジュール設定');
  
  final closeButton = makeCloseButton();
  closeButton.onClick.listen((_) => backdrop.remove());
  header.children.add(closeButton);
  sheet.children.add(header);

  final scrollArea = DivElement()..style.maxHeight = '45vh'..style.overflowY = 'auto';

  for (final schedule in recurringSchedules) {
    final row = DivElement()..classes.addAll(['event-card', 'color-blue', 'settings-row'])..style.marginBottom = '12px';
    final iconRow = DivElement()..classes.add('schedule-icon-row');
    iconRow.append(svgIcon('cog', size: 16));
    iconRow.append(SpanElement()..text = schedule.title);
    row.children.add(iconRow);
    row.children.add(ParagraphElement()..classes.add('schedule-desc')..text = schedule.description);

    final weekdaySelect = SelectElement();
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    for (var i = 1; i <= 7; i++) {
      final option = OptionElement(data: weekdays[i - 1], value: i.toString());
      if (schedule.weekday == i) option.selected = true;
      weekdaySelect.children.add(option);
    }
    weekdaySelect.onChange.listen((_) {
      schedule.weekday = int.tryParse(weekdaySelect.value ?? '1') ?? schedule.weekday;
      dbService.saveAll();
      renderMonthView();
    });

    final hourPicker = createPickerWheel(
      value: schedule.hour, min: 0, max: 23, step: 1,
      onChange: (v) {
        schedule.hour = v;
        dbService.saveAll();
        renderMonthView();
      },
    );
    final minutePicker = createPickerWheel(
      value: schedule.minute, min: 0, max: 59, step: 1,
      onChange: (v) {
        schedule.minute = v;
        dbService.saveAll();
        renderMonthView();
      },
    );

    // --- 【新機能】「アイコンのみ表示」のチェックボックスを追加 ---
    final iconOnlyLabel = LabelElement()..classes.add('checkbox-row');
    final iconOnlyCheckbox = CheckboxInputElement()
      ..classes.add('checkbox-input')
      ..checked = schedule.showIconOnly;
    iconOnlyCheckbox.onChange.listen((_) {
      schedule.showIconOnly = iconOnlyCheckbox.checked ?? false;
      dbService.saveAll();
      renderMonthView();
    });
    iconOnlyLabel.children.addAll([
      iconOnlyCheckbox,
      SpanElement()..text = 'アイコンのみ表示'..classes.add('on-colored')
    ]);
    // -------------------------------------------------------------

    final metaRow = DivElement()..classes.add('form-row')..style.marginTop = '8px';
    metaRow.children.add(DivElement()
      ..classes.add('form-field')
      ..children.addAll([
        ParagraphElement()
          ..text = '曜日'
          ..classes.addAll(['form-field-label', 'on-colored']),
        weekdaySelect,
      ]));
    metaRow.children.add(DivElement()
      ..classes.add('form-field')
      ..children.addAll([
        ParagraphElement()
          ..text = '開始'
          ..classes.addAll(['form-field-label', 'on-colored']),
        hourPicker,
      ]));
    metaRow.children.add(DivElement()
      ..classes.add('form-field')
      ..children.addAll([
        ParagraphElement()
          ..text = '分'
          ..classes.addAll(['form-field-label', 'on-colored']),
        minutePicker,
      ]));

    final weekSelect = SelectElement();
    weekSelect.children.add(OptionElement(data: '毎週', value: '0'));
    for (var i = 1; i <= 4; i++) {
      final option = OptionElement(data: '第${i}週', value: i.toString());
      if (schedule.weekOfMonth == i) option.selected = true;
      weekSelect.children.add(option);
    }
    weekSelect.onChange.listen((_) {
      final value = int.tryParse(weekSelect.value ?? '0');
      schedule.weekOfMonth = value == 0 ? null : value;
      dbService.saveAll();
      renderMonthView();
    });
    metaRow.children.add(DivElement()
      ..classes.add('form-field')
      ..children.addAll([
        ParagraphElement()
          ..text = '週'
          ..classes.addAll(['form-field-label', 'on-colored']),
        weekSelect,
      ]));

    final removeButton = ButtonElement()
      ..text = '削除'
      ..classes.addAll(['save-btn', 'danger', 'compact'])
      ..style.marginTop = '12px';
    removeButton.onClick.listen((_) {
      recurringSchedules.remove(schedule);
      dbService.saveAll();
      renderMonthView();
      backdrop.remove();
      showSettingsDialog();
    });

    metaRow.children.add(DivElement()
      ..classes.add('form-field')
      ..children.add(removeButton));

    row.children.addAll([iconOnlyLabel, metaRow]);
    scrollArea.children.add(row);
  }
  sheet.children.add(scrollArea);

  sheet.children.add(DivElement()..classes.add('section-divider'));

  final titleInput = InputElement()
    ..type = 'text'
    ..placeholder = '予定タイトル'
    ..classes.add('text-input')..style.marginBottom = '12px';
  final descInput = TextAreaElement()
    ..placeholder = '説明'
    ..classes.add('textarea-input')..style.marginBottom = '12px';
  final iconInput = InputElement()
    ..type = 'text'
    ..placeholder = 'アイコン（例: 🗑️）'
    ..classes.add('text-input')..style.marginBottom = '12px';
  
  // 新規固定予定用の「アイコンのみ表示」
  final iconOnlyLabelNew = LabelElement()..classes.add('checkbox-row');
  final iconOnlyCheckboxNew = CheckboxInputElement()..classes.add('checkbox-input');
  iconOnlyLabelNew.children.addAll([
    iconOnlyCheckboxNew,
    SpanElement()..text = 'アイコンのみ表示'
  ]);

  final weekdaySelectNew = SelectElement();
  const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];
  for (var i = 1; i <= 7; i++) {
    weekdaySelectNew.children.add(OptionElement(data: weekdayLabels[i - 1], value: i.toString()));
  }
  int newHour = 8;
  final hourPickerNew = createPickerWheel(
    value: newHour, min: 0, max: 23, step: 1,
    onChange: (v) { newHour = v; },
  );
  int newMinute = 0;
  final minutePickerNew = createPickerWheel(
    value: newMinute, min: 0, max: 59, step: 1,
    onChange: (v) { newMinute = v; },
  );
  final weekOfMonthSelectNew = SelectElement();
  weekOfMonthSelectNew.children.add(OptionElement(data: '毎週', value: '0'));
  for (var i = 1; i <= 4; i++) {
    weekOfMonthSelectNew.children.add(OptionElement(data: '第${i}週', value: i.toString()));
  }
  
  final addButton = ButtonElement()
    ..text = '新規追加'
    ..classes.addAll(['save-btn', 'block']);
  addButton.onClick.listen((_) {
    final title = titleInput.value?.trim() ?? '';
    if (title.isEmpty) {
      window.alert('タイトルを入力してください。');
      return;
    }
    recurringSchedules.add(RecurringSchedule(
      title: title,
      description: descInput.value?.trim() ?? '',
      weekday: int.tryParse(weekdaySelectNew.value ?? '1') ?? 1,
      hour: newHour,
      minute: newMinute,
      weekOfMonth: int.tryParse(weekOfMonthSelectNew.value ?? '0') == 0 ? null : int.tryParse(weekOfMonthSelectNew.value ?? '0'),
      icon: iconInput.value?.trim().isEmpty ?? true ? '' : iconInput.value!.trim(),
      showIconOnly: iconOnlyCheckboxNew.checked ?? false,
    ));
    dbService.saveAll();
    renderMonthView();
    backdrop.remove();
    showSettingsDialog();
  });

  sheet.children.addAll([
    ParagraphElement()..text = '固定スケジュールを追加'..classes.add('form-section-label'),
    titleInput,
    descInput,
    iconInput,
    iconOnlyLabelNew,
    DivElement()
      ..classes.add('form-row')
      ..children.addAll([
        DivElement()..classes.add('form-field')..children.addAll([ParagraphElement()..text = '曜日'..classes.add('form-field-label'), weekdaySelectNew]),
        DivElement()..classes.add('form-field')..children.addAll([ParagraphElement()..text = '時間'..classes.add('form-field-label'), hourPickerNew]),
        DivElement()..classes.add('form-field')..children.addAll([ParagraphElement()..text = '分'..classes.add('form-field-label'), minutePickerNew]),
        DivElement()..classes.add('form-field')..children.addAll([ParagraphElement()..text = '週'..classes.add('form-field-label'), weekOfMonthSelectNew]),
      ]),
    addButton
  ]);

  backdrop.children.add(sheet);
  document.body?.children.add(backdrop);

  refreshLucideIcons();
}

// 絶対配置型タイムラインの実装 (画像2の完全再現)
Element renderDayTimeline(DateTime date, List<ScheduleEvent> fixedEvents, List<ScheduleEvent> manualEvents) {
  final wrapper = DivElement()..classes.add('event-list');
  wrapper.children.add(HeadingElement.h3()..text = 'タイムライン');

  final timelineContainer = DivElement()..classes.add('timeline-container');
  final timelineBg = DivElement()..classes.add('timeline-bg');
  
  // インタラクション用オーバーレイ
  final interactionOverlay = DivElement()..classes.add('timeline-interaction-overlay');
  
  // ドラッグ選択インジケーターとハンドル
  final dragIndicator = DivElement()..classes.add('drag-indicator');
  dragIndicator.children.addAll([
    DivElement()..classes.add('drag-handle-top'),
    DivElement()..classes.add('drag-handle-bottom')
  ]);

  // ドラッグ開始位置を示すマーカー (始点時刻ラベル + 縦線)
  final dragStartMarker = DivElement()..classes.add('drag-start-marker');
  final dragStartLabel = DivElement()..classes.add('drag-start-label')..text = '';
  dragStartMarker.children.add(dragStartLabel);
  
  // 0:00から23:00までのグリッド線を描画 (1時間=40px)
  const hourHeight = 40;
  const startHour = 0;
  const endHour = 23;

  for (int hour = startHour; hour <= endHour; hour++) {
    final topPos = (hour - startHour) * hourHeight;
    
    // グリッド線
    final gridLine = DivElement()
      ..classes.add('timeline-grid-line')
      ..style.top = '${topPos}px';
    timelineBg.children.add(gridLine);
    
    // 時間ラベル (24時間表記)
    final labelStr = '${hour.toString().padLeft(2, '0')}:00';
    
    final hourLabel = DivElement()
      ..classes.add('timeline-hour-label')
      ..style.top = '${topPos}px'
      ..text = labelStr;
    timelineBg.children.add(hourLabel);
  }

  // イベントの絶対配置描画
  final allEvents = [...fixedEvents, ...manualEvents].where((event) => event.date != null).toList();
  
  for (final event in allEvents) {
    final start = event.date!;
    final startMinutes = start.hour * 60 + start.minute;
    final startOffset = startMinutes - (startHour * 60);
    
    if (startMinutes >= startHour * 60 && startMinutes <= endHour * 60) {
      final topPos = startOffset * hourHeight / 60;
      
      double blockHeight;
      if (event.hasTimeRange) {
        final end = event.endDate!;
        final duration = (end.hour * 60 + end.minute) - startMinutes;
        blockHeight = duration * hourHeight / 60;
      } else {
        blockHeight = 35; // 開始時間のみの予定はデフォルト35px
      }
      
      final cardClass = getEventCardClass(event);
      
      final eventBlock = DivElement()
        ..classes.addAll(['timeline-event-block', cardClass])
        ..style.top = '${topPos}px'
        ..style.height = '${blockHeight}px'
        ..style.cursor = 'pointer'; // クリック可能であることを明示
      
      final titleDiv = DivElement()..classes.add('timeline-event-title');
      if (fixedEvents.contains(event)) titleDiv.append(svgIcon('cog', size: 14));
      if (event.icon != null && event.icon!.isNotEmpty) titleDiv.append(SpanElement()..text = '${event.icon} ');
      titleDiv.append(SpanElement()..text = event.title);
      
      String timeDisplay;
      if (event.hasTimeRange) {
        timeDisplay = '${formatTime(startMinutes)}〜${formatTime(event.endDate!.hour * 60 + event.endDate!.minute)}';
      } else {
        timeDisplay = formatTime(startMinutes);
      }
      
      final timeDiv = DivElement()
        ..classes.add('timeline-event-time')
        ..text = '$timeDisplay - ${event.description}';
      
      eventBlock.children.addAll([titleDiv, timeDiv]);

      if (event.note != null && event.note!.isNotEmpty) {
        final noteRow = DivElement()..classes.add('event-note');
        noteRow.append(svgIcon('sticky-note', size: 12));
        noteRow.append(SpanElement()..text = ' ${event.note!}');
        eventBlock.children.add(noteRow);
      }

      // タイムラインブロックをクリックした時も編集ダイアログを開く
      eventBlock.onClick.listen((e) {
        e.stopPropagation();
        // 親のボトムシート詳細を閉じてから開く
        final parentBackdrop = querySelector('.overlay-backdrop');
        parentBackdrop?.remove();
        showEditEventDialog(event);
      });

      timelineBg.children.add(eventBlock);
    }
  }

  // ドラッグ操作による時間帯選択ロジック
  int? dragStartMinutes;
  int? dragEndMinutes;
  bool isDragging = false;

  int getMinutesFromY(int localY) {
    final hourOffset = localY / hourHeight;
    final totalMinutes = (hourOffset * 60).round();
    final snappedMinutes = ((totalMinutes + 7) ~/ 15) * 15;
    return (startHour * 60) + snappedMinutes;
  }

  void updateDragUI(int startMin, int endMin) {
    final minMin = startMin < endMin ? startMin : endMin;
    final maxMin = startMin < endMin ? endMin : startMin;

    final topPos = (minMin - (startHour * 60)) * hourHeight / 60;
    final heightVal = (maxMin - minMin) * hourHeight / 60;

    dragIndicator.style.display = 'block';
    dragIndicator.style.top = '${topPos}px';
    dragIndicator.style.height = '${heightVal > 0 ? heightVal : 10}px';

    // ドラッグ開始位置にマーカー (縦線 + 時刻ラベル) を表示
    final startTopPos = (startMin - (startHour * 60)) * hourHeight / 60;
    dragStartMarker.style.display = 'block';
    dragStartMarker.style.top = '${startTopPos}px';
    dragStartLabel.text = '開始 ${formatTime(startMin)}';
    // 開始位置が上端か下端かでラベルの位置を反転
    final isStartAtTop = startMin <= endMin;
    dragStartLabel.classes.toggle('label-bottom', !isStartAtTop);
  }

  interactionOverlay.onMouseDown.listen((e) {
    e.preventDefault();
    final localY = e.offset.y.toInt();
    dragStartMinutes = getMinutesFromY(localY);
    dragEndMinutes = dragStartMinutes;
    isDragging = true;
    updateDragUI(dragStartMinutes!, dragEndMinutes!);
  });

  interactionOverlay.onMouseMove.listen((e) {
    if (!isDragging || dragStartMinutes == null) return;
    final localY = e.offset.y.toInt();
    dragEndMinutes = getMinutesFromY(localY);
    updateDragUI(dragStartMinutes!, dragEndMinutes!);
  });

  document.onMouseUp.listen((e) {
    if (!isDragging) return;
    isDragging = false;

    if (dragStartMinutes != null && dragEndMinutes != null) {
      final startMin = dragStartMinutes! < dragEndMinutes! ? dragStartMinutes! : dragEndMinutes!;
      var endMin = dragStartMinutes! < dragEndMinutes! ? dragEndMinutes! : dragStartMinutes!;

      if (startMin == endMin) endMin = startMin + 60;

      _showQuickAddDialog(date, startMin, endMin);

      dragStartMinutes = null;
      dragEndMinutes = null;
      dragIndicator.style.display = 'none';
      dragStartMarker.style.display = 'none';
    }
  });

  timelineBg.children.addAll([dragIndicator, dragStartMarker, interactionOverlay]);
  timelineContainer.children.add(timelineBg);
  wrapper.children.add(timelineContainer);
  
  return wrapper;
}

// タイムラインドラッグ時の予定追加（ボトムシート形式 - 画像2の再現）
void _showQuickAddDialog(DateTime date, int startMinutes, int endMinutes) {
  final backdrop = DivElement()..classes.addAll(['overlay-backdrop', 'fade-in']);
  final sheet = DivElement()..classes.add('bottom-sheet');

  final header = DivElement()..classes.add('sheet-header');
  header.children.add(HeadingElement.h3()..text = '${date.month}月${date.day}日 ${formatTime(startMinutes)} 〜 ${formatTime(endMinutes)}');
  
  final closeButton = makeCloseButton();
  closeButton.onClick.listen((_) => backdrop.remove());
  header.children.add(closeButton);
  sheet.children.add(header);

  final titleInput = InputElement()
    ..type = 'text'
    ..placeholder = '予定タイトル'
    ..classes.addAll(['text-input', 'title-input']);
  
  final descInput = TextAreaElement()
    ..placeholder = '詳細を入力'
    ..classes.add('textarea-input')..style.marginTop = '12px';

  // タグ/カテゴリ選択UI
  final tagTitle = ParagraphElement()
    ..text = 'カテゴリ'
    ..classes.add('form-section-label');

  final tagContainer = DivElement()..classes.add('tag-container');
  final tags = ['あなた', 'グループ', '仕事', '大学', 'プライベート'];
  String? selectedTag;

  for (final tag in tags) {
    final tagPill = DivElement()
      ..classes.add('tag-pill')
      ..text = tag;
    tagPill.onClick.listen((_) {
      selectedTag = tag;
      for (final child in tagContainer.children) {
        child.classes.remove('selected');
      }
      tagPill.classes.add('selected');
    });
    tagContainer.children.add(tagPill);
  }
  // デフォルトで「あなた」を選択
  tagContainer.children.first.classes.add('selected');
  selectedTag = tags.first;

  // アイコン選択行
  final iconTitle = ParagraphElement()
    ..text = 'アイコン（任意）'
    ..classes.add('form-section-label');
    
  final iconRow = DivElement()..classes.add('tag-container');
  final icons = ['📝', '🍴', '✈️', '💼', '🎓', '🛒', '🏃', '🏠', '🎬', '📚'];
  String? selectedIcon;

  for (final icon in icons) {
    final iconPill = DivElement()
      ..classes.add('tag-pill')
      ..text = icon;
    iconPill.onClick.listen((_) {
      selectedIcon = icon;
      for (final child in iconRow.children) {
        child.classes.remove('selected');
      }
      iconPill.classes.add('selected');
    });
    iconRow.children.add(iconPill);
  }

  final saveButton = ButtonElement()
    ..text = '保存'
    ..classes.addAll(['save-btn', 'block']);

  saveButton.onClick.listen((_) {
    final title = titleInput.value?.trim() ?? '';
    if (title.isEmpty) {
      window.alert('予定タイトルを入力してください。');
      return;
    }

    final categoryDesc = selectedTag != null ? '[$selectedTag]' : '';
    final finalDescription = descInput.value?.trim() ?? '';
    final fullDescription = categoryDesc.isNotEmpty
      ? (finalDescription.isNotEmpty ? '$categoryDesc $finalDescription' : categoryDesc)
      : finalDescription;

    monthlyEvents.add(ScheduleEvent(
      title: title,
      description: fullDescription,
      date: DateTime(date.year, date.month, date.day, startMinutes ~/ 60, startMinutes % 60),
      endDate: DateTime(date.year, date.month, date.day, endMinutes ~/ 60, endMinutes % 60),
      icon: selectedIcon,
    ));

    dbService.saveAll();
    renderMonthView();
    backdrop.remove();
  });

  sheet.children.addAll([
    titleInput,
    descInput,
    tagTitle,
    tagContainer,
    iconTitle,
    iconRow,
    saveButton
  ]);

  backdrop.onClick.listen((event) {
    if (event.target == backdrop) backdrop.remove();
  });

  backdrop.children.add(sheet);
  document.body?.children.add(backdrop);
}

// タイムライン詳細下部にある静的予定追加フォーム
Element renderAddEventForm(DateTime date) {
  final wrapper = DivElement()..classes.add('event-list')..style.marginTop = '24px';
  wrapper.children.add(HeadingElement.h3()..text = '予定の新規作成');

  final titleInput = InputElement()
    ..type = 'text'
    ..placeholder = '予定タイトル'
    ..classes.add('text-input')..style.marginBottom = '12px';
  final descInput = TextAreaElement()
    ..placeholder = '詳細を入力'
    ..classes.add('textarea-input')..style.marginBottom = '12px';

  final timeRow = DivElement()..classes.add('form-row')..style.marginBottom = '12px';
  final startSelect = SelectElement();
  final endSelect = SelectElement();

  for (int minute = 6 * 60; minute <= 22 * 60; minute += 15) {
    final optionText = formatTime(minute);
    startSelect.children.add(OptionElement(data: optionText, value: minute.toString()));
    if (minute > 6 * 60) {
      endSelect.children.add(OptionElement(data: optionText, value: minute.toString()));
    }
  }
  startSelect.value = '540'; // 9:00 AM
  endSelect.value = '600';   // 10:00 AM

  timeRow.children.add(DivElement()
    ..classes.add('form-field')
    ..children.addAll([
      ParagraphElement()..text = '開始'..classes.add('form-field-label'),
      startSelect,
    ]));
  timeRow.children.add(DivElement()
    ..classes.add('form-field')
    ..children.addAll([
      ParagraphElement()..text = '終了'..classes.add('form-field-label'),
      endSelect,
    ]));

  final tagContainer = DivElement()..classes.add('tag-container');
  final tags = ['あなた', 'グループ', '仕事', '大学', 'プライベート'];
  String? selectedTag = tags.first;

  for (final tag in tags) {
    final tagPill = DivElement()
      ..classes.add('tag-pill')
      ..text = tag;
    if (tag == selectedTag) tagPill.classes.add('selected');
    tagPill.onClick.listen((_) {
      selectedTag = tag;
      for (final child in tagContainer.children) {
        child.classes.remove('selected');
      }
      tagPill.classes.add('selected');
    });
    tagContainer.children.add(tagPill);
  }

  final saveButton = ButtonElement()
    ..text = '追加する'
    ..classes.addAll(['save-btn', 'block']);

  saveButton.onClick.listen((_) {
    final title = titleInput.value?.trim() ?? '';
    final description = descInput.value?.trim() ?? '';
    final startMinute = int.tryParse(startSelect.value ?? '540') ?? 540;
    final endMinute = int.tryParse(endSelect.value ?? '600') ?? 600;

    if (title.isEmpty) {
      window.alert('予定タイトルを入力してください。');
      return;
    }
    if (endMinute <= startMinute) {
      window.alert('終了時刻は開始時刻より後にしてください。');
      return;
    }

    final categoryDesc = selectedTag != null ? '[$selectedTag]' : '';
    final fullDescription = categoryDesc.isNotEmpty
      ? (description.isNotEmpty ? '$categoryDesc $description' : categoryDesc)
      : description;

    monthlyEvents.add(ScheduleEvent(
      title: title,
      description: fullDescription,
      date: DateTime(date.year, date.month, date.day, startMinute ~/ 60, startMinute % 60),
      endDate: DateTime(date.year, date.month, date.day, endMinute ~/ 60, endMinute % 60),
    ));

    dbService.saveAll();
    renderMonthView();
    final backdropEl = querySelector('.overlay-backdrop');
    if (backdropEl != null) backdropEl.remove();

    final fixed = getFixedEventsForMonth(date.year, date.month)
        .where((ev) => ev.date != null && ev.date!.day == date.day).toList();
    final manual = getManualEventsForMonth(date.year, date.month)
        .where((ev) => ev.date != null && ev.date!.day == date.day).toList();
    showDayDetails(date, fixed, manual);
  });

  wrapper.children.addAll([
    titleInput,
    descInput,
    timeRow,
    ParagraphElement()..text = 'カテゴリ'..classes.add('form-section-label'),
    tagContainer,
    saveButton
  ]);
  
  return wrapper;
}

void renderClassWeekView() {
  content.children.clear();
  final card = DivElement()..classes.addAll(['card', 'fade-in', 'timetable-view']);

  final header = DivElement()..classes.add('calendar-header');
  final title = DivElement()..classes.add('calendar-title')
    ..children.add(HeadingElement.h2()..text = '週間授業スケジュール');
  final controls = DivElement()..classes.add('calendar-controls');

  final settingsButton = ButtonElement()
    ..classes.add('settings-button')
    ..title = '設定'
    ..setAttribute('aria-label', '設定');
  settingsButton.append(svgIcon('settings', size: 22));
  settingsButton.onClick.listen((_) => showSettingsDialog());

  final syncButton = ButtonElement()
    ..classes.add('settings-button')
    ..title = '同期・バックアップ'
    ..setAttribute('aria-label', '同期・バックアップ');
  syncButton.append(svgIcon('cloud', size: 22));
  syncButton.onClick.listen((_) => showSyncDialog());

  controls.children.addAll([settingsButton, syncButton]);
  header.children.addAll([title, controls]);
  card.children.add(header);
  card.children.add(renderClassScheduleTable());

  content.children.add(card);

  refreshLucideIcons();
}

Element renderClassScheduleTable() {
  final table = TableElement()..classes.add('week-table');
  final headerRow = TableRowElement();
  headerRow.children.add(TableCellElement()..text = '限数');
  final weekdays = ['月', '火', '水', '木', '金'];
  for (final label in weekdays) {
    headerRow.children.add(TableCellElement()..text = label);
  }
  table.children.add(headerRow);

  for (int period = 1; period <= 5; period++) {
    final row = TableRowElement();
    
    // 時限セルを時間付きでリッチに描画
    final timeCell = TableCellElement()..classes.add('period-header');
    timeCell.children.addAll([
      DivElement()..classes.add('period-num')..text = '$period限',
    ]);
    row.children.add(timeCell);

    for (int weekday = 1; weekday <= 5; weekday++) {
      final cell = TableCellElement();
      final events = classSchedule.where((event) => event.weekday == weekday && event.period == period).toList();
      
      if (events.isEmpty) {
        // 空きコマを+マークのプレースホルダーとして描画
        final emptySlot = DivElement()..classes.add('empty-slot');
        emptySlot.append(svgIcon('plus', size: 18));
        cell.children.add(emptySlot);
        
        cell.onClick.listen((_) {
          showAddClassEventDialog(weekday, period);
        });
      } else {
        for (final event in events) {
          final cardClass = getEventCardClass(event);
          
          final pill = DivElement()
            ..classes.addAll(['schedule-pill', cardClass]);
          
          final titleSpan = SpanElement()
            ..classes.add('pill-title');
          titleSpan.append(SpanElement()..text = event.title);
          if (event.note != null && event.note!.isNotEmpty) {
            titleSpan.append(svgIcon('sticky-note', size: 12));
          }
          
          final descStr = event.description.isNotEmpty ? event.description.replaceAll(RegExp(r'^\d限: '), '') : '';
          
          pill.children.add(titleSpan);
          
          if (descStr.isNotEmpty) {
            pill.children.add(SpanElement()
              ..classes.add('pill-desc')
              ..text = descStr);
          }
          
          if (event.note != null && event.note!.isNotEmpty) {
            pill.children.add(SpanElement()
              ..classes.add('pill-note')
              ..text = event.note!);
          }
          
          final tooltip = '【${event.title}】\n場所/詳細: ${event.description}' + 
              ((event.note != null && event.note!.isNotEmpty) ? '\nメモ: ${event.note!}' : '');
          pill.title = tooltip;

          pill.onClick.listen((e) {
            e.stopPropagation();
            showEditClassEventDialog(event);
          });
          
          cell.children.add(pill);
        }
      }
      row.children.add(cell);
    }
    table.children.add(row);
  }

  return table;
}


// 授業スケジュールの編集・メモ追加ダイアログ
void showEditClassEventDialog(ScheduleEvent event) {
  final backdrop = DivElement()..classes.addAll(['overlay-backdrop', 'fade-in']);
  final sheet = DivElement()..classes.add('bottom-sheet');

  final header = DivElement()..classes.add('sheet-header');
  final weekdayNames = ['', '月曜', '火曜', '水曜', '木曜', '金曜', '土曜', '日曜'];
  final timeSlotStr = '${weekdayNames[event.weekday ?? 1]} ${event.period ?? 1}限';
  header.children.add(HeadingElement.h3()..text = '授業の編集 ($timeSlotStr)');
  
  final closeButton = makeCloseButton();
  closeButton.onClick.listen((_) => backdrop.remove());
  header.children.add(closeButton);
  sheet.children.add(header);

  // 授業名入力
  final titleInput = InputElement()
    ..type = 'text'
    ..placeholder = '授業名（例：英語）'
    ..value = event.title
    ..classes.addAll(['text-input', 'title-input']);

  // 詳細・教室入力
  // '1限: ' という文字が含まれていたらそれを取り除く
  final prefixStr = '${event.period ?? 1}限: ';
  var descVal = event.description;
  if (descVal.startsWith(prefixStr)) {
    descVal = descVal.substring(prefixStr.length);
  }

  final descInput = TextAreaElement()
    ..placeholder = '詳細・教室・教員（例：302教室）'
    ..value = descVal
    ..classes.add('textarea-input')
    ..style.marginTop = '12px';

  // メモ入力 (課題や小テストメモなど)
  final memoTitle = ParagraphElement()
    ..text = '授業のメモ (課題・タスク・試験情報など)'
    ..classes.add('form-section-label');

  final memoInput = TextAreaElement()
    ..placeholder = '例：来週月曜日にレポート提出、教科書p50持参'
    ..value = event.note ?? ''
    ..classes.add('textarea-input')
    ..style.minHeight = '80px';

  // 保存ボタン
  final saveButton = ButtonElement()
    ..text = '保存する'
    ..classes.addAll(['save-btn', 'block']);

  saveButton.onClick.listen((_) {
    final title = titleInput.value?.trim() ?? '';
    if (title.isEmpty) {
      window.alert('授業名を入力してください。');
      return;
    }

    event.title = title;
    final cleanDesc = descInput.value?.trim() ?? '';
    event.description = '${event.period ?? 1}限: $cleanDesc';
    event.note = memoInput.value?.trim();

    dbService.saveAll();
    renderClassWeekView(); // 週間授業画面を再描画
    backdrop.remove();
  });

  // 削除ボタン
  final deleteButton = ButtonElement()
    ..text = '授業を時間割から削除'
    ..classes.addAll(['save-btn', 'danger', 'block'])
    ..style.marginTop = '8px';
  
  deleteButton.onClick.listen((_) {
    if (window.confirm('この授業を時間割から削除しますか？')) {
      classSchedule.remove(event);
      dbService.saveAll();
      renderClassWeekView();
      backdrop.remove();
    }
  });

  sheet.children.addAll([
    titleInput,
    descInput,
    memoTitle,
    memoInput,
    saveButton,
    deleteButton
  ]);

  backdrop.onClick.listen((e) {
    if (e.target == backdrop) backdrop.remove();
  });

  backdrop.children.add(sheet);
  document.body?.children.add(backdrop);
}

// 空きコマに新規に授業を追加するダイアログ
void showAddClassEventDialog(int weekday, int period) {
  final backdrop = DivElement()..classes.addAll(['overlay-backdrop', 'fade-in']);
  final sheet = DivElement()..classes.add('bottom-sheet');

  final header = DivElement()..classes.add('sheet-header');
  final weekdayNames = ['', '月曜', '火曜', '水曜', '木曜', '金曜', '土曜', '日曜'];
  header.children.add(HeadingElement.h3()..text = '新規授業の登録 (${weekdayNames[weekday]} ${period}限)');
  
  final closeButton = makeCloseButton();
  closeButton.onClick.listen((_) => backdrop.remove());
  header.children.add(closeButton);
  sheet.children.add(header);

  // 授業名入力
  final titleInput = InputElement()
    ..type = 'text'
    ..placeholder = '授業名（例：線形代数）'
    ..classes.addAll(['text-input', 'title-input']);

  // 詳細・教室入力
  final descInput = TextAreaElement()
    ..placeholder = '教室や教員（例：101教室）'
    ..classes.add('textarea-input')
    ..style.marginTop = '12px';

  // メモ入力 (任意)
  final memoTitle = ParagraphElement()
    ..text = 'メモ (任意)'
    ..classes.add('form-section-label');

  final memoInput = TextAreaElement()
    ..placeholder = '課題や持ち物などのメモ...'
    ..classes.add('textarea-input')
    ..style.minHeight = '60px';

  // 追加ボタン
  final addButton = ButtonElement()
    ..text = '時間割に追加'
    ..classes.addAll(['save-btn', 'block']);

  addButton.onClick.listen((_) {
    final title = titleInput.value?.trim() ?? '';
    if (title.isEmpty) {
      window.alert('授業名を入力してください。');
      return;
    }

    final newClass = ScheduleEvent(
      title: title,
      description: '${period}限: ' + (descInput.value?.trim() ?? ''),
      weekday: weekday,
      period: period,
      note: memoInput.value?.trim(),
    );

    classSchedule.add(newClass);
    dbService.saveAll();
    renderClassWeekView(); // 再描画
    backdrop.remove();
  });

  sheet.children.addAll([
    titleInput,
    descInput,
    memoTitle,
    memoInput,
    addButton
  ]);

  backdrop.onClick.listen((e) {
    if (e.target == backdrop) backdrop.remove();
  });

  backdrop.children.add(sheet);
  document.body?.children.add(backdrop);
}

// 同期・バックアップダイアログの表示
void showSyncDialog() {
  final backdrop = DivElement()..classes.addAll(['overlay-backdrop', 'fade-in']);
  final sheet = DivElement()..classes.add('bottom-sheet');

  final header = DivElement()..classes.add('sheet-header');
  header.children.add(HeadingElement.h3()..text = 'データ同期・バックアップ');
  
  final closeButton = makeCloseButton();
  closeButton.onClick.listen((_) => backdrop.remove());
  header.children.add(closeButton);
  sheet.children.add(header);

  // クラウド同期セクション
  final cloudSection = DivElement()..classes.add('settings-section');
  cloudSection.children.add(HeadingElement.h4()
    ..classes.add('settings-section-title')
    ..children.addAll([
      svgIcon('cloud', size: 18, extraClasses: ['icon-title']),
      SpanElement()..text = 'クラウド同期',
    ]));
  cloudSection.children.add(ParagraphElement()
    ..classes.add('settings-section-desc')
    ..text = '特定の同期サーバーに接続する場合に設定します。');

  // 同期先URL入力欄
  final urlInput = InputElement()
    ..type = 'text'
    ..placeholder = 'APIエンドポイントURL（例: https://api.example.com/sync）'
    ..value = window.localStorage['sync_api_url'] ?? ''
    ..classes.addAll(['text-input'])
    ..style.marginBottom = '10px';

  // 同期用ボタンのコンテナ
  final cloudBtnRow = DivElement()..classes.add('btn-row');

  final uploadButton = ButtonElement()..classes.add('save-btn');
  uploadButton.append(SpanElement()..text = 'クラウドへ保存 ');
  uploadButton.append(svgIcon('arrow-up', size: 16));

  final downloadButton = ButtonElement()
    ..classes.addAll(['save-btn', 'success']);
  downloadButton.append(SpanElement()..text = 'クラウドから復元 ');
  downloadButton.append(svgIcon('arrow-down', size: 16));

  cloudBtnRow.children.addAll([uploadButton, downloadButton]);

  // イベントリスナーの登録
  uploadButton.onClick.listen((_) async {
    final url = urlInput.value?.trim() ?? '';
    if (url.isEmpty) {
      window.alert('同期先APIのURLを入力してください。');
      return;
    }
    // URLを保存
    window.localStorage['sync_api_url'] = url;

    // アップロード開始
    await uploadToCloud(url);
  });

  downloadButton.onClick.listen((_) async {
    final url = urlInput.value?.trim() ?? '';
    if (url.isEmpty) {
      window.alert('同期先APIのURLを入力してください。');
      return;
    }
    window.localStorage['sync_api_url'] = url;

    if (window.confirm('クラウドのデータで現在のローカルデータを上書きします。よろしいですか？')) {
      await downloadFromCloud(url);
    }
  });

  cloudSection.children.addAll([urlInput, cloudBtnRow]);

  // ファイルバックアップセクション
  final fileSection = DivElement()..classes.add('settings-section');
  fileSection.children.add(HeadingElement.h4()
    ..classes.add('settings-section-title')
    ..children.addAll([
      svgIcon('folder', size: 18, extraClasses: ['icon-title']),
      SpanElement()..text = 'ファイルバックアップ',
    ]));
  fileSection.children.add(ParagraphElement()
    ..classes.add('settings-section-desc')
    ..text = 'スマホ・PC間での手動データ移行用。');

  final fileBtnRow = DivElement()..classes.add('btn-row');

  final exportButton = ButtonElement()
    ..text = 'ファイルへエクスポート'
    ..classes.addAll(['save-btn', 'warning']);

  final importButton = ButtonElement()
    ..text = 'ファイルからインポート'
    ..classes.addAll(['save-btn', 'accent']);

  fileBtnRow.children.addAll([exportButton, importButton]);

  exportButton.onClick.listen((_) => exportToJson());
  importButton.onClick.listen((_) => importFromJson());

  fileSection.children.add(fileBtnRow);

  sheet.children.addAll([
    cloudSection,
    DivElement()..classes.add('section-divider'),
    fileSection
  ]);

  backdrop.onClick.listen((e) {
    if (e.target == backdrop) backdrop.remove();
  });

  backdrop.children.add(sheet);
  document.body?.children.add(backdrop);

  refreshLucideIcons();
}

// クラウドへのデータ送信
Future<void> uploadToCloud(String url) async {
  final payload = {
    'monthly_events': monthlyEvents.map((e) => e.toJson()).toList(),
    'class_schedule': classSchedule.map((e) => e.toJson()).toList(),
    'recurring_schedules': recurringSchedules.map((e) => e.toJson()).toList(),
  };

  try {
    final response = await HttpRequest.request(
      url,
      method: 'POST',
      sendData: jsonEncode(payload),
      requestHeaders: {'Content-Type': 'application/json'},
    );
    if (response.status == 200 || response.status == 201) {
      window.alert('クラウドへ予定データを同期・バックアップしました！');
    } else {
      window.alert('同期に失敗しました（ステータスコード: ${response.status}）');
    }
  } catch (e) {
    window.alert('クラウドに接続できませんでした。\nエラー: $e');
  }
}

// クラウドからのデータ取得
Future<void> downloadFromCloud(String url) async {
  try {
    final response = await HttpRequest.request(
      url,
      method: 'GET',
    );
    if (response.status == 200) {
      final data = jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;
      applyImportData(data);
      window.alert('クラウドからデータを取得して復元しました！');
    } else {
      window.alert('データの取得に失敗しました（ステータスコード: ${response.status}）');
    }
  } catch (e) {
    window.alert('クラウドに接続できませんでした。\nエラー: $e');
  }
}

// JSONデータのエクスポート
void exportToJson() {
  final payload = {
    'monthly_events': monthlyEvents.map((e) => e.toJson()).toList(),
    'class_schedule': classSchedule.map((e) => e.toJson()).toList(),
    'recurring_schedules': recurringSchedules.map((e) => e.toJson()).toList(),
  };
  
  final jsonStr = jsonEncode(payload);
  final blob = Blob([jsonStr], 'application/json');
  final url = Url.createObjectUrlFromBlob(blob);
  
  final anchor = AnchorElement()
    ..href = url
    ..download = 'calendar_backup.json';
  
  anchor.click();
  Url.revokeObjectUrl(url);
}

// JSONデータのインポート
void importFromJson() {
  final input = FileUploadInputElement();
  input.accept = '.json';
  input.onChange.listen((_) {
    if (input.files!.isEmpty) return;
    final file = input.files!.first;
    final reader = FileReader();
    reader.readAsText(file);
    reader.onLoadEnd.listen((_) async {
      try {
        final jsonStr = reader.result as String;
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        applyImportData(data);
        window.alert('バックアップファイルからデータを正常に復元しました！');
      } catch (e) {
        window.alert('ファイルのインポートに失敗しました。\n正しいJSONバックアップファイルかご確認ください。\nエラー: $e');
      }
    });
  });
  input.click();
}

// インポートしたデータを適用して保存・描画するヘルパー
void applyImportData(Map<String, dynamic> data) async {
  if (data.containsKey('monthly_events')) {
    final list = data['monthly_events'] as List;
    monthlyEvents.clear();
    monthlyEvents.addAll(list.map((item) => ScheduleEvent.fromJson(Map<String, dynamic>.from(item as Map))));
  }
  if (data.containsKey('class_schedule')) {
    final list = data['class_schedule'] as List;
    classSchedule.clear();
    classSchedule.addAll(list.map((item) => ScheduleEvent.fromJson(Map<String, dynamic>.from(item as Map))));
  }
  if (data.containsKey('recurring_schedules')) {
    final list = data['recurring_schedules'] as List;
    recurringSchedules.clear();
    recurringSchedules.addAll(list.map((item) => RecurringSchedule.fromJson(Map<String, dynamic>.from(item as Map))));
  }
  
  // IndexedDB に保存
  await dbService.saveAll();
  
  // 画面の更新
  renderCurrentPage();
}
