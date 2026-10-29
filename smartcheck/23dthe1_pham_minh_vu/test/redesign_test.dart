import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/clock.dart';
import 'package:pham_minh_vu_23dthe1/core/geo.dart';
import 'package:pham_minh_vu_23dthe1/core/theme.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/features/admin/admin_home.dart';
import 'package:pham_minh_vu_23dthe1/features/employee/employee_home.dart';
import 'package:pham_minh_vu_23dthe1/features/manager_qr/manager_home.dart';
import 'package:pham_minh_vu_23dthe1/features/scan/check_page.dart';

import 'support/fake_server.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
}

Map<String, dynamic> _me(UserRole role) => {'id': 'u', 'fullName': 'Tên thử', 'email': 'x@test.local', 'role': role.apiName, 'employeeCode': 'NV001', 'hasFace': false, 'hasDevice': false};

Map<String, dynamic> _mine(int id, DateTime local, {String type = 'CheckIn', bool late = false, bool early = false}) => {
      'id': id,
      'type': type,
      'timestamp': local.toUtc().toIso8601String(),
      'isLate': late,
      'isEarlyLeave': early,
      'distanceMeters': 10.0,
      'location': 'Văn phòng chính',
    };

Future<bool> _faceOk(BuildContext _) async => true;

void main() {
  group('geo.distanceMeters', () {
    test('cùng một điểm là 0; đối xứng', () {
      expect(distanceMeters(10.8019, 106.7144, 10.8019, 106.7144), 0);
      expect(distanceMeters(10.8, 106.7, 10.9, 106.8), closeTo(distanceMeters(10.9, 106.8, 10.8, 106.7), 1e-6));
    });
    test('0,001° kinh độ ở vĩ độ 10,8° ≈ 109 m; 0,001° vĩ độ ≈ 111 m', () {
      expect(distanceMeters(10.8019, 106.7144, 10.8019, 106.7154), closeTo(109.4, 1));
      expect(distanceMeters(10.8019, 106.7144, 10.8029, 106.7144), closeTo(111.2, 1));
    });
  });

  group('bảng màu', () {
    test('nút chính là xanh lá, điểm nhấn là cam (theo mẫu thiết kế)', () {
      final theme = buildTheme();
      expect(theme.colorScheme.primary, AppColors.brand);
      expect(theme.colorScheme.secondary, AppColors.amber);
      expect(AppColors.brand.g, greaterThan(AppColors.brand.r)); // xanh lá: kênh G trội
      expect(AppColors.amber.r, greaterThan(AppColors.amber.b)); // cam: kênh R trội
    });
  });

  group('Màn Chấm công (bố cục mới)', () {
    FakeServer withLocation() => FakeServer()..on('GET', '/api/locations', (_) => FakeServer.json(page([location(1, 'Văn phòng chính')])));

    testWidgets('thẻ số lớn: khoảng cách ước tính tới điểm gần nhất, bán kính cho phép', (t) async {
      // 0,001° kinh độ cách tâm địa điểm ≈ 109 m
      await pumpScreen(t, withLocation(), CheckPage(scan: (_) async => null, verifyFace: _faceOk), location: FakeLocation(reading: gps(lat: 10.8019, lng: 106.7154)));
      await _settle(t);
      expect(t.widget<Text>(find.byKey(const Key('distance-value'))).data, '109');
      expect(find.text('Cách Văn phòng chính'), findsOneWidget);
      expect(find.text('Cho phép 150 m'), findsOneWidget);
    });

    testWidgets('chưa có danh sách địa điểm thì hiện "--" và vẫn chấm công được', (t) async {
      await pumpScreen(t, FakeServer(), CheckPage(scan: (_) async => null, verifyFace: _faceOk));
      await _settle(t);
      expect(t.widget<Text>(find.byKey(const Key('distance-value'))).data, '--');
      expect(find.textContaining('Quét mã QR'), findsOneWidget);
    });

    testWidgets('xa địa điểm hơn 1 km thì hiện bằng km', (t) async {
      await pumpScreen(t, withLocation(), CheckPage(scan: (_) async => null, verifyFace: _faceOk), location: FakeLocation(reading: gps(lat: 10.8919, lng: 106.7144)));
      await _settle(t);
      expect(t.widget<Text>(find.byKey(const Key('distance-value'))).data, '10.0');
      expect(find.text('km'), findsOneWidget);
    });

    testWidgets('banner có thể ẩn đi', (t) async {
      await pumpScreen(t, FakeServer(), CheckPage(scan: (_) async => null, verifyFace: _faceOk));
      await _settle(t);
      expect(find.text('Đúng người, đúng chỗ, đúng giờ'), findsOneWidget);
      await t.tap(find.byTooltip('Ẩn'));
      await _settle(t);
      expect(find.text('Đúng người, đúng chỗ, đúng giờ'), findsNothing);
    });

    testWidgets('đường thời gian ba bước: chỉ "Vị trí" xong lúc đầu, đi hết luồng thì cả ba bước xong', (t) async {
      final s = FakeServer()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json({'id': 1, 'type': 'CheckIn', 'timeLocal': '2026-10-29T08:00:00+07:00', 'isLate': false, 'isEarlyLeave': false, 'distance': 5.0, 'flags': []}));
      await pumpScreen(t, s, CheckPage(verifyFace: _faceOk, scan: (_) async => 'SC1.1.1.x'));
      await _settle(t);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget); // chỉ "Vị trí" đã xong
      expect(find.byKey(const Key('location-coords')), findsOneWidget);

      await t.tap(find.textContaining('Quét mã QR'));
      await t.pump(const Duration(seconds: 1));
      await _settle(t);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3)); // cả ba bước xong
    });

    testWidgets('quét lại: các bước làm lại từ đầu', (t) async {
      final s = FakeServer()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json({'code': 'QR_INVALID', 'message': 'QR hết hạn'}, 400));
      var face = true;
      await pumpScreen(t, s, CheckPage(verifyFace: (_) async => face, scan: (_) async => 'SC1.1.1.x'));
      await _settle(t);
      await t.tap(find.textContaining('Quét mã QR'));
      await t.pump(const Duration(seconds: 1));
      await _settle(t);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));

      face = false; // lần sau không qua khuôn mặt
      await t.tap(find.textContaining('Quét mã QR'));
      await t.pump(const Duration(seconds: 1));
      await _settle(t);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget); // chỉ còn "Vị trí"
    });

    testWidgets('thẻ kết quả nằm trong cây và được cuộn tới sau khi gửi', (t) async {
      final s = FakeServer()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json({'code': 'OUT_OF_RANGE', 'message': 'Bạn cách điểm chấm công 500 m'}, 400));
      await pumpScreen(t, s, CheckPage(verifyFace: _faceOk, scan: (_) async => 'SC1.1.1.x'));
      await _settle(t);
      await t.tap(find.textContaining('Quét mã QR'));
      await t.pump(const Duration(seconds: 1));
      await _settle(t);
      expect(find.byKey(const Key('check-failure')), findsOneWidget);
      final box = t.getRect(find.byKey(const Key('check-failure')));
      expect(box.top, lessThan(t.view.physicalSize.height / t.view.devicePixelRatio)); // nằm trong vùng nhìn thấy
    });
  });

  group('Trang chủ (bố cục mới)', () {
    final now = DateTime(2026, 10, 29, 12);

    testWidgets('Employee: thẻ trạng thái hôm nay hiện giờ vào/ra và đúng giờ/đi trễ', (t) async {
      nowProvider = () => now;
      addTearDown(() => nowProvider = DateTime.now);
      final s = FakeServer()
        ..on('GET', '/api/auth/me', (_) => FakeServer.json(_me(UserRole.employee)))
        ..on('GET', '/api/attendance/my', (_) => FakeServer.json([_mine(1, DateTime(2026, 10, 29, 8, 25), late: true), _mine(2, DateTime(2026, 10, 28, 8, 0))]));
      await pumpScreen(t, s, const EmployeeHome(), role: UserRole.employee);
      await _settle(t);
      expect(find.text('Vào ca hôm nay'), findsOneWidget);
      expect(find.text('08:25 · Đi trễ'), findsOneWidget);
      expect(find.text('Chưa chấm công'), findsOneWidget); // chưa ra ca
    });

    testWidgets('Employee: nút cam giữa mở màn Chấm công; lối tắt mở Lịch sử', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/auth/me', (_) => FakeServer.json(_me(UserRole.employee)))
        ..on('GET', '/api/attendance/my', (_) => FakeServer.json([]))
        ..on('GET', '/api/locations', (_) => FakeServer.json(page([])));
      await pumpScreen(t, s, const EmployeeHome(), role: UserRole.employee);
      await _settle(t);

      await t.tap(find.byTooltip('Lịch sử'));
      await _settle(t);
      expect(find.text('Lịch sử chấm công'), findsOneWidget);
      await t.pageBack();
      await _settle(t);

      await t.tap(find.byKey(const Key('nav-fab')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(CheckPage), findsOneWidget);
    });

    testWidgets('Admin: thẻ trạng thái đếm lượt chấm công hôm nay và cảnh báo chưa xử lý', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/auth/me', (_) => FakeServer.json(_me(UserRole.admin)))
        ..on('GET', '/api/attendance', (_) => FakeServer.json({'total': 12, 'items': []}))
        ..on('GET', '/api/fraud-alerts', (_) => FakeServer.json([fraud(1, 'a'), fraud(2, 'b'), fraud(3, 'c')]));
      await pumpScreen(t, s, const AdminHome());
      await _settle(t);
      expect(find.text('12 lượt'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(s.calls('GET', '/api/fraud-alerts').single.queryParameters, {'resolved': false});
    });

    testWidgets('Admin: chip nhóm lọc các thẻ chức năng', (t) async {
      t.view.physicalSize = const Size(800, 2600); // đủ cao để danh sách dựng hết 9 thẻ
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = FakeServer()
        ..on('GET', '/api/auth/me', (_) => FakeServer.json(_me(UserRole.admin)))
        ..on('GET', '/api/attendance', (_) => FakeServer.json({'total': 0, 'items': []}))
        ..on('GET', '/api/fraud-alerts', (_) => FakeServer.json([]));
      await pumpScreen(t, s, const AdminHome());
      await _settle(t);
      for (final title in ['Nhân viên', 'Phòng ban', 'Ca làm việc', 'Địa điểm', 'Điểm chấm công', 'Bảng công', 'Bản đồ chấm công', 'Cảnh báo gian lận', 'Đơn nghỉ phép']) {
        expect(find.text(title), findsWidgets, reason: title);
      }

      await t.tap(find.widgetWithText(ChoiceChip, 'Nghỉ phép'));
      await _settle(t);
      expect(find.text('Đơn nghỉ phép'), findsOneWidget);
      expect(find.text('Phòng ban'), findsNothing);

      await t.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
      await _settle(t);
      expect(find.text('Phòng ban'), findsWidgets);
    });

    testWidgets('Manager: có 5 chức năng, chip Chấm công/Nghỉ phép; nút giữa là Điểm chấm công', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/auth/me', (_) => FakeServer.json(_me(UserRole.manager)))
        ..on('GET', '/api/attendance', (_) => FakeServer.json({'total': 0, 'items': []}))
        ..on('GET', '/api/fraud-alerts', (_) => FakeServer.json([]));
      await pumpScreen(t, s, const ManagerHome(), role: UserRole.manager);
      await _settle(t);
      expect(find.widgetWithText(ChoiceChip, 'Chấm công'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Nghỉ phép'), findsOneWidget);
      expect(find.byTooltip('Điểm chấm công'), findsOneWidget); // tooltip của nút cam giữa
    });

    testWidgets('lỗi tải thẻ trạng thái hiện thông báo thay vì treo', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/auth/me', (_) => FakeServer.json(_me(UserRole.employee)))
        ..on('GET', '/api/attendance/my', (_) => FakeServer.json({'message': 'Máy chủ lỗi'}, 500));
      await pumpScreen(t, s, const EmployeeHome(), role: UserRole.employee);
      await _settle(t);
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
    });
  });
}
