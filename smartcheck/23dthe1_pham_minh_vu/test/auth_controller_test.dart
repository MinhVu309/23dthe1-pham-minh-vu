import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/api_client.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/auth_controller.dart';
import 'package:pham_minh_vu_23dthe1/services/biometric_service.dart';
import 'package:pham_minh_vu_23dthe1/services/google_auth_service.dart';

import 'support/fakes.dart';

AuthController _make(FakeAuthApi api, MemoryStore store, [FakeGoogle? g]) =>
    AuthController(api: api, store: store, google: g ?? FakeGoogle());

void main() {
  _biometricTests();

  test('chưa có phiên đã lưu → signedOut', () async {
    final c = _make(FakeAuthApi(), MemoryStore());
    expect(c.status, AuthStatus.unknown);
    await c.restore();
    expect(c.status, AuthStatus.signedOut);
  });

  test('có phiên đã lưu → signedIn và hỏi /me để kiểm tra token', () async {
    final api = FakeAuthApi();
    final c = _make(api, MemoryStore(sessionFor(UserRole.manager)));
    await c.restore();
    expect(c.status, AuthStatus.signedIn);
    expect(c.session!.role, UserRole.manager);
    expect(c.token, 'jwt-Manager');
    expect(api.meCalls, 1);
  });

  test('mất mạng lúc mở app vẫn giữ phiên', () async {
    final api = FakeAuthApi()..meError = ApiException('offline');
    final c = _make(api, MemoryStore(sessionFor(UserRole.employee)));
    await c.restore();
    expect(c.status, AuthStatus.signedIn);
  });

  test('verifyOtp lưu phiên và chuyển sang signedIn', () async {
    final store = MemoryStore();
    final c = _make(FakeAuthApi(role: UserRole.admin), store);
    await c.restore();
    await c.verifyOtp('  admin@test.local ', ' 123456 ');
    expect(c.status, AuthStatus.signedIn);
    expect(c.session!.role, UserRole.admin);
    expect(store.saved?.token, 'jwt-Admin');
  });

  test('verifyOtp sai thì không đổi trạng thái', () async {
    final api = FakeAuthApi()..verifyError = ApiException('OTP sai hoặc hết hạn', status: 401);
    final c = _make(api, MemoryStore());
    await c.restore();
    await expectLater(c.verifyOtp('a', '000000'), throwsA(isA<ApiException>()));
    expect(c.status, AuthStatus.signedOut);
  });

  test('401 từ server → đăng xuất, xoá phiên đã lưu, có thông báo', () async {
    final store = MemoryStore(sessionFor(UserRole.employee));
    final google = FakeGoogle();
    final c = _make(FakeAuthApi(), store, google);
    await c.restore();
    c.handleUnauthorized();
    await Future<void>.delayed(Duration.zero);
    expect(c.status, AuthStatus.signedOut);
    expect(store.saved, isNull);
    expect(google.signedOut, isTrue);
    expect(c.takeNotice(), contains('hết hạn'));
    expect(c.takeNotice(), isNull);
  });

  test('handleUnauthorized khi chưa đăng nhập thì bỏ qua', () async {
    final c = _make(FakeAuthApi(), MemoryStore());
    await c.restore();
    c.handleUnauthorized();
    expect(c.takeNotice(), isNull);
  });

  test('đăng xuất chủ động xoá phiên', () async {
    final store = MemoryStore(sessionFor(UserRole.admin));
    final c = _make(FakeAuthApi(), store);
    await c.restore();
    await c.logout();
    expect(c.status, AuthStatus.signedOut);
    expect(store.saved, isNull);
    expect(c.takeNotice(), isNull);
  });

  test('Google: chưa cấu hình / huỷ được ném nguyên cho UI xử lý', () async {
    final g = FakeGoogle()..error = GoogleNotConfigured();
    final c = _make(FakeAuthApi(), MemoryStore(), g);
    await expectLater(c.signInWithGoogle(), throwsA(isA<GoogleNotConfigured>()));
    g.error = GoogleCancelled();
    await expectLater(c.signInWithGoogle(), throwsA(isA<GoogleCancelled>()));
    expect(c.status, isNot(AuthStatus.signedIn));
  });

  test('Google thành công → signedIn', () async {
    final c = _make(FakeAuthApi(role: UserRole.employee), MemoryStore());
    await c.restore();
    await c.signInWithGoogle();
    expect(c.status, AuthStatus.signedIn);
  });

  test('role lạ rơi về Employee', () {
    expect(UserRole.parse('Admin'), UserRole.admin);
    expect(UserRole.parse('manager'), UserRole.manager);
    expect(UserRole.parse('Gì-đó'), UserRole.employee);
    expect(UserRole.parse(null), UserRole.employee);
  });
}

AuthController _withBio(FakeAuthApi api, FakeVault vault) => AuthController(
      api: api,
      store: MemoryStore(),
      google: FakeGoogle(),
      biometric: vault,
      deviceId: FakeDeviceId(),
    );

void _biometricTests() {
  group('đăng nhập sinh trắc học', () {
    test('mật khẩu + OTP xong thì mời bật; bật xong lần sau đăng nhập được bằng token đã cất', () async {
      final api = FakeAuthApi();
      final vault = FakeVault();
      final c = _withBio(api, vault);

      await c.verifyOtp('a@b.c', '123456');
      expect(await c.takeBiometricOffer(), 'vân tay');
      expect(await c.takeBiometricOffer(), isNull, reason: 'chỉ mời một lần mỗi lần đăng nhập');

      await c.enableBiometric();
      expect(api.lastBiometricDevice, 'device-1');
      expect(vault.token, 'bio-token-1');
      expect(await c.isBiometricEnabled(), isTrue);

      await c.logout();
      expect(c.status, AuthStatus.signedOut);
      final option = await c.biometricOption();
      expect(option!.label, 'vân tay');

      await c.loginWithBiometric();
      expect(api.lastBiometricToken, 'bio-token-1');
      expect(c.status, AuthStatus.signedIn);
      expect(await c.takeBiometricOffer(), isNull, reason: 'đăng nhập sinh trắc không mời lại');
    });

    test('không mời khi máy không hỗ trợ, đã bật sẵn, hoặc đã bấm "Để sau"', () async {
      final unsupported = _withBio(FakeAuthApi(), FakeVault(supported: false));
      await unsupported.verifyOtp('a@b.c', '123456');
      expect(await unsupported.takeBiometricOffer(), isNull);

      final vault = FakeVault();
      final c = _withBio(FakeAuthApi(), vault);
      await c.verifyOtp('a@b.c', '123456');
      await c.declineBiometricOffer();
      await c.verifyOtp('a@b.c', '123456');
      expect(await c.takeBiometricOffer(), isNull);

      final enabled = _withBio(FakeAuthApi(), FakeVault());
      await enabled.verifyOtp('a@b.c', '123456');
      await enabled.enableBiometric();
      await enabled.verifyOtp('a@b.c', '123456');
      expect(await enabled.takeBiometricOffer(), isNull);
    });

    test('huỷ hộp thoại quét lúc bật → thu hồi token vừa cấp, không lưu gì', () async {
      final api = FakeAuthApi();
      final vault = FakeVault()..scanError = const BiometricCancelled();
      final c = _withBio(api, vault);
      await c.verifyOtp('a@b.c', '123456');
      await expectLater(c.enableBiometric(), throwsA(isA<BiometricCancelled>()));
      expect(api.revokeCalls, 1);
      expect(vault.stored, isNull);
    });

    test('người dùng huỷ lúc đăng nhập → vẫn giữ thông tin để thử lại', () async {
      final vault = FakeVault();
      final c = _withBio(FakeAuthApi(), vault);
      await c.verifyOtp('a@b.c', '123456');
      await c.enableBiometric();
      await c.logout();

      vault.scanError = const BiometricCancelled();
      await expectLater(c.loginWithBiometric(), throwsA(isA<BiometricCancelled>()));
      expect(c.status, AuthStatus.signedOut);
      expect(vault.stored, isNotNull);
    });

    test('máy không còn sinh trắc học → xoá thông tin; lỗi tạm thời (khoá do quét sai) thì giữ', () async {
      final vault = FakeVault();
      final c = _withBio(FakeAuthApi(), vault);
      await c.verifyOtp('a@b.c', '123456');
      await c.enableBiometric();
      await c.logout();

      vault.scanError = const BiometricFailed('temporaryLockout');
      await expectLater(c.loginWithBiometric(), throwsA(isA<BiometricFailed>()));
      expect(vault.stored, isNotNull);

      vault.scanError = const BiometricFailed('noBiometricsEnrolled', permanent: true);
      await expectLater(c.loginWithBiometric(), throwsA(isA<BiometricFailed>()));
      expect(vault.stored, isNull);
      expect(await c.biometricOption(), isNull);
    });

    test('server báo token hết hạn/thu hồi (401) → xoá thông tin; mất mạng thì giữ', () async {
      final api = FakeAuthApi();
      final vault = FakeVault();
      final c = _withBio(api, vault);
      await c.verifyOtp('a@b.c', '123456');
      await c.enableBiometric();
      await c.logout();

      api.biometricLoginError = ApiException('offline');
      await expectLater(c.loginWithBiometric(), throwsA(isA<ApiException>()));
      expect(vault.stored, isNotNull);

      api.biometricLoginError = ApiException('hết hạn', status: 401, code: 'BIOMETRIC_INVALID');
      await expectLater(c.loginWithBiometric(), throwsA(isA<ApiException>()));
      expect(vault.stored, isNull);
      expect(c.status, AuthStatus.signedOut);
    });

    test('tắt sinh trắc → thu hồi ở server và xoá trên máy; đặt lại mật khẩu cũng xoá', () async {
      final api = FakeAuthApi();
      final vault = FakeVault();
      final c = _withBio(api, vault);
      await c.verifyOtp('a@b.c', '123456');
      await c.enableBiometric();
      await c.disableBiometric();
      expect(api.revokeCalls, 1);
      expect(vault.stored, isNull);

      await c.enableBiometric();
      await c.logout();
      await c.resetPassword('a@b.c', '123456', 'matkhau1');
      expect(vault.stored, isNull, reason: 'server đã thu hồi token khi đổi mật khẩu');
    });
  });
}
