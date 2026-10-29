import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/api_client.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/auth_controller.dart';
import 'package:pham_minh_vu_23dthe1/services/google_auth_service.dart';

import 'support/fakes.dart';

AuthController _make(FakeAuthApi api, MemoryStore store, [FakeGoogle? g]) =>
    AuthController(api: api, store: store, google: g ?? FakeGoogle());

void main() {
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
