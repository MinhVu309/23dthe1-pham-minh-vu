enum LeaveStatus {
  pending('Pending', 'Chờ duyệt'),
  approved('Approved', 'Đã duyệt'),
  rejected('Rejected', 'Từ chối');

  const LeaveStatus(this.apiName, this.label);
  final String apiName;
  final String label;

  static LeaveStatus parse(String? v) =>
      LeaveStatus.values.firstWhere((s) => s.apiName == v, orElse: () => LeaveStatus.pending);
}

class Leave {
  const Leave({
    required this.id,
    required this.userId,
    required this.userName,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
  });

  final int id;
  final String userId;
  final String userName;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final LeaveStatus status;

  /// Server dùng ngày `yyyy-MM-dd`.
  static String formatApiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory Leave.fromJson(Map<String, dynamic> j) => Leave(
        id: (j['id'] as num).toInt(),
        userId: (j['userId'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        fromDate: DateTime.parse(j['fromDate'] as String),
        toDate: DateTime.parse(j['toDate'] as String),
        reason: (j['reason'] ?? '') as String,
        status: LeaveStatus.parse(j['status'] as String?),
      );
}
