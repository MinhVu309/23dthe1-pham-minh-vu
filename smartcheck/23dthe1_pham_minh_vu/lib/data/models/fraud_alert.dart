class FraudAlert {
  const FraudAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.reason,
    this.detail,
    required this.createdAt,
    required this.resolved,
  });

  final int id;
  final String userId;
  final String userName;
  final String reason;

  /// Chuỗi thô do server ghi, ví dụ `lat=10.8, lng=106.7, acc=12, device=...`.
  final String? detail;
  final DateTime createdAt;
  final bool resolved;

  factory FraudAlert.fromJson(Map<String, dynamic> j) => FraudAlert(
        id: (j['id'] as num).toInt(),
        userId: (j['userId'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
        detail: j['detail'] as String?,
        // Timestamp của server là UTC; hiển thị theo giờ máy.
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        resolved: j['resolved'] == true,
      );
}
