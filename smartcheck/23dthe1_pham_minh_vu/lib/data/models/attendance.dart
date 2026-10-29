enum AttendanceType {
  checkIn('check-in', 'Vào ca'),
  checkOut('check-out', 'Ra ca');

  const AttendanceType(this.path, this.label);

  /// Đoạn cuối của URL: `/api/attendance/{path}`.
  final String path;
  final String label;

  static AttendanceType parse(String? s) => s == 'CheckOut' ? checkOut : checkIn;
}

/// Dữ liệu gửi lên khi chấm công. Server là nơi quyết định hợp lệ, app chỉ thu thập.
class CheckPayload {
  const CheckPayload({
    required this.qrToken,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMocked,
    required this.deviceId,
    required this.faceVerified,
  });

  final String qrToken;
  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMocked;
  final String deviceId;
  final bool faceVerified;

  Map<String, dynamic> toJson() => {
        'qrToken': qrToken,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'isMocked': isMocked,
        'deviceId': deviceId,
        'faceVerified': faceVerified,
      };
}

/// Kết quả chấm công thành công.
class CheckResult {
  const CheckResult({
    required this.id,
    required this.type,
    required this.time,
    required this.isLate,
    required this.isEarlyLeave,
    required this.distance,
    required this.flags,
  });

  final int id;
  final AttendanceType type;
  final DateTime time;
  final bool isLate;
  final bool isEarlyLeave;
  final double distance;
  final List<String> flags;

  factory CheckResult.fromJson(Map<String, dynamic> j) => CheckResult(
        id: (j['id'] as num).toInt(),
        type: AttendanceType.parse(j['type'] as String?),
        // `timeLocal` mang múi giờ (+07:00); đổi sang giờ của máy để hiển thị.
        time: DateTime.parse(j['timeLocal'] as String).toLocal(),
        isLate: j['isLate'] == true,
        isEarlyLeave: j['isEarlyLeave'] == true,
        distance: (j['distance'] as num?)?.toDouble() ?? 0,
        flags: (j['flags'] as List? ?? const []).map((e) => '$e').toList(),
      );
}
