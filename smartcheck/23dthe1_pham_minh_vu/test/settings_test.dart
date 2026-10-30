import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/api_client.dart';
import 'package:pham_minh_vu_23dthe1/core/settings.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/auth_repository.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/auth_controller.dart';
import 'package:pham_minh_vu_23dthe1/features/settings/edit_profile_page.dart';
import 'package:pham_minh_vu_23dthe1/main.dart';

import 'support/fakes.dart';

Future<({AuthController auth, SettingsController settings, FakeAuthApi api, FakeVault vault})> _pump(
  WidgetTester t, {
  MemorySettingsStore? store,
  FakeVault? vault,
  FakeAuthApi? api,
}) async {
  t.view.physicalSize = const Size(800, 2000); // đủ cao để cả trang Cài đặt hiện cùng lúc
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final fakeApi = api ?? FakeAuthApi(role: UserRole.employee);
  final fakeVault = vault ?? FakeVault();
  final auth = AuthController(
    api: fakeApi,
    store: MemoryStore(sessionFor(UserRole.employee)),
    google: FakeGoogle(),
    biometric: fakeVault,
    deviceId: FakeDeviceId(),
  );
  await auth.restore();
  final settings = SettingsController(store ?? MemorySettingsStore());
  await settings.load();
  await t.pumpWidget(SmartCheckApp(
    auth: auth,
    api: ApiClient(tokenProvider: () => auth.token),
    authApi: fakeApi as AuthApi,
    deviceId: FakeDeviceId(),
    settings: settings,
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  return (auth: auth, settings: settings, api: fakeApi, vault: fakeVault);
}

Future<void> _openSettings(WidgetTester t) async {
  await t.tap(find.byTooltip('Hồ sơ'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.byKey(const Key('open-settings')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

double _scale(WidgetTester t) => MediaQuery.of(t.element(find.byType(Scaffold).first)).textScaler.scale(1);

void main() {
  group('SettingsController', () {
    test('mặc định, đổi, lưu và nạp lại', () async {
      final store = MemorySettingsStore();
      final s = SettingsController(store);
      await s.load();
      expect(s.textSize, AppTextSize.normal);
      expect(s.background, AppBackground.fog);
      expect(s.isDefault, isTrue);

      await s.setTextSize(AppTextSize.large);
      await s.setBackground(AppBackground.cream);
      expect(s.isDefault, isFalse);

      final reopened = SettingsController(store);
      await reopened.load();
      expect(reopened.textSize, AppTextSize.large);
      expect(reopened.background, AppBackground.cream);

      await reopened.reset();
      expect(reopened.isDefault, isTrue);
      expect(store.data, isEmpty);
    });

    test('giá trị lạ trong bộ nhớ thì rơi về mặc định', () async {
      final s = SettingsController(MemorySettingsStore({'textSize': 'huge', 'background': 'neon'}));
      await s.load();
      expect(s.isDefault, isTrue);
    });
  });

  group('kiểm tra form hồ sơ', () {
    test('họ tên', () {
      expect(validateFullName(' '), isNotNull);
      expect(validateFullName('A'), isNotNull);
      expect(validateFullName('Nguyễn Văn An'), isNull);
    });
    test('số điện thoại: trống hợp lệ, sai thì báo', () {
      expect(validatePhone(''), isNull);
      expect(validatePhone('0912345678'), isNull);
      expect(validatePhone('+84 912345678'), isNull);
      expect(validatePhone('12345'), isNotNull);
      expect(validatePhone('09123abc78'), isNotNull);
    });
  });

  testWidgets('đổi cỡ chữ và màu nền áp dụng ngay cho cả app và được lưu', (t) async {
    final store = MemorySettingsStore();
    await _pump(t, store: store);
    await _openSettings(t);
    expect(find.text('Cài đặt'), findsWidgets);
    expect(_scale(t), 1.0);

    await t.tap(find.byKey(const Key('text-size-xlarge')));
    await t.pump();
    expect(_scale(t), closeTo(1.3, 0.001));

    await t.tap(find.byKey(const Key('background-cream')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400)); // MaterialApp chuyển màu theme có hiệu ứng
    expect(Theme.of(t.element(find.byType(Scaffold).first)).scaffoldBackgroundColor, AppBackground.cream.page);
    expect(store.data, {'textSize': 'xlarge', 'background': 'cream'});

    await t.tap(find.byKey(const Key('reset-appearance')));
    await t.pump();
    expect(_scale(t), 1.0);
    expect(find.byKey(const Key('reset-appearance')), findsNothing);
  });

  testWidgets('lần mở sau vẫn giữ cỡ chữ và màu nền đã chọn', (t) async {
    await _pump(t, store: MemorySettingsStore({'textSize': 'small', 'background': 'mint'}));
    expect(_scale(t), closeTo(0.9, 0.001));
    expect(Theme.of(t.element(find.byType(Scaffold).first)).scaffoldBackgroundColor, AppBackground.mint.page);
  });

  testWidgets('sửa hồ sơ: lưu họ tên + số điện thoại, tên mới hiện ở phiên đăng nhập', (t) async {
    final r = await _pump(t);
    await _openSettings(t);
    await t.tap(find.byKey(const Key('edit-profile')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.enterText(find.byKey(const Key('profile-name')), '  Trần Thị Bình ');
    await t.enterText(find.byKey(const Key('profile-phone')), '0912345678');
    await t.tap(find.text('Lưu thay đổi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(r.api.updateCalls, 1);
    expect(r.api.savedProfile!.fullName, 'Trần Thị Bình');
    expect(r.api.savedProfile!.phoneNumber, '0912345678');
    expect(r.auth.session!.fullName, 'Trần Thị Bình');
    await t.pump(const Duration(milliseconds: 400)); // chờ trang sửa đóng hẳn
    expect(find.text('Đã cập nhật hồ sơ.'), findsOneWidget);
    expect(find.text('0912345678'), findsOneWidget);
  });

  testWidgets('sửa hồ sơ: dữ liệu sai thì không gọi API; xoá số điện thoại gửi null; lỗi server hiện ra', (t) async {
    final r = await _pump(t);
    await _openSettings(t);
    await t.tap(find.byKey(const Key('edit-profile')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await t.enterText(find.byKey(const Key('profile-name')), 'A');
    await t.enterText(find.byKey(const Key('profile-phone')), '123');
    await t.tap(find.text('Lưu thay đổi'));
    await t.pump();
    expect(find.text('Nhập họ và tên (ít nhất 2 ký tự).'), findsOneWidget);
    expect(find.textContaining('Số điện thoại gồm'), findsOneWidget);
    expect(r.api.updateCalls, 0);

    r.api.updateError = ApiException('Máy chủ từ chối', status: 400);
    await t.enterText(find.byKey(const Key('profile-name')), 'Lê Văn C');
    await t.enterText(find.byKey(const Key('profile-phone')), '');
    await t.tap(find.text('Lưu thay đổi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Máy chủ từ chối'), findsOneWidget);
    expect(find.byKey(const Key('profile-name')), findsOneWidget, reason: 'lỗi thì ở lại form');
    expect(r.auth.session!.fullName, isNot('Lê Văn C'));

    r.api.updateError = null;
    await t.tap(find.text('Lưu thay đổi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(r.api.savedProfile!.phoneNumber, isNull);
  });

  testWidgets('công tắc sinh trắc: bật rồi tắt; máy không hỗ trợ thì khoá và nêu lý do', (t) async {
    final r = await _pump(t);
    await _openSettings(t);
    final sw = find.byKey(const Key('biometric-switch'));
    expect(t.widget<SwitchListTile>(sw).value, isFalse);

    await t.tap(sw);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(r.vault.token, isNotNull);
    expect(t.widget<SwitchListTile>(sw).value, isTrue);

    await t.tap(sw);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(r.vault.stored, isNull);
    expect(r.api.revokeCalls, 1);
    expect(t.widget<SwitchListTile>(sw).value, isFalse);
  });

  testWidgets('công tắc sinh trắc bị khoá khi máy không hỗ trợ', (t) async {
    await _pump(t, vault: FakeVault(supported: false));
    await _openSettings(t);
    final sw = find.byKey(const Key('biometric-switch'));
    expect(t.widget<SwitchListTile>(sw).onChanged, isNull);
    expect(find.text('không hỗ trợ'), findsOneWidget);
  });
}
