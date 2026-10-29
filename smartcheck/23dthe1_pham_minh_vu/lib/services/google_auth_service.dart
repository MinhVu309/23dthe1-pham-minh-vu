import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import '../core/config.dart';

class GoogleNotConfigured implements Exception {
  GoogleNotConfigured([this.message = 'Đăng nhập Google chưa được cấu hình (thiếu Google client ID).']);
  final String message;
}

class GoogleCancelled implements Exception {}

class GoogleSignInFailed implements Exception {
  GoogleSignInFailed(this.detail);
  final String detail;
}

/// Lấy Google ID token để gửi lên `POST /api/auth/google-login`.
abstract interface class GoogleAuth {
  Future<String> getIdToken();
  Future<void> signOut();
}

/// Chặn đăng nhập Google khi thiếu cấu hình. Quan trọng trên iOS: thiếu client ID thì thư viện Google
/// ném NSException gốc (không bắt được bằng try/catch của Dart) và app **sập** ngay khi bấm nút.
/// Trả `null` nếu dùng được, ngược lại là lý do để hiện cho người dùng.
String? googleUnavailableReason({
  required bool isIOS,
  String serverClientId = AppConfig.googleServerClientId,
  String iosClientId = AppConfig.googleIosClientId,
}) {
  if (serverClientId.isEmpty) return 'Đăng nhập Google chưa được cấu hình (thiếu Google client ID).';
  if (isIOS && iosClientId.isEmpty) {
    return 'Đăng nhập Google chưa dùng được trên iPhone (chưa có client ID iOS). Hãy đăng nhập bằng email và mật khẩu.';
  }
  return null;
}

class GoogleAuthService implements GoogleAuth {
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? AppConfig.googleIosClientId : null,
      serverClientId: AppConfig.googleServerClientId,
    );
    _initialized = true;
  }

  @override
  Future<String> getIdToken() async {
    final reason = googleUnavailableReason(isIOS: Platform.isIOS);
    if (reason != null) throw GoogleNotConfigured(reason);
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw GoogleSignInFailed('Không nhận được ID token');
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw GoogleCancelled();
      throw GoogleSignInFailed(e.code.name);
    }
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
