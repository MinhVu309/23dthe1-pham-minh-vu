import 'attendance.dart';

/// Một dòng của `GET /api/attendance/my`: lượt chấm công của chính mình.
class MyAttendance {
  const MyAttendance({
    required this.id,
    required this.type,
    required this.time,
    required this.isLate,
    required this.isEarlyLeave,
    required this.distance,
    required this.location,
  });

  final int id;
  final AttendanceType type;
  final DateTime time;
  final bool isLate;
  final bool isEarlyLeave;
  final double distance;
  final String location;

  factory MyAttendance.fromJson(Map<String, dynamic> j) => MyAttendance(
        id: (j['id'] as num).toInt(),
        type: AttendanceType.parse(j['type'] as String?),
        // Timestamp của server là UTC; hiển thị theo giờ máy.
        time: DateTime.parse(j['timestamp'] as String).toLocal(),
        isLate: j['isLate'] == true,
        isEarlyLeave: j['isEarlyLeave'] == true,
        distance: (j['distanceMeters'] as num?)?.toDouble() ?? 0,
        location: (j['location'] ?? '') as String,
      );
}

/// Các lượt chấm công trong một ngày: lấy lần vào sớm nhất và lần ra muộn nhất.
class DayLog {
  const DayLog({required this.day, this.checkIn, this.checkOut});

  final DateTime day; // 00:00 giờ máy
  final MyAttendance? checkIn;
  final MyAttendance? checkOut;

  bool get hasIssue => (checkIn?.isLate ?? false) || (checkOut?.isEarlyLeave ?? false);
}

/// Gom danh sách lượt chấm công theo ngày (giờ máy), ngày mới nhất trước.
List<DayLog> groupByDay(Iterable<MyAttendance> items) {
  final byDay = <DateTime, List<MyAttendance>>{};
  for (final a in items) {
    final d = DateTime(a.time.year, a.time.month, a.time.day);
    byDay.putIfAbsent(d, () => []).add(a);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      DayLog(
        day: d,
        checkIn: (byDay[d]!.where((a) => a.type == AttendanceType.checkIn).toList()..sort((a, b) => a.time.compareTo(b.time))).firstOrNull,
        checkOut: (byDay[d]!.where((a) => a.type == AttendanceType.checkOut).toList()..sort((a, b) => b.time.compareTo(a.time))).firstOrNull,
      ),
  ];
}

/// Một dòng bảng công tháng (`GET /api/attendance/report`).
class ReportRow {
  const ReportRow({required this.userId, required this.name, required this.daysWorked, required this.lateCount, required this.earlyLeaveCount});

  final String userId;
  final String name;
  final int daysWorked;
  final int lateCount;
  final int earlyLeaveCount;

  factory ReportRow.fromJson(Map<String, dynamic> j) => ReportRow(
        userId: (j['userId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        daysWorked: (j['daysWorked'] as num?)?.toInt() ?? 0,
        lateCount: (j['lateCount'] as num?)?.toInt() ?? 0,
        earlyLeaveCount: (j['earlyLeaveCount'] as num?)?.toInt() ?? 0,
      );
}

class MonthlyReport {
  const MonthlyReport({required this.year, required this.month, required this.rows});

  final int year;
  final int month;
  final List<ReportRow> rows;

  int get totalDays => rows.fold(0, (s, r) => s + r.daysWorked);
  int get totalLate => rows.fold(0, (s, r) => s + r.lateCount);
  int get totalEarly => rows.fold(0, (s, r) => s + r.earlyLeaveCount);

  factory MonthlyReport.fromJson(Map<String, dynamic> j) => MonthlyReport(
        year: (j['year'] as num).toInt(),
        month: (j['month'] as num).toInt(),
        rows: ((j['rows'] as List?) ?? const []).map((e) => ReportRow.fromJson((e as Map).cast<String, dynamic>())).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );
}
