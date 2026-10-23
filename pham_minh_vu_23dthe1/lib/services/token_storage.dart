import 'package:shared_preferences/shared_preferences.dart';

/// Lưu JWT vào máy bằng SharedPreferences để lần sau mở app tự đăng nhập.
class TokenStorage {
  TokenStorage._();

  static const key = 'jwt_token';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, token);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
