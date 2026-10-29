import 'session.dart';

/// Kết quả `GET /api/auth/me`.
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.employeeCode,
    this.departmentId,
    this.hasFace = false,
    this.deviceBound = false,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String? employeeCode;
  final int? departmentId;
  final bool hasFace;
  final bool deviceBound;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: (j['id'] ?? '') as String,
        fullName: (j['fullName'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        role: UserRole.parse(j['role'] as String?),
        employeeCode: j['employeeCode'] as String?,
        departmentId: j['departmentId'] as int?,
        hasFace: j['hasFace'] == true,
        deviceBound: j['deviceBound'] == true,
      );
}
