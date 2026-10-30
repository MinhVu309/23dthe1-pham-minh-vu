import '../../core/api_client.dart';
import '../models/profile.dart';
import '../models/register_result.dart';
import '../models/session.dart';

/// Các lời gọi API xác thực. Controller phụ thuộc interface này để dễ test.
abstract interface class AuthApi {
  /// Bước 1. Trả `true` nếu server đã gửi OTP.
  Future<bool> login(String userNameOrEmail, String password);
  Future<Session> verifyOtp(String userNameOrEmail, String code);
  Future<void> resendOtp(String userNameOrEmail);
  Future<RegisterResult> register(String email, String password, String fullName);
  Future<Session> googleLogin(String idToken);

  /// Quên mật khẩu, bước 1: server gửi mã 6 số tới email (luôn trả thông báo chung, không lộ email có tài khoản hay không).
  Future<String> forgotPassword(String email);

  /// Quên mật khẩu, bước 2: đúng mã thì đổi mật khẩu và đăng nhập luôn.
  Future<Session> resetPassword(String email, String code, String newPassword);
  Future<Profile> me();

  /// Đã đăng nhập: xin token đăng nhập sinh trắc gắn với thiết bị này. Trả `(token, hạn dùng)`.
  Future<({String token, DateTime expiresAt})> biometricEnroll(String deviceId);

  /// Chưa đăng nhập: đổi token sinh trắc (sau khi vân tay/khuôn mặt khớp) lấy phiên mới. 401 `BIOMETRIC_INVALID` nếu token hết hạn/bị thu hồi.
  Future<Session> biometricLogin(String deviceId, String token);

  /// Đã đăng nhập: thu hồi token sinh trắc của thiết bị này.
  Future<void> biometricRevoke(String deviceId);
}

class AuthRepository implements AuthApi {
  AuthRepository(this._api);
  final ApiClient _api;

  Map<String, dynamic> _map(dynamic data) => (data as Map).cast<String, dynamic>();

  @override
  Future<bool> login(String userNameOrEmail, String password) async {
    final r = _map(await _api.post('/api/auth/login',
        body: {'userNameOrEmail': userNameOrEmail, 'password': password}));
    return r['requiresOtp'] == true;
  }

  @override
  Future<Session> verifyOtp(String userNameOrEmail, String code) async =>
      Session.fromJson(_map(await _api.post('/api/auth/verify-otp',
          body: {'userNameOrEmail': userNameOrEmail, 'code': code})));

  @override
  Future<void> resendOtp(String userNameOrEmail) async {
    await _api.post('/api/auth/resend-otp', body: {'userNameOrEmail': userNameOrEmail});
  }

  @override
  Future<RegisterResult> register(String email, String password, String fullName) async {
    final r = _map(await _api.post('/api/auth/register',
        body: {'email': email, 'password': password, 'fullName': fullName}));
    return RegisterResult(
      message: (r['message'] ?? 'Đăng ký thành công, hãy đăng nhập.') as String,
      requiresEmailVerification: r['requiresEmailVerification'] == true,
    );
  }

  @override
  Future<Session> googleLogin(String idToken) async =>
      Session.fromJson(_map(await _api.post('/api/auth/google-login', body: {'idToken': idToken})));

  @override
  Future<String> forgotPassword(String email) async {
    final r = _map(await _api.post('/api/auth/forgot-password', body: {'email': email}));
    return (r['message'] ?? 'Nếu email có tài khoản, mã đặt lại mật khẩu đã được gửi.') as String;
  }

  @override
  Future<Session> resetPassword(String email, String code, String newPassword) async => Session.fromJson(
      _map(await _api.post('/api/auth/reset-password', body: {'email': email, 'code': code, 'newPassword': newPassword})));

  @override
  Future<Profile> me() async => Profile.fromJson(_map(await _api.get('/api/auth/me')));

  @override
  Future<({String token, DateTime expiresAt})> biometricEnroll(String deviceId) async {
    final r = _map(await _api.post('/api/auth/biometric/enroll', body: {'deviceId': deviceId}));
    return (token: r['token'] as String, expiresAt: DateTime.parse(r['expiresAt'] as String).toUtc());
  }

  @override
  Future<Session> biometricLogin(String deviceId, String token) async =>
      Session.fromJson(_map(await _api.post('/api/auth/biometric/login', body: {'deviceId': deviceId, 'token': token})));

  @override
  Future<void> biometricRevoke(String deviceId) async {
    await _api.post('/api/auth/biometric/revoke', body: {'deviceId': deviceId});
  }
}
