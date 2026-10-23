/// Đọc thông tin từ payload của JWT (đã decode).
///
/// Backend dùng `new JwtSecurityToken(...)` nên tên claim là URI đầy đủ:
///  - username: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name
///  - role:     http://schemas.microsoft.com/ws/2008/06/identity/claims/role
/// (với nhiều role thì giá trị là mảng). Vẫn hỗ trợ các tên rút gọn
/// ("unique_name", "name", "role", "roles") phòng khi backend đổi cách tạo token.
const roleClaimKeys = [
  'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
  'role',
  'roles',
];

const nameClaimKeys = [
  'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name',
  'unique_name',
  'name',
  'sub',
];

const adminRole = 'Admin';
const userRole = 'User';

/// Trả về "Admin" hoặc "User"; null nếu token không có role hợp lệ.
/// Có cả hai role thì ưu tiên Admin.
String? extractRole(Map<String, dynamic> claims) {
  final roles = <String>[];
  for (final key in roleClaimKeys) {
    final value = claims[key];
    if (value is String) {
      roles.add(value);
    } else if (value is List) {
      roles.addAll(value.whereType<String>());
    }
  }
  bool has(String role) => roles.any((r) => r.toLowerCase() == role.toLowerCase());
  if (has(adminRole)) return adminRole;
  if (has(userRole)) return userRole;
  return null;
}

String? extractUsername(Map<String, dynamic> claims) {
  for (final key in nameClaimKeys) {
    final value = claims[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}
