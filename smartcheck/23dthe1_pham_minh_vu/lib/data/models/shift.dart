import 'package:flutter/material.dart';

class Shift {
  const Shift({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.lateToleranceMinutes,
  });

  final int id;
  final String name;
  final TimeOfDay start;
  final TimeOfDay end;
  final int lateToleranceMinutes;

  /// Server trả `"08:00:00"` (TimeSpan).
  static TimeOfDay parseTime(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  static String formatApi(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  static String formatShort(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get range => '${formatShort(start)} – ${formatShort(end)}';

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        start: parseTime(j['startTime'] as String),
        end: parseTime(j['endTime'] as String),
        lateToleranceMinutes: (j['lateToleranceMinutes'] as num).toInt(),
      );
}
