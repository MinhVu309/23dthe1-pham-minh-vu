import 'attendance.dart';

/// Một dòng chấm công trong `GET /api/attendance` (Admin/Manager), có toạ độ để vẽ lên bản đồ.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.isLate,
    required this.isEarlyLeave,
    required this.location,
  });

  final int id;
  final String userId;
  final String userName;
  final AttendanceType type;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double distance;
  final bool isLate;
  final bool isEarlyLeave;
  final String location;

  bool get isOnTime => type == AttendanceType.checkIn ? !isLate : !isEarlyLeave;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: (j['id'] as num).toInt(),
        userId: (j['userId'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        type: AttendanceType.parse(j['type'] as String?),
        time: DateTime.parse(j['timestamp'] as String).toLocal(),
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        distance: (j['distanceMeters'] as num?)?.toDouble() ?? 0,
        isLate: j['isLate'] == true,
        isEarlyLeave: j['isEarlyLeave'] == true,
        location: (j['location'] ?? '') as String,
      );
}

/// `{total, items}`; `total` có thể lớn hơn số dòng trả về vì server giới hạn mỗi trang.
class AttendanceList {
  const AttendanceList({required this.total, required this.items});
  final int total;
  final List<AttendanceRecord> items;
}
