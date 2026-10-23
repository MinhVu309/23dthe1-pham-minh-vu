// ignore_for_file: camel_case_types
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Nơi DUY NHẤT khai báo đường dẫn tới API.
/// Đọc BASE_URL trong file .env; nếu không có thì dùng địa chỉ mặc định theo nền tảng.
/// BASE_URL luôn kết thúc bằng "/api/" nên endpoint viết không có dấu "/" đầu, VD: "Authenticate/login".
class Config_URL {
  Config_URL._();

  static String get baseUrl {
    final url = dotenv.isInitialized ? dotenv.env['BASE_URL']?.trim() : null;
    if (url == null || url.isEmpty) {
      debugPrint('BASE_URL chưa được khai báo trong .env, dùng địa chỉ mặc định.');
      return _defaultUrl;
    }
    return url.endsWith('/') ? url : '$url/';
  }

  // Android emulator gọi máy host qua 10.0.2.2; các nền tảng khác dùng localhost
  static String get _defaultUrl => defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:5126/api/'
      : 'http://localhost:5126/api/';
}
