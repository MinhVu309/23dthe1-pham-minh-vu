import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/api_client.dart';
import 'package:pham_minh_vu_23dthe1/core/clock.dart';
import 'package:pham_minh_vu_23dthe1/core/router.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/auth_repository.dart';
import 'package:pham_minh_vu_23dthe1/features/admin/admin_home.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/auth_controller.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/otp_page.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/register_page.dart';
import 'package:pham_minh_vu_23dthe1/features/employee/employee_home.dart';
import 'package:pham_minh_vu_23dthe1/features/manager_qr/manager_home.dart';
import 'package:pham_minh_vu_23dthe1/main.dart';
import 'package:pham_minh_vu_23dthe1/services/google_auth_service.dart';

import 'support/fakes.dart';

final _otpField = find.descendant(of: find.byType(OtpPage), matching: find.byType(TextField));

/// Đồng hồ giả: tiến cùng với `pump` để bộ đếm ngược OTP chạy đúng.
late DateTime _fakeNow;

Future<void> _advance(WidgetTester t, Duration d) async {
  _fakeNow = _fakeNow.add(d);
  await t.pump(d);
}

Future<AuthController> _pumpApp(WidgetTester t, FakeAuthApi api, {Session? saved}) async {
  _fakeNow = DateTime(2026, 10, 29, 9);
  nowProvider = () => _fakeNow;
  addTearDown(() => nowProvider = DateTime.now);
  final auth = AuthController(api: api, store: MemoryStore(saved), google: FakeGoogle());
  await auth.restore();
  await t.pumpWidget(SmartCheckApp(
    auth: auth,
    api: ApiClient(tokenProvider: () => auth.token),
    authApi: api as AuthApi,
  ));
  await t.pump();
  return auth;
}

void main() {
  group('điều hướng theo role', () {
    for (final (role, type, text) in [
      (UserRole.admin, AdminHome, 'Quản trị viên'),
      (UserRole.manager, ManagerHome, 'Quản lý'),
      (UserRole.employee, EmployeeHome, 'Nhân viên'),
    ]) {
      testWidgets('${role.apiName} vào đúng trang', (t) async {
        await _pumpApp(t, FakeAuthApi(role: role), saved: sessionFor(role));
        await t.pump();
        expect(find.byType(type), findsOneWidget);
        expect(find.text(text), findsWidgets);
        expect(find.text('NV001'), findsOneWidget); // dữ liệu từ /me
      });
    }

    test('homeForRole trả đúng widget', () {
      expect(homeForRole(UserRole.admin), isA<AdminHome>());
      expect(homeForRole(UserRole.manager), isA<ManagerHome>());
      expect(homeForRole(UserRole.employee), isA<EmployeeHome>());
    });
  });

  group('màn đăng nhập', () {
    testWidgets('bỏ trống thì báo lỗi và không gọi API', (t) async {
      await _pumpApp(t, FakeAuthApi());
      await t.tap(find.text('Đăng nhập'));
      await t.pump();
      expect(find.text('Nhập email hoặc tên đăng nhập'), findsOneWidget);
      expect(find.text('Nhập mật khẩu'), findsOneWidget);
    });

    testWidgets('sai mật khẩu hiện thông báo của server', (t) async {
      final api = FakeAuthApi()..loginError = ApiException('Sai tài khoản hoặc mật khẩu', status: 401);
      await _pumpApp(t, api);
      await t.enterText(find.byType(TextFormField).at(0), 'admin@test.local');
      await t.enterText(find.byType(TextFormField).at(1), 'sai');
      await t.tap(find.text('Đăng nhập'));
      await t.pump();
      await t.pump();
      expect(find.text('Sai tài khoản hoặc mật khẩu'), findsOneWidget);
      expect(find.byType(OtpPage), findsNothing);
    });

    testWidgets('Google chưa cấu hình thì báo rõ lý do', (t) async {
      final api = FakeAuthApi();
      final google = FakeGoogle()..error = GoogleNotConfigured();
      final auth = AuthController(api: api, store: MemoryStore(), google: google);
      await auth.restore();
      await t.pumpWidget(SmartCheckApp(auth: auth, api: ApiClient(tokenProvider: () => null), authApi: api));
      await t.pump();
      await t.tap(find.text('Tiếp tục với Google'));
      await t.pump();
      await t.pump();
      expect(find.textContaining('chưa được cấu hình'), findsOneWidget);
    });
  });

  testWidgets('đăng nhập → OTP → trang chủ rồi đăng xuất', (t) async {
    final api = FakeAuthApi(role: UserRole.manager);
    final auth = await _pumpApp(t, api);

    await t.enterText(find.byType(TextFormField).at(0), 'quanly@test.local');
    await t.enterText(find.byType(TextFormField).at(1), 'matkhau1');
    await t.tap(find.text('Đăng nhập'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.textContaining('hết hạn sau 05:00'), findsOneWidget);

    await t.enterText(_otpField, '123456'); // đủ 6 số tự gửi
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.pump(const Duration(milliseconds: 400)); // hiệu ứng đóng màn OTP
    expect(api.lastCode, '123456');
    expect(auth.status, AuthStatus.signedIn);
    expect(find.byType(ManagerHome), findsOneWidget);
    expect(find.byType(OtpPage), findsNothing);

    // đăng xuất có hỏi xác nhận
    await t.tap(find.byTooltip('Đăng xuất'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
    await t.pump(const Duration(milliseconds: 400));
    expect(auth.status, AuthStatus.signedOut);
    expect(find.text('SmartCheck'), findsOneWidget);
  });

  testWidgets('OTP sai: giữ ở màn OTP và hiện lỗi', (t) async {
    final api = FakeAuthApi()..verifyError = ApiException('OTP sai hoặc hết hạn', status: 401);
    await _pumpApp(t, api);
    await t.enterText(find.byType(TextFormField).at(0), 'a@test.local');
    await t.enterText(find.byType(TextFormField).at(1), 'matkhau1');
    await t.tap(find.text('Đăng nhập'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(_otpField, '000000');
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('OTP sai hoặc hết hạn'), findsOneWidget);
    expect(find.byType(OtpPage), findsOneWidget);
  });

  testWidgets('OTP: nút gửi lại bị khoá 30 giây rồi mở', (t) async {
    final api = FakeAuthApi();
    await _pumpApp(t, api);
    await t.enterText(find.byType(TextFormField).at(0), 'a@test.local');
    await t.enterText(find.byType(TextFormField).at(1), 'matkhau1');
    await t.tap(find.text('Đăng nhập'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);

    await _advance(t, const Duration(seconds: 31));
    expect(find.text('Gửi lại mã'), findsOneWidget);
    await t.tap(find.text('Gửi lại mã'));
    await t.pump();
    await t.pump();
    expect(api.resendCalls, 1);
    expect(find.textContaining('Gửi lại mã sau'), findsOneWidget); // đếm lại từ đầu
  });

  group('kiểm tra form đăng ký', () {
    test('mật khẩu', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('ab1'), contains('6'));
      expect(validatePassword('ABCDEF1'), contains('chữ thường'));
      expect(validatePassword('abcdefg'), contains('chữ số'));
      expect(validatePassword('abcde1'), isNull);
    });
    test('email', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('khong-hop-le'), isNotNull);
      expect(validateEmail(' vu@gmail.com '), isNull);
    });
  });

  test('định dạng đếm ngược OTP', () {
    expect(formatCountdown(const Duration(minutes: 5)), '05:00');
    expect(formatCountdown(const Duration(seconds: 65)), '01:05');
    expect(formatCountdown(const Duration(seconds: -3)), '00:00');
  });
}
