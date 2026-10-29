import 'package:pham_minh_vu_23dthe1/core/api_client.dart';
import 'package:pham_minh_vu_23dthe1/core/secure_store.dart';
import 'package:pham_minh_vu_23dthe1/data/models/profile.dart';
import 'package:pham_minh_vu_23dthe1/data/models/register_result.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/auth_repository.dart';
import 'package:pham_minh_vu_23dthe1/services/google_auth_service.dart';

Session sessionFor(UserRole role) => Session(
      token: 'jwt-${role.apiName}',
      role: role,
      userId: 'u-${role.apiName}',
      fullName: 'Nguyễn Văn ${role.apiName}',
      email: '${role.apiName.toLowerCase()}@test.local',
    );

class MemoryStore implements SessionStore {
  MemoryStore([this.saved]);
  Session? saved;
  @override
  Future<Session?> read() async => saved;
  @override
  Future<void> write(Session session) async => saved = session;
  @override
  Future<void> clear() async => saved = null;
}

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.role = UserRole.employee});

  UserRole role;
  ApiException? meError;
  ApiException? loginError;
  ApiException? verifyError;
  int meCalls = 0;
  int resendCalls = 0;
  int registerCalls = 0;
  String? lastCode;
  String? lastVerifyIdentifier;
  String? lastRegisterEmail;
  ApiException? registerError;

  int forgotCalls = 0;
  int resetCalls = 0;
  String? lastForgotEmail;
  String? lastResetCode;
  String? lastResetPassword;
  ApiException? forgotError;
  ApiException? resetError;

  /// `false` mô phỏng server cũ chưa có bước xác minh email khi đăng ký.
  bool requiresVerification = true;

  @override
  Future<bool> login(String userNameOrEmail, String password) async {
    if (loginError != null) throw loginError!;
    return true;
  }

  @override
  Future<Session> verifyOtp(String userNameOrEmail, String code) async {
    lastCode = code;
    lastVerifyIdentifier = userNameOrEmail;
    if (verifyError != null) throw verifyError!;
    return sessionFor(role);
  }

  @override
  Future<void> resendOtp(String userNameOrEmail) async => resendCalls++;

  @override
  Future<RegisterResult> register(String email, String password, String fullName) async {
    registerCalls++;
    lastRegisterEmail = email;
    if (registerError != null) throw registerError!;
    return requiresVerification
        ? const RegisterResult(message: 'Đã gửi mã xác minh tới email.', requiresEmailVerification: true)
        : const RegisterResult(message: 'Đăng ký thành công, hãy đăng nhập.');
  }

  @override
  Future<Session> googleLogin(String idToken) async => sessionFor(role);

  @override
  Future<String> forgotPassword(String email) async {
    forgotCalls++;
    lastForgotEmail = email;
    if (forgotError != null) throw forgotError!;
    return 'Nếu email có tài khoản, mã đặt lại mật khẩu đã được gửi. Mã có hiệu lực 5 phút.';
  }

  @override
  Future<Session> resetPassword(String email, String code, String newPassword) async {
    resetCalls++;
    lastResetCode = code;
    lastResetPassword = newPassword;
    if (resetError != null) throw resetError!;
    return sessionFor(role);
  }

  @override
  Future<Profile> me() async {
    meCalls++;
    if (meError != null) throw meError!;
    return Profile(id: 'u', fullName: 'Tên thử', email: 'x@test.local', role: role, employeeCode: 'NV001');
  }
}

class FakeGoogle implements GoogleAuth {
  Object? error;
  bool signedOut = false;
  @override
  Future<String> getIdToken() async => error != null ? throw error! : 'google-id-token';
  @override
  Future<void> signOut() async => signedOut = true;
}
