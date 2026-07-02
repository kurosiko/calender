class ScheduleEvent {
  String title;
  String description;
  DateTime? date;
  DateTime? endDate; // 終了時間
  final int? weekday; // 1 = Monday, 7 = Sunday
  final int? period; // 1..5
  String? icon;
  bool showIconOnly;
  String? note; // 追加: 予定のメモ
  RecurringSchedule? origin; // 追加: 生成元の固定スケジュールへの参照

  ScheduleEvent({
    required this.title,
    required this.description,
    this.date,
    this.endDate,
    this.weekday,
    this.period,
    this.icon,
    this.showIconOnly = false,
    this.note,
    this.origin,
  });

  bool get isClassSchedule => weekday != null && period != null;
  
  // 時間範囲を持っているかどうか
  bool get hasTimeRange => date != null && endDate != null && endDate!.isAfter(date!);

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'date': date?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'weekday': weekday,
    'period': period,
    'icon': icon,
    'showIconOnly': showIconOnly,
    'note': note,
  };

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
    title: json['title'] as String,
    description: json['description'] as String,
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
    weekday: json['weekday'] as int?,
    period: json['period'] as int?,
    icon: json['icon'] as String?,
    showIconOnly: json['showIconOnly'] as bool? ?? false,
    note: json['note'] as String?,
  );
}

class RecurringSchedule {
  String title;
  String description;
  int weekday;
  int hour;
  int minute;
  int? weekOfMonth;
  String icon;
  bool enabled;
  bool showIconOnly; // 追加: アイコンのみ表示フラグ
  String? note; // 追加: 固定スケジュールのメモ

  RecurringSchedule({
    required this.title,
    required this.description,
    required this.weekday,
    this.hour = 8,
    this.minute = 0,
    this.weekOfMonth,
    required this.icon,
    this.enabled = true,
    this.showIconOnly = false,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'weekday': weekday,
    'hour': hour,
    'minute': minute,
    'weekOfMonth': weekOfMonth,
    'icon': icon,
    'enabled': enabled,
    'showIconOnly': showIconOnly,
    'note': note,
  };

  factory RecurringSchedule.fromJson(Map<String, dynamic> json) => RecurringSchedule(
    title: json['title'] as String,
    description: json['description'] as String,
    weekday: json['weekday'] as int,
    hour: json['hour'] as int? ?? 8,
    minute: json['minute'] as int? ?? 0,
    weekOfMonth: json['weekOfMonth'] as int?,
    icon: json['icon'] as String,
    enabled: json['enabled'] as bool? ?? true,
    showIconOnly: json['showIconOnly'] as bool? ?? false,
    note: json['note'] as String?,
  );
}

final DateTime now = DateTime.now();

final List<ScheduleEvent> monthlyEvents = [];

final List<ScheduleEvent> classSchedule = [];

final List<RecurringSchedule> recurringSchedules = [];

List<ScheduleEvent> generateRecurringEvents(int year, int month) {
  final events = <ScheduleEvent>[];
  final daysInMonth = DateTime(year, month + 1, 0).day;

  for (final recurring in recurringSchedules) {
    if (recurring.weekOfMonth != null) {
      final date = _dateForWeekdayInMonth(year, month, recurring.weekday, recurring.weekOfMonth!);
      if (date != null) {
        events.add(ScheduleEvent(
          title: recurring.title,
          description: recurring.description,
          date: DateTime(year, month, date, recurring.hour, recurring.minute),
          icon: recurring.icon,
          showIconOnly: recurring.showIconOnly,
          note: recurring.note,
          origin: recurring,
        ));
      }
      continue;
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final current = DateTime(year, month, day);
      if (current.weekday == recurring.weekday) {
        events.add(ScheduleEvent(
          title: recurring.title,
          description: recurring.description,
          date: DateTime(year, month, day, recurring.hour, recurring.minute),
          icon: recurring.icon,
          showIconOnly: recurring.showIconOnly,
          note: recurring.note,
          origin: recurring,
        ));
      }
    }
  }

  return events;
}

int? _dateForWeekdayInMonth(int year, int month, int weekday, int weekOfMonth) {
  int count = 0;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  for (int day = 1; day <= daysInMonth; day++) {
    final current = DateTime(year, month, day);
    if (current.weekday == weekday) {
      count += 1;
      if (count == weekOfMonth) {
        return day;
      }
    }
  }
  return null;
}
