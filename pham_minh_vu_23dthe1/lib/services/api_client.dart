import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/config_url.dart';
import 'token_storage.dart';

/// Gọi các giao thức HTTP (GET/POST/PUT/DELETE) tới backend.
/// Tự gắn `Authorization: Bearer <token>` nếu đã đăng nhập.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  final String? _baseUrl;
  final http.Client _client;

  /// Được gọi khi server trả 401 cho request đã gửi kèm token (token hết hạn/không hợp lệ).
  /// main() gán hàm này để xóa token và đưa người dùng về LoginScreen.
  static Future<void> Function()? onUnauthorized;
  static bool _handlingUnauthorized = false;

  // Đọc lúc gọi (không lưu cứng) để luôn dùng giá trị mới nhất trong .env
  String get baseUrl => _baseUrl ?? Config_URL.baseUrl;

  /// [authenticated] = false cho các request công khai như đăng nhập/đăng ký:
  /// không gắn token và không coi 401 là "hết phiên".
  Future<http.Response> get(String endpoint,
      {Map<String, String>? headers, bool authenticated = true}) {
    return _send((h) => _client.get(_uri(endpoint), headers: h), headers, authenticated);
  }

  Future<http.Response> post(String endpoint,
      {Map<String, String>? headers, dynamic body, bool authenticated = true}) {
    return _send(
      (h) => _client.post(_uri(endpoint), headers: h, body: jsonEncode(body)),
      headers,
      authenticated,
    );
  }

  Future<http.Response> put(String endpoint,
      {Map<String, String>? headers, dynamic body, bool authenticated = true}) {
    return _send(
      (h) => _client.put(_uri(endpoint), headers: h, body: jsonEncode(body)),
      headers,
      authenticated,
    );
  }

  Future<http.Response> delete(String endpoint,
      {Map<String, String>? headers, bool authenticated = true}) {
    return _send((h) => _client.delete(_uri(endpoint), headers: h), headers, authenticated);
  }

  Uri _uri(String endpoint) => Uri.parse('$baseUrl$endpoint');

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
    Map<String, String>? extraHeaders,
    bool authenticated,
  ) async {
    final token = authenticated ? await TokenStorage.read() : null;
    final response = await request({
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extraHeaders,
    });

    if (response.statusCode == 401 && token != null) await _handleUnauthorized();
    return response;
  }

  Future<void> _handleUnauthorized() async {
    if (_handlingUnauthorized) return; // nhiều request cùng 401 thì chỉ xử lý một lần
    _handlingUnauthorized = true;
    try {
      await TokenStorage.clear();
      await onUnauthorized?.call();
    } finally {
      _handlingUnauthorized = false;
    }
  }
}
