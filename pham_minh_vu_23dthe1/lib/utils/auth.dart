import '../models/auth_session.dart';
import '../services/auth_service.dart';

/// Lớp tiện ích để giao diện gọi đăng nhập/đăng ký/đăng xuất.
class Auth {
  Auth._();

  static final AuthService _authService = AuthService();

  /// Trả về Map: {success, message, token?, role?, username?, decodedToken?}
  static Future<Map<String, dynamic>> login(String username, String password) {
    return _authService.login(username, password);
  }

  /// Trả về Map: {success, message}
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? initials,
    String? phoneNumber,
    String role = 'User',
  }) {
    return _authService.register(
      username: username,
      email: email,
      password: password,
      initials: initials,
      phoneNumber: phoneNumber,
      role: role,
    );
  }

  static Future<void> logout() => _authService.logout();

  /// Phiên đăng nhập còn hiệu lực (null nếu chưa đăng nhập, token hết hạn hoặc không hợp lệ)
  static Future<AuthSession?> currentSession() => _authService.currentSession();
}
