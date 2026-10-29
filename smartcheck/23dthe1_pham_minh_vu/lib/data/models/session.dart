enum UserRole {
  admin('Admin', 'Quản trị viên'),
  manager('Manager', 'Quản lý'),
  employee('Employee', 'Nhân viên');

  const UserRole(this.apiName, this.label);
  final String apiName;
  final String label;

  /// Role lạ/thiếu thì rơi về quyền thấp nhất (Employee).
  static UserRole parse(String? v) {
    for (final r in UserRole.values) {
      if (r.apiName.toLowerCase() == v?.toLowerCase()) return r;
    }
    return UserRole.employee;
  }
}

/// Kết quả đăng nhập `{token, role, userId, fullName, email}`.
class Session {
  const Session({
    required this.token,
    required this.role,
    required this.userId,
    required this.fullName,
    required this.email,
  });

  final String token;
  final UserRole role;
  final String userId;
  final String fullName;
  final String email;

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        token: j['token'] as String,
        role: UserRole.parse(j['role'] as String?),
        userId: (j['userId'] ?? '') as String,
        fullName: (j['fullName'] ?? '') as String,
        email: (j['email'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'role': role.apiName,
        'userId': userId,
        'fullName': fullName,
        'email': email,
      };
}
