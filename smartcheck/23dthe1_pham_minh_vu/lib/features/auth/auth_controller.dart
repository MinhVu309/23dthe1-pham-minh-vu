import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/secure_store.dart';
import '../../data/models/register_result.dart';
import '../../data/models/session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/biometric_service.dart';
import '../../services/device_id.dart';
import '../../services/google_auth_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Nút "Đăng nhập bằng vân tay/khuôn mặt" ở màn đăng nhập: bật cho ai, gọi là gì.
class BiometricOption {
  const BiometricOption({required this.label, required this.fullName, required this.email});
  final String label;
  final String fullName;
  final String email;
}

/// Giữ phiên đăng nhập của cả app. `AuthGate` lắng nghe để chọn màn hình.
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi api,
    required SessionStore store,
    required GoogleAuth google,
    BiometricVault? biometric,
    DeviceIdProvider? deviceId,
  })  : _api = api,
        _store = store,
        _google = google,
        _bio = biometric,
        _deviceId = deviceId;

  final AuthApi _api;
  final SessionStore _store;
  final GoogleAuth _google;
  final BiometricVault? _bio;
  final DeviceIdProvider? _deviceId;

  /// Vừa đăng nhập bằng mật khẩu + OTP: có thể mời bật đăng nhập sinh trắc (xem [takeBiometricOffer]).
  bool _offerPending = false;

  AuthStatus _status = AuthStatus.unknown;
  Session? _session;
  String? _notice;

  AuthStatus get status => _status;
  Session? get session => _session;
  String? get token => _session?.token;

  /// Thông báo hiện ở màn đăng nhập (ví dụ phiên hết hạn). Đọc xong thì xoá.
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  /// Gọi lúc mở app: nạp phiên đã lưu rồi hỏi server xem token còn dùng được không.
  Future<void> restore() async {
    final saved = await _store.read();
    if (saved == null) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    _session = saved;
    _status = AuthStatus.signedIn;
    notifyListeners();
    try {
      await _api.me(); // 401 sẽ kích hoạt handleUnauthorized qua ApiClient
    } on ApiException {
      // Mất mạng/lỗi tạm: vẫn giữ phiên, 401 sau đó sẽ tự đưa về đăng nhập.
    }
  }

  Future<bool> login(String userNameOrEmail, String password) =>
      _api.login(userNameOrEmail.trim(), password);

  Future<void> resendOtp(String userNameOrEmail) => _api.resendOtp(userNameOrEmail.trim());

  Future<void> verifyOtp(String userNameOrEmail, String code) async {
    final s = await _api.verifyOtp(userNameOrEmail.trim(), code.trim());
    _offerPending = true;
    await _setSession(s);
  }

  Future<RegisterResult> register(String email, String password, String fullName) =>
      _api.register(email.trim(), password, fullName.trim());

  Future<String> forgotPassword(String email) => _api.forgotPassword(email.trim());

  Future<void> resetPassword(String email, String code, String newPassword) async {
    final s = await _api.resetPassword(email.trim(), code.trim(), newPassword);
    // Server đã thu hồi mọi token sinh trắc của tài khoản này khi đổi mật khẩu.
    if ((await _bio?.hint())?.userId == s.userId) await _bio?.clear();
    await _setSession(s);
  }

  /// Ném [GoogleNotConfigured], [GoogleCancelled], [GoogleSignInFailed] hoặc [ApiException].
  Future<void> signInWithGoogle() async =>
      _setSession(await _api.googleLogin(await _google.getIdToken()));

  // ---------- Đăng nhập sinh trắc học ----------

  /// Màn đăng nhập hỏi: máy này đã bật vân tay/khuôn mặt cho ai? Null thì không hiện nút.
  Future<BiometricOption?> biometricOption() async {
    final bio = _bio;
    if (bio == null) return null;
    final hint = await bio.hint();
    if (hint == null) return null;
    final support = await bio.support();
    if (!support.available) return null;
    return BiometricOption(label: support.label, fullName: hint.fullName, email: hint.email);
  }

  /// Quét vân tay/khuôn mặt rồi đổi token đã cất lấy phiên mới.
  /// Ném [BiometricCancelled] (người dùng đóng hộp thoại, không phải lỗi), [BiometricFailed] hoặc [ApiException].
  /// Token hết hạn/bị thu hồi hoặc máy không còn sinh trắc học thì xoá thông tin đã cất để quay về mật khẩu + OTP.
  Future<void> loginWithBiometric() async {
    final bio = _bio;
    final device = _deviceId;
    if (bio == null || device == null) throw const BiometricFailed('not configured');
    final String? token;
    try {
      token = await bio.readToken();
    } on BiometricFailed catch (e) {
      if (e.permanent) await bio.clear();
      rethrow;
    }
    if (token == null) {
      await bio.clear();
      throw const BiometricFailed('missing token');
    }
    try {
      await _setSession(await _api.biometricLogin(await device.get(), token));
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) await bio.clear();
      rethrow;
    }
  }

  /// Sau đăng nhập mật khẩu + OTP: trả tên gọi ("vân tay", "khuôn mặt"…) nếu nên mời người dùng bật; ngược lại null.
  /// Chỉ trả giá trị một lần cho mỗi lần đăng nhập.
  Future<String?> takeBiometricOffer() async {
    final bio = _bio;
    final s = _session;
    if (!_offerPending) return null;
    _offerPending = false;
    if (bio == null || s == null) return null;
    final support = await bio.support();
    if (!support.available) return null;
    if ((await bio.hint())?.userId == s.userId) return null; // đã bật sẵn cho tài khoản này
    if (await bio.isDeclined(s.userId)) return null;
    return support.label;
  }

  Future<void> declineBiometricOffer() async {
    final s = _session;
    if (s != null) await _bio?.decline(s.userId);
  }

  /// Bật cho tài khoản đang đăng nhập trên máy này. Ném [BiometricCancelled], [BiometricFailed] hoặc [ApiException].
  Future<void> enableBiometric() async {
    final bio = _bio;
    final device = _deviceId;
    final s = _session;
    if (bio == null || device == null || s == null) throw const BiometricFailed('not configured');
    final deviceId = await device.get();
    final granted = await _api.biometricEnroll(deviceId);
    try {
      await bio.save(
        BiometricHint(userId: s.userId, email: s.email, fullName: s.fullName, expiresAt: granted.expiresAt),
        granted.token,
      );
    } catch (_) {
      // Người dùng không xác nhận được: thu hồi token vừa cấp để khỏi tồn đọng ở server.
      try {
        await _api.biometricRevoke(deviceId);
      } on ApiException {
        // token chưa ai giữ nên để tự hết hạn cũng được
      }
      rethrow;
    }
  }

  /// Tắt đăng nhập sinh trắc trên máy này (cả ở server, nếu còn mạng và còn phiên).
  Future<void> disableBiometric() async {
    final device = _deviceId;
    if (_session != null && device != null) {
      try {
        await _api.biometricRevoke(await device.get());
      } on ApiException {
        // vẫn xoá phía máy; token ở server sẽ tự hết hạn
      }
    }
    await _bio?.clear();
  }

  /// Máy này đã bật đăng nhập sinh trắc cho tài khoản đang đăng nhập chưa.
  Future<bool> isBiometricEnabled() async {
    final s = _session;
    return s != null && (await _bio?.hint())?.userId == s.userId;
  }

  Future<void> _setSession(Session s) async {
    await _store.write(s);
    _session = s;
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> logout() => _signOut(null);

  /// ApiClient báo server trả 401 cho request có JWT.
  void handleUnauthorized() {
    if (_status != AuthStatus.signedIn) return;
    _signOut('Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.');
  }

  Future<void> _signOut(String? notice) async {
    _notice = notice;
    _session = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
    await _store.clear();
    await _google.signOut();
  }
}
