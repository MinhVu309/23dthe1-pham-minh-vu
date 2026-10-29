import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Định danh máy gửi kèm mỗi lần chấm công; server gắn tài khoản với máy ở lần đầu.
abstract interface class DeviceIdProvider {
  Future<String> get();
}

/// Android không cho ứng dụng đọc ANDROID_ID cố định, nên sinh một mã ngẫu nhiên lưu trong
/// Keystore (sống đến khi gỡ app) và ghép thêm tên máy từ `device_info_plus` cho dễ đọc.
class StoredDeviceId implements DeviceIdProvider {
  StoredDeviceId([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'smartcheck.device';
  final FlutterSecureStorage _storage;
  String? _cached;

  @override
  Future<String> get() async {
    if (_cached != null) return _cached!;
    var id = await _storage.read(key: _key);
    if (id == null) {
      id = '${await _model()}-${_randomHex(16)}';
      await _storage.write(key: _key, value: id);
    }
    return _cached = id;
  }

  Future<String> _model() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return '${info.manufacturer}-${info.model}'.replaceAll(RegExp(r'\s+'), '_');
    } catch (_) {
      return 'android';
    }
  }

  static String _randomHex(int bytes) {
    final r = Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
