import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../models/auth_session.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// Gọi API Authenticate (đăng nhập/đăng ký) và quản lý token đã lưu.
/// Mọi hàm trả về Map có `success` (bool) và `message` (String) để giao diện dùng thống nhất.
class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static const _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client
          .post('Authenticate/login',
              body: {'username': username, 'password': password}, authenticated: false)
          .timeout(_timeout);
      final data = _decode(response);

      // Server trả { status: bool, message, token }
      if (response.statusCode != 200 || data['status'] != true) {
        return _fail(data['message'] ?? 'Đăng nhập thất bại (${response.statusCode})');
      }

      final token = data['token'];
      if (token is! String || token.isEmpty) {
        return _fail('Server không trả về token');
      }

      // Giải mã token để biết người dùng và vai trò
      final session = AuthSession.tryParse(token);
      if (session == null) {
        // Role lạ/không có (hoặc token hỏng): không lưu token, không cho vào
        return _fail('Tài khoản không có quyền hợp lệ (Admin/User)');
      }

      await TokenStorage.save(token);
      return {
        'success': true,
        'message': data['message'] ?? 'Đăng nhập thành công',
        'token': token,
        'decodedToken': JwtDecoder.decode(token),
        'role': session.role,
        'username': session.username,
      };
    } catch (e) {
      return _fail(_networkMessage(e));
    }
  }

  /// Chuẩn hóa kết quả: server trả `status`, giao diện kiểm tra `success`.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? initials,
    String? phoneNumber,
    String? role,
  }) async {
    try {
      final response = await _client
          .post(
            'Authenticate/register',
            body: {
              'username': username,
              'email': email,
              'password': password,
              if (initials != null && initials.isNotEmpty) 'initials': initials,
              if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
              if (role != null && role.isNotEmpty) 'role': role,
            },
            authenticated: false,
          )
          .timeout(_timeout);
      final data = _decode(response);

      final ok = response.statusCode == 200 && data['status'] == true;
      if (ok) return {'success': true, 'message': data['message'] ?? 'Đăng ký thành công'};
      return _fail(data['message'] ?? 'Đăng ký thất bại (${response.statusCode})');
    } catch (e) {
      return _fail(_networkMessage(e));
    }
  }

  /// Xóa token đã lưu.
  Future<void> logout() => TokenStorage.clear();

  /// Phiên đăng nhập hiện tại. Token không có/hết hạn/hỏng/role lạ thì xóa token và trả về null.
  Future<AuthSession?> currentSession() async {
    final token = await TokenStorage.read();
    if (token == null) return null;
    final session = AuthSession.tryParse(token);
    if (session == null) await TokenStorage.clear();
    return session;
  }

  Map<String, dynamic> _fail(Object message) => {'success': false, 'message': message.toString()};

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return {};
  }

  String _networkMessage(Object e) {
    if (e is TimeoutException) return 'Hết thời gian chờ, kiểm tra backend đã chạy chưa';
    if (e is SocketException || e is http.ClientException) {
      return 'Không kết nối được tới máy chủ';
    }
    return 'Có lỗi xảy ra: $e';
  }
}
