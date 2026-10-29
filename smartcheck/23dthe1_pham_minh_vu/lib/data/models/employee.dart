import 'session.dart';

class Employee {
  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    this.employeeCode,
    this.departmentId,
    this.departmentName,
    this.isActive = true,
    this.hasFace = false,
    this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final String? employeeCode;
  final int? departmentId;
  final String? departmentName;
  final bool isActive;
  final bool hasFace;

  /// Chỉ có khi lấy chi tiết (`GET /api/employees/{id}`); danh sách không trả role.
  final UserRole? role;

  Employee copyWith({bool? isActive}) => Employee(
        id: id,
        fullName: fullName,
        email: email,
        employeeCode: employeeCode,
        departmentId: departmentId,
        departmentName: departmentName,
        isActive: isActive ?? this.isActive,
        hasFace: hasFace,
        role: role,
      );

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        fullName: (j['fullName'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        employeeCode: j['employeeCode'] as String?,
        departmentId: (j['departmentId'] as num?)?.toInt(),
        departmentName: j['department'] as String?,
        isActive: j['isActive'] != false,
        hasFace: j['hasFace'] == true,
        role: j['role'] == null ? null : UserRole.parse(j['role'] as String?),
      );
}
