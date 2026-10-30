import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Máy có dùng được vân tay/khuôn mặt cho app hay không (đã đăng ký ít nhất một sinh trắc học mạnh).
class BiometricSupport {
  const BiometricSupport.available(this.label)
      : available = true,
        reason = null;
  const BiometricSupport.unavailable(this.reason)
      : available = false,
        label = 'sinh trắc học';

  final bool available;

  /// Cách gọi trong giao diện: "vân tay", "khuôn mặt", "vân tay hoặc khuôn mặt"…
  final String label;
  final String? reason;
}

/// Phần KHÔNG bí mật của đăng nhập sinh trắc học: dùng để biết máy này đã bật cho ai mà không phải quét vân tay.
class BiometricHint {
  const BiometricHint({required this.userId, required this.email, required this.fullName, required this.expiresAt});

  final String userId;
  final String email;
  final String fullName;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'fullName': fullName,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  factory BiometricHint.fromJson(Map<String, dynamic> j) => BiometricHint(
        userId: j['userId'] as String,
        email: (j['email'] ?? '') as String,
        fullName: (j['fullName'] ?? '') as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String).toUtc(),
      );
}

/// Người dùng đóng hộp thoại vân tay/khuôn mặt.
class BiometricCancelled implements Exception {
  const BiometricCancelled();
}

/// Quét sinh trắc thất bại không phải do người dùng huỷ.
/// [permanent]: máy không còn dùng được sinh trắc học (xoá hết vân tay/khuôn mặt…), nên bỏ thông tin đã cất;
/// ngược lại (khoá tạm vì quét sai nhiều lần, lỗi phần cứng) thì thử lại sau được.
class BiometricFailed implements Exception {
  const BiometricFailed(this.detail, {this.permanent = false});
  final String detail;
  final bool permanent;

  @override
  String toString() => 'BiometricFailed($detail, permanent: $permanent)';
}

/// Két giữ token đăng nhập sinh trắc: token nằm trong Keystore/Keychain (flutter_secure_storage) và chỉ được đọc ra
/// sau khi vân tay/khuôn mặt của máy khớp (local_auth, chỉ nhận sinh trắc học, không nhận mã PIN).
abstract interface class BiometricVault {
  Future<BiometricSupport> support();

  /// Máy này đã bật cho tài khoản nào (null nếu chưa bật hoặc đã hết hạn). Không hiện hộp thoại quét.
  Future<BiometricHint?> hint();

  /// Cất token. Hiện hộp thoại quét, nên cũng là bước xác nhận của người dùng.
  /// Ném [BiometricCancelled] hoặc [BiometricFailed].
  Future<void> save(BiometricHint hint, String token);

  /// Hiện hộp thoại quét rồi trả token. Ném [BiometricCancelled] hoặc [BiometricFailed].
  Future<String?> readToken();

  Future<void> clear();

  /// Người dùng đã bấm "Để sau" ở lời mời bật; không mời lại ở các lần đăng nhập sau.
  Future<bool> isDeclined(String userId);
  Future<void> decline(String userId);
}

class DeviceBiometricVault implements BiometricVault {
  DeviceBiometricVault({FlutterSecureStorage? storage, LocalAuthentication? auth, DateTime Function()? now})
      : _storage = storage ?? const FlutterSecureStorage(),
        _auth = auth ?? LocalAuthentication(),
        _now = now ?? DateTime.now;

  static const _hintKey = 'smartcheck.biometric.hint';
  static const _tokenKey = 'smartcheck.biometric.token';
  static const _declinedKey = 'smartcheck.biometric.declined';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;
  final DateTime Function() _now;

  @override
  Future<BiometricSupport> support() async {
    try {
      if (!await _auth.isDeviceSupported()) {
        return const BiometricSupport.unavailable('Thiết bị này không hỗ trợ vân tay hay khuôn mặt.');
      }
      if (!await _auth.canCheckBiometrics) {
        return const BiometricSupport.unavailable('Thiết bị này không có cảm biến vân tay hay khuôn mặt.');
      }
      final types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) {
        return const BiometricSupport.unavailable('Hãy thêm vân tay hoặc khuôn mặt trong Cài đặt của điện thoại trước.');
      }
      final face = types.contains(BiometricType.face);
      final finger = types.contains(BiometricType.fingerprint);
      return BiometricSupport.available(face && finger
          ? 'vân tay hoặc khuôn mặt'
          : face
              ? 'khuôn mặt'
              : finger
                  ? 'vân tay'
                  : 'vân tay/khuôn mặt'); // Android mới chỉ báo "strong"/"weak", không nói rõ loại
    } catch (e) {
      return const BiometricSupport.unavailable('Không kiểm tra được sinh trắc học của thiết bị.');
    }
  }

  @override
  Future<BiometricHint?> hint() async {
    try {
      final raw = await _storage.read(key: _hintKey);
      if (raw == null) return null;
      final hint = BiometricHint.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (hint.isExpired(_now())) {
        await clear();
        return null;
      }
      return hint;
    } catch (_) {
      await clear();
      return null;
    }
  }

  /// Hiện hộp thoại vân tay/khuôn mặt; trả khi khớp, còn lại ném [BiometricCancelled] hoặc [BiometricFailed].
  Future<void> _scan(String reason) async {
    final bool ok;
    try {
      ok = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(signInTitle: 'SmartCheck', cancelButton: 'Huỷ'),
          IOSAuthMessages(cancelButton: 'Huỷ'),
        ],
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      throw switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          const BiometricCancelled(),
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noCredentialsSet =>
          BiometricFailed(e.description ?? e.code.name, permanent: true),
        _ => BiometricFailed(e.description ?? e.code.name),
      };
    } catch (e) {
      throw BiometricFailed('$e');
    }
    if (!ok) throw const BiometricCancelled();
  }

  @override
  Future<void> save(BiometricHint hint, String token) async {
    await _scan('Xác nhận để bật đăng nhập bằng sinh trắc học');
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _hintKey, value: jsonEncode(hint.toJson()));
  }

  @override
  Future<String?> readToken() async {
    await _scan('Xác thực để đăng nhập SmartCheck');
    return _storage.read(key: _tokenKey);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _hintKey);
    await _storage.delete(key: _tokenKey);
  }

  @override
  Future<bool> isDeclined(String userId) async {
    final raw = await _storage.read(key: _declinedKey);
    return raw != null && (jsonDecode(raw) as List).contains(userId);
  }

  @override
  Future<void> decline(String userId) async {
    final raw = await _storage.read(key: _declinedKey);
    final ids = <String>{...raw == null ? const <String>[] : (jsonDecode(raw) as List).cast<String>(), userId};
    await _storage.write(key: _declinedKey, value: jsonEncode(ids.toList()));
  }
}
