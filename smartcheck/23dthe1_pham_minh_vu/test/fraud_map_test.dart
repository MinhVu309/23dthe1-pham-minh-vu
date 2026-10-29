import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/data/models/attendance_record.dart';
import 'package:pham_minh_vu_23dthe1/data/models/attendance.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/features/admin/fraud_alerts_page.dart';
import 'package:pham_minh_vu_23dthe1/features/map/attendance_map_page.dart';
import 'package:pham_minh_vu_23dthe1/services/location_service.dart';

import 'support/fake_server.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
}

void main() {
  group('Cảnh báo gian lận', () {
    testWidgets('mặc định lọc "Chưa xử lý", hiện lý do, người, chi tiết', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/fraud-alerts', (_) => FakeServer.json([
              fraud(1, 'Thiết bị báo vị trí giả lập (mock location)', who: 'Trần Thị B'),
              fraud(2, 'Chấm công từ thiết bị chưa đăng ký'),
            ]));
      await pumpScreen(t, s, const FraudAlertsPage(), role: UserRole.manager);
      await _settle(t);

      expect(s.calls('GET', '/api/fraud-alerts').single.queryParameters, {'resolved': false});
      expect(find.text('Thiết bị báo vị trí giả lập (mock location)'), findsOneWidget);
      expect(find.textContaining('Trần Thị B'), findsOneWidget);
      expect(find.textContaining('lat=10.8'), findsWidgets);
      expect(find.text('Đã xử lý'), findsNWidgets(3)); // 1 chip lọc + 2 nút
    });

    testWidgets('không có cảnh báo thì hiện trạng thái trống', (t) async {
      final s = FakeServer()..on('GET', '/api/fraud-alerts', (_) => FakeServer.json([]));
      await pumpScreen(t, s, const FraudAlertsPage());
      await _settle(t);
      expect(find.text('Không có cảnh báo nào cần xử lý'), findsOneWidget);
    });

    testWidgets('đánh dấu đã xử lý: gọi POST resolve rồi tải lại, cảnh báo biến mất khỏi danh sách', (t) async {
      var resolved = false;
      final s = FakeServer()
        ..on('GET', '/api/fraud-alerts', (_) => FakeServer.json(resolved ? [] : [fraud(7, 'GPS giả')]))
        ..on('POST', '/api/fraud-alerts/7/resolve', (_) {
          resolved = true;
          return FakeServer.empty();
        });
      await pumpScreen(t, s, const FraudAlertsPage());
      await _settle(t);

      await t.tap(find.widgetWithText(TextButton, 'Đã xử lý'));
      await _settle(t);

      expect(s.calls('POST', '/api/fraud-alerts/7/resolve'), hasLength(1));
      expect(s.calls('GET', '/api/fraud-alerts'), hasLength(2));
      expect(find.text('GPS giả'), findsNothing);
      expect(find.text('Đã đánh dấu đã xử lý'), findsOneWidget);
    });

    testWidgets('lọc "Đã xử lý" và "Tất cả" gọi lại API với tham số đúng; mục đã xử lý không có nút', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/fraud-alerts', (o) => FakeServer.json(o.queryParameters['resolved'] == false ? [] : [fraud(3, 'Khuôn mặt không khớp', resolved: true)]));
      await pumpScreen(t, s, const FraudAlertsPage());
      await _settle(t);

      await t.tap(find.widgetWithText(ChoiceChip, 'Đã xử lý'));
      await _settle(t);
      expect(s.calls('GET', '/api/fraud-alerts').last.queryParameters, {'resolved': true});
      expect(find.text('Khuôn mặt không khớp'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Đã xử lý'), findsNothing);

      await t.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
      await _settle(t);
      expect(s.calls('GET', '/api/fraud-alerts').last.queryParameters, isEmpty);
    });

    testWidgets('lỗi 403 hiện thông báo và Thử lại', (t) async {
      final s = FakeServer()..on('GET', '/api/fraud-alerts', (_) => FakeServer.json({}, 403));
      await pumpScreen(t, s, const FraudAlertsPage(), role: UserRole.employee);
      await _settle(t);
      expect(find.text('Bạn không có quyền thực hiện thao tác này.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('Bản đồ chấm công', () {
    FakeServer serverWith(List<Map<String, dynamic>> items, {int? total}) => FakeServer()
      ..on('GET', '/api/locations', (_) => FakeServer.json(page([location(1, 'Văn phòng chính')])))
      ..on('GET', '/api/attendance', (_) => FakeServer.json({'total': total ?? items.length, 'items': items}));

    testWidgets('tải địa điểm và chấm công, hiện số lượt và các điểm trên bản đồ', (t) async {
      final s = serverWith([attendance(1, 'Trần Thị B'), attendance(2, 'Lê Văn C', type: 'CheckOut', lat: 10.8021, lng: 106.7146)]);
      await pumpScreen(t, s, const AttendanceMapPage());
      await _settle(t);

      expect(find.text('2 lượt chấm công'), findsOneWidget);
      expect(find.byKey(const Key('att-1')), findsOneWidget);
      expect(find.byKey(const Key('att-2')), findsOneWidget);
      expect(find.text('Văn phòng chính'), findsOneWidget);
      final q = s.calls('GET', '/api/attendance').single.queryParameters;
      expect(q['pageSize'], 200);
      expect(DateTime.parse(q['from'] as String).isUtc, isTrue);
    });

    testWidgets('chạm vào điểm chấm công mở chi tiết (người, loại, trạng thái)', (t) async {
      final s = serverWith([attendance(1, 'Trần Thị B', late: true)]);
      await pumpScreen(t, s, const AttendanceMapPage());
      await _settle(t);

      await t.tap(find.byKey(const Key('att-1')));
      await _settle(t);
      expect(find.text('Trần Thị B'), findsOneWidget);
      expect(find.textContaining('Vào ca'), findsOneWidget);
      expect(find.text('Đi trễ'), findsOneWidget);
      expect(find.textContaining('12 m'), findsOneWidget);
    });

    testWidgets('chưa có chấm công thì báo trống nhưng vẫn vẽ địa điểm', (t) async {
      final s = serverWith([]);
      await pumpScreen(t, s, const AttendanceMapPage());
      await _settle(t);
      expect(find.text('Chưa có lượt chấm công trong khoảng này'), findsOneWidget);
      expect(find.text('Văn phòng chính'), findsOneWidget);
    });

    testWidgets('nhiều hơn 200 lượt thì nói rõ chỉ hiển thị phần mới nhất', (t) async {
      final s = serverWith([attendance(1, 'A'), attendance(2, 'B')], total: 250);
      await pumpScreen(t, s, const AttendanceMapPage());
      await _settle(t);
      expect(find.text('Hiển thị 2/250 lượt gần nhất'), findsOneWidget);
    });

    testWidgets('đổi sang "7 ngày" tải lại với mốc thời gian sớm hơn', (t) async {
      final s = serverWith([attendance(1, 'A')]);
      await pumpScreen(t, s, const AttendanceMapPage());
      await _settle(t);
      await t.tap(find.widgetWithText(ChoiceChip, '7 ngày'));
      await _settle(t);

      final calls = s.calls('GET', '/api/attendance').toList();
      expect(calls, hasLength(2));
      final today = DateTime.parse(calls[0].queryParameters['from'] as String);
      final week = DateTime.parse(calls[1].queryParameters['from'] as String);
      expect(today.difference(week).inDays, 6);
    });

    testWidgets('lỗi tải dữ liệu hiện Thử lại', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/locations', (_) => FakeServer.json(page([])))
        ..on('GET', '/api/attendance', (_) => FakeServer.json({'message': 'Máy chủ lỗi'}, 500));
      await pumpScreen(t, s, const AttendanceMapPage());
      await _settle(t);
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('Dịch lỗi GPS', () {
    test('chỉ tắt GPS và từ chối vĩnh viễn mới cần mở Cài đặt, nhãn nút khác nhau', () {
      const off = LocationException(LocationProblem.serviceOff);
      const forever = LocationException(LocationProblem.deniedForever);
      expect(off.needsSettings, isTrue);
      expect(off.settingsLabel, 'Mở cài đặt vị trí');
      expect(forever.needsSettings, isTrue);
      expect(forever.settingsLabel, 'Mở cài đặt ứng dụng');
      for (final p in [LocationProblem.denied, LocationProblem.timeout, LocationProblem.unavailable]) {
        expect(LocationException(p).needsSettings, isFalse, reason: '$p');
      }
      for (final p in LocationProblem.values) {
        expect(LocationException(p).message, isNotEmpty);
      }
    });

    test('AttendanceRecord.isOnTime: vào thì xét đi trễ, ra thì xét về sớm', () {
      AttendanceRecord r(String type, {bool late = false, bool early = false}) => AttendanceRecord.fromJson(attendance(1, 'A', type: type, late: late, early: early));
      expect(r('CheckIn').isOnTime, isTrue);
      expect(r('CheckIn', late: true).isOnTime, isFalse);
      expect(r('CheckOut', late: true).isOnTime, isTrue); // cờ đi trễ không ảnh hưởng lượt ra
      expect(r('CheckOut', early: true).isOnTime, isFalse);
      expect(r('CheckOut').type, AttendanceType.checkOut);
    });
  });
}
