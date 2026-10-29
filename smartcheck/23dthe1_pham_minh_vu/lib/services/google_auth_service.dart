import 'package:google_sign_in/google_sign_in.dart';

import '../core/config.dart';

class GoogleNotConfigured implements Exception {}

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

class GoogleAuthService implements GoogleAuth {
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: AppConfig.googleServerClientId);
    _initialized = true;
  }

  @override
  Future<String> getIdToken() async {
    if (AppConfig.googleServerClientId.isEmpty) throw GoogleNotConfigured();
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
