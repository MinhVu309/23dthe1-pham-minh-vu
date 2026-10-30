import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/api_client.dart';
import 'package:pham_minh_vu_23dthe1/core/clock.dart';
import 'package:pham_minh_vu_23dthe1/core/router.dart';
import 'package:pham_minh_vu_23dthe1/core/widgets.dart' show BusyButton;
import 'package:pham_minh_vu_23dthe1/data/models/register_result.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/auth_repository.dart';
import 'package:pham_minh_vu_23dthe1/features/admin/admin_home.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/auth_controller.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/otp_page.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/register_page.dart';
import 'package:pham_minh_vu_23dthe1/features/employee/employee_home.dart';
import 'package:pham_minh_vu_23dthe1/features/manager_qr/manager_home.dart';
import 'package:pham_minh_vu_23dthe1/main.dart';
import 'package:pham_minh_vu_23dthe1/services/biometric_service.dart';
import 'package:pham_minh_vu_23dthe1/services/google_auth_service.dart';

import 'support/fakes.dart';

final _otpField = find.descendant(of: find.byType(OtpPage), matching: find.byType(TextField));

/// Đồng hồ giả: tiến cùng với `pump` để bộ đếm ngược OTP chạy đúng.
late DateTime _fakeNow;

Future<void> _advance(WidgetTester t, Duration d) async {
  _fakeNow = _fakeNow.add(d);
  await t.pump(d);
}

Future<AuthController> _pumpApp(WidgetTester t, FakeAuthApi api, {Session? saved, FakeVault? vault}) async {
  _fakeNow = DateTime(2026, 10, 29, 9);
  nowProvider = () => _fakeNow;
  addTearDown(() => nowProvider = DateTime.now);
  final auth = AuthController(
    api: api,
    store: MemoryStore(saved),
    google: FakeGoogle(),
    biometric: vault,
    deviceId: vault == null ? null : FakeDeviceId(),
  );
  await auth.restore();
  await t.pumpWidget(SmartCheckApp(
    auth: auth,
    api: ApiClient(tokenProvider: () => auth.token),
    authApi: api as AuthApi,
    deviceId: FakeDeviceId(),
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
        expect(find.byKey(const Key('nav-fab')), findsOneWidget); // nút cam giữa thanh điều hướng

        // Hồ sơ (dữ liệu từ /me) nằm trong bảng mở bằng mục "Hồ sơ" của thanh điều hướng.
        await t.tap(find.byTooltip('Hồ sơ'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(find.text('NV001'), findsOneWidget);
        expect(find.text('Chưa đăng ký'), findsOneWidget);
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

  group('đăng nhập sinh trắc học', () {
    testWidgets('đăng nhập mật khẩu + OTP lần đầu → hộp thoại mời → bật xong lần sau có nút vân tay', (t) async {
      final api = FakeAuthApi();
      final vault = FakeVault();
      final auth = await _pumpApp(t, api, vault: vault);
      expect(find.textContaining('Đăng nhập bằng vân tay'), findsNothing, reason: 'chưa bật thì chưa có nút');

      await t.enterText(find.byType(TextFormField).at(0), 'a@test.local');
      await t.enterText(find.byType(TextFormField).at(1), 'matkhau1');
      await t.tap(find.text('Đăng nhập'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(_otpField, '123456');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byType(EmployeeHome), findsOneWidget);
      expect(find.text('Đăng nhập nhanh bằng vân tay?'), findsOneWidget);
      await t.tap(find.text('Bật ngay'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(vault.token, isNotNull);
      expect(find.text('Đã bật đăng nhập bằng vân tay.'), findsOneWidget);

      await auth.logout();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Đăng nhập bằng vân tay'), findsOneWidget);

      await t.tap(find.text('Đăng nhập bằng vân tay'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(auth.status, AuthStatus.signedIn);
      expect(find.byType(EmployeeHome), findsOneWidget);
    });

    testWidgets('bấm "Để sau" thì không bật và không mời lại', (t) async {
      final vault = FakeVault();
      await _pumpApp(t, FakeAuthApi(), vault: vault);
      await t.enterText(find.byType(TextFormField).at(0), 'a@test.local');
      await t.enterText(find.byType(TextFormField).at(1), 'matkhau1');
      await t.tap(find.text('Đăng nhập'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(_otpField, '123456');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      await t.tap(find.text('Để sau'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(vault.token, isNull);
      expect(vault.declined, isNotEmpty);
    });

    testWidgets('hết hạn/bị thu hồi (401): báo lỗi và nút vân tay biến mất', (t) async {
      final api = FakeAuthApi()..biometricLoginError = ApiException('Phiên sinh trắc học đã hết hạn', status: 401);
      final vault = FakeVault()
        ..token = 'x'
        ..stored = BiometricHint(userId: 'u', email: 'a@test.local', fullName: 'An', expiresAt: DateTime.now().toUtc().add(const Duration(days: 3)));
      await _pumpApp(t, api, vault: vault);
      await t.pump();
      expect(find.text('Đăng nhập bằng vân tay'), findsOneWidget);
      expect(find.text('Xin chào An'), findsOneWidget);

      await t.tap(find.text('Đăng nhập bằng vân tay'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Phiên sinh trắc học đã hết hạn'), findsOneWidget);
      expect(find.text('Đăng nhập bằng vân tay'), findsNothing);
      expect(vault.stored, isNull);
    });
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

  group('đăng ký có xác minh email', () {
    Future<void> settle(WidgetTester t) async {
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> openRegister(WidgetTester t) async {
      await t.tap(find.text('Đăng ký'));
      await settle(t);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
    }

    Future<void> submit(WidgetTester t) async {
      final button = find.byType(BusyButton);
      await t.ensureVisible(button);
      await t.tap(button);
      await settle(t);
    }

    Future<void> fillAndSubmit(WidgetTester t, {String email = 'sv@test.local'}) async {
      final f = find.byType(TextFormField);
      await t.enterText(f.at(0), 'Sinh Vien');
      await t.enterText(f.at(1), email);
      await t.enterText(f.at(2), 'matkhau1');
      await t.enterText(f.at(3), 'matkhau1');
      await submit(t);
    }

    testWidgets('đăng ký → màn xác minh email → nhập đúng mã → vào app (có gửi đúng email)', (t) async {
      final api = FakeAuthApi();
      final auth = await _pumpApp(t, api);
      await openRegister(t);
      await fillAndSubmit(t);

      expect(api.registerCalls, 1);
      expect(find.byType(OtpPage), findsOneWidget);
      expect(find.text('Xác minh email'), findsOneWidget);
      expect(find.textContaining('sv@test.local'), findsOneWidget);
      expect(auth.status, AuthStatus.signedOut); // chưa xác minh thì chưa vào được app

      await t.enterText(_otpField, '654321');
      await settle(t);
      expect(api.lastVerifyIdentifier, 'sv@test.local');
      expect(api.lastCode, '654321');
      expect(auth.status, AuthStatus.signedIn);
      expect(find.byType(EmployeeHome), findsOneWidget);
      expect(find.byType(OtpPage), findsNothing);
      expect(find.text('Tạo tài khoản'), findsNothing); // mọi màn đăng ký đã đóng
    });

    testWidgets('server cũ chưa xác minh email: quay về đăng nhập với thông báo như trước', (t) async {
      final api = FakeAuthApi()..requiresVerification = false;
      await _pumpApp(t, api);
      await openRegister(t);
      await fillAndSubmit(t);
      expect(find.byType(OtpPage), findsNothing);
      expect(find.text('Đăng ký thành công, hãy đăng nhập.'), findsOneWidget);
    });

    testWidgets('mã sai: ở lại màn xác minh và hiện lỗi', (t) async {
      final api = FakeAuthApi()..verifyError = ApiException('OTP sai hoặc hết hạn', status: 401);
      final auth = await _pumpApp(t, api);
      await openRegister(t);
      await fillAndSubmit(t);
      await t.enterText(_otpField, '000000');
      await settle(t);
      expect(find.text('OTP sai hoặc hết hạn'), findsOneWidget);
      expect(find.byType(OtpPage), findsOneWidget);
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('gửi lại mã xác minh sau 30 giây, có thông báo riêng', (t) async {
      final api = FakeAuthApi();
      await _pumpApp(t, api);
      await openRegister(t);
      await fillAndSubmit(t);
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);
      await _advance(t, const Duration(seconds: 31));
      await t.tap(find.text('Gửi lại mã'));
      await t.pump();
      await t.pump();
      expect(api.resendCalls, 1);
      expect(find.text('Đã gửi lại mã xác minh, hãy kiểm tra email.'), findsOneWidget);
    });

    testWidgets('thoát giữa chừng: ở lại màn đăng ký, giữ dữ liệu, sửa email gõ nhầm rồi đăng ký lại', (t) async {
      final api = FakeAuthApi();
      await _pumpApp(t, api);
      await openRegister(t);
      await fillAndSubmit(t, email: 'sai@test.local');

      await t.tap(find.descendant(of: find.byType(OtpPage), matching: find.byIcon(Icons.arrow_back_rounded)));
      await settle(t);
      expect(find.byType(OtpPage), findsNothing);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.textContaining('chưa được xác minh'), findsOneWidget);
      expect(find.text('Sinh Vien'), findsOneWidget); // dữ liệu đã nhập vẫn còn

      await t.enterText(find.byType(TextFormField).at(1), 'dung@test.local');
      await submit(t);
      expect(api.registerCalls, 2);
      expect(api.lastRegisterEmail, 'dung@test.local');
      expect(find.textContaining('dung@test.local'), findsWidgets);
      expect(find.byType(OtpPage), findsOneWidget);
    });

    testWidgets('email đã được dùng: hiện lỗi của server và ở lại màn đăng ký', (t) async {
      final api = FakeAuthApi()..registerError = ApiException('Email này đã được đăng ký.', status: 400);
      await _pumpApp(t, api);
      await openRegister(t);
      await fillAndSubmit(t);
      expect(find.text('Email này đã được đăng ký.'), findsOneWidget);
      expect(find.byType(OtpPage), findsNothing);
    });

    test('RegisterResult mặc định không yêu cầu xác minh (tương thích server cũ)', () {
      expect(const RegisterResult(message: 'x').requiresEmailVerification, isFalse);
    });
  });

  group('quên mật khẩu', () {
    Future<void> settle(WidgetTester t) async {
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> press(WidgetTester t) async {
      final b = find.byType(BusyButton);
      await t.ensureVisible(b);
      await t.tap(b);
      await settle(t);
    }

    Future<void> openForgot(WidgetTester t) async {
      await t.tap(find.text('Quên mật khẩu?'));
      await settle(t);
      expect(find.text('Quên mật khẩu'), findsOneWidget);
    }

    Future<void> sendCode(WidgetTester t, {String email = 'sv@test.local'}) async {
      await t.enterText(find.byType(TextFormField).at(0), email);
      await press(t);
    }

    Future<void> fillReset(WidgetTester t, {String code = '123456', String pw = 'matkhaumoi1', String? confirm}) async {
      final f = find.byType(TextFormField);
      await t.enterText(f.at(0), code);
      await t.enterText(f.at(1), pw);
      await t.enterText(f.at(2), confirm ?? pw);
    }

    testWidgets('mở từ màn đăng nhập; email đã gõ ở ô đăng nhập được điền sẵn', (t) async {
      await _pumpApp(t, FakeAuthApi());
      await t.enterText(find.byType(TextFormField).at(0), 'da.go@test.local');
      await openForgot(t);
      expect(find.text('da.go@test.local'), findsOneWidget);
    });

    testWidgets('tên đăng nhập (không phải email) thì không điền sẵn', (t) async {
      await _pumpApp(t, FakeAuthApi());
      await t.enterText(find.byType(TextFormField).at(0), 'quanly');
      await openForgot(t);
      expect(find.text('quanly'), findsNothing);
    });

    testWidgets('email sai định dạng: báo lỗi và không gọi API', (t) async {
      final api = FakeAuthApi();
      await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t, email: 'khong-hop-le');
      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(api.forgotCalls, 0);
    });

    testWidgets('gửi mã: sang bước nhập mã, hiện thông báo của server và đếm ngược 5 phút', (t) async {
      final api = FakeAuthApi();
      await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t);
      expect(api.forgotCalls, 1);
      expect(api.lastForgotEmail, 'sv@test.local');
      expect(find.textContaining('mã đặt lại mật khẩu đã được gửi'), findsOneWidget);
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(find.textContaining('hết hạn sau 05:00'), findsOneWidget);
    });

    testWidgets('lỗi khi gửi mã hiện thông báo và ở lại bước 1', (t) async {
      final api = FakeAuthApi()..forgotError = ApiException('Máy chủ lỗi', status: 500);
      await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t);
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
      expect(find.text('Mật khẩu mới'), findsNothing);
    });

    testWidgets('bước 2 kiểm tra form: thiếu mã, mật khẩu yếu, nhập lại không khớp', (t) async {
      final api = FakeAuthApi();
      await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t);

      await fillReset(t, code: '123');
      await press(t);
      expect(find.text('Nhập đủ 6 số của mã'), findsOneWidget);

      await fillReset(t, pw: 'abc');
      await press(t);
      expect(find.textContaining('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);

      await fillReset(t, pw: 'matkhaumoi1', confirm: 'matkhauKHAC1');
      await press(t);
      expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
      expect(api.resetCalls, 0);
    });

    testWidgets('đúng mã: đổi mật khẩu, đăng nhập luôn và đóng mọi màn quên mật khẩu', (t) async {
      final api = FakeAuthApi();
      final auth = await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t);
      await fillReset(t, code: '654321', pw: 'matkhaumoi1');
      await press(t);

      expect(api.resetCalls, 1);
      expect(api.lastResetCode, '654321');
      expect(api.lastResetPassword, 'matkhaumoi1');
      expect(auth.status, AuthStatus.signedIn);
      expect(find.byType(EmployeeHome), findsOneWidget);
      expect(find.text('Quên mật khẩu'), findsNothing);
    });

    testWidgets('mã sai: hiện lỗi của server, ở lại màn và chưa đăng nhập', (t) async {
      final api = FakeAuthApi()..resetError = ApiException('Mã không đúng hoặc đã hết hạn', status: 401);
      final auth = await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t);
      await fillReset(t);
      await press(t);
      expect(find.text('Mã không đúng hoặc đã hết hạn'), findsOneWidget);
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('gửi lại mã chỉ mở sau 60 giây (khớp thời gian chặn của server)', (t) async {
      final api = FakeAuthApi();
      await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t);
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);

      await _advance(t, const Duration(seconds: 31));
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget); // 30 giây của OTP đăng nhập chưa đủ ở đây

      await _advance(t, const Duration(seconds: 30));
      expect(find.text('Gửi lại mã'), findsOneWidget);
      await t.ensureVisible(find.text('Gửi lại mã'));
      await t.tap(find.text('Gửi lại mã'));
      await t.pump();
      await t.pump();
      expect(api.forgotCalls, 2);
      expect(find.text('Đã gửi lại mã, hãy kiểm tra email.'), findsOneWidget);
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget); // đếm lại từ đầu
    });

    testWidgets('"Đổi email khác" quay về bước 1 và xoá mã đã nhập', (t) async {
      final api = FakeAuthApi();
      await _pumpApp(t, api);
      await openForgot(t);
      await sendCode(t);
      await t.enterText(find.byType(TextFormField).at(0), '999999');
      await t.ensureVisible(find.text('Đổi email khác'));
      await t.tap(find.text('Đổi email khác'));
      await settle(t);
      expect(find.text('Mật khẩu mới'), findsNothing);
      expect(find.text('Gửi mã xác minh'), findsOneWidget);
    });
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
