import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/secure_store.dart';
import '../../data/models/register_result.dart';
import '../../data/models/session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/google_auth_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Giữ phiên đăng nhập của cả app. `AuthGate` lắng nghe để chọn màn hình.
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi api,
    required SessionStore store,
    required GoogleAuth google,
  })  : _api = api,
        _store = store,
        _google = google;

  final AuthApi _api;
  final SessionStore _store;
  final GoogleAuth _google;

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

  Future<void> verifyOtp(String userNameOrEmail, String code) async =>
      _setSession(await _api.verifyOtp(userNameOrEmail.trim(), code.trim()));

  Future<RegisterResult> register(String email, String password, String fullName) =>
      _api.register(email.trim(), password, fullName.trim());

  Future<String> forgotPassword(String email) => _api.forgotPassword(email.trim());

  Future<void> resetPassword(String email, String code, String newPassword) async =>
      _setSession(await _api.resetPassword(email.trim(), code.trim(), newPassword));

  /// Ném [GoogleNotConfigured], [GoogleCancelled], [GoogleSignInFailed] hoặc [ApiException].
  Future<void> signInWithGoogle() async =>
      _setSession(await _api.googleLogin(await _google.getIdToken()));

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
