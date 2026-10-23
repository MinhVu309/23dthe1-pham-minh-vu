import 'package:jwt_decoder/jwt_decoder.dart';

import '../utils/jwt_claims.dart';

/// Thông tin người dùng đang đăng nhập, lấy từ JWT đã giải mã.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.username,
    required this.role,
    required this.expiresAt,
  });

  final String token;
  final String username;
  final String role; // "Admin" hoặc "User"
  final DateTime expiresAt;

  bool get isAdmin => role == adminRole;

  /// Giải mã token. Trả về null nếu token hỏng, đã hết hạn hoặc không có role hợp lệ.
  static AuthSession? tryParse(String token) {
    try {
      if (JwtDecoder.isExpired(token)) return null;
      final claims = JwtDecoder.decode(token);
      final role = extractRole(claims);
      if (role == null) return null;
      return AuthSession(
        token: token,
        username: extractUsername(claims) ?? '',
        role: role,
        expiresAt: JwtDecoder.getExpirationDate(token),
      );
    } catch (_) {
      return null; // token sai định dạng
    }
  }
}
