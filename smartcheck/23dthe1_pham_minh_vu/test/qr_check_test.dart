import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/data/models/attendance.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/features/manager_qr/qr_display_page.dart';
import 'package:pham_minh_vu_23dthe1/features/scan/check_page.dart';
import 'package:pham_minh_vu_23dthe1/services/location_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/fake_server.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

/// Gỡ màn hình để huỷ timer trước khi test kết thúc.
Future<void> _leave(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump();
}

String _qrData(WidgetTester t) => (t.widget<QrImageView>(find.byType(QrImageView)).key! as ValueKey<String>).value;

Future<bool> _faceOk(BuildContext _) async => true;

Map<String, dynamic> _qr(String token, {int ttl = 45}) => {'token': token, 'ttlSeconds': ttl, 'location': 'Cơ sở 1'};

void main() {
  group('Điểm chấm công (QR động)', () {
    testWidgets('chưa có địa điểm thì hướng dẫn tạo', (t) async {
      final s = FakeServer()..on('GET', '/api/locations', (_) => FakeServer.json(page([])));
      await pumpScreen(t, s, const QrDisplayPage(), role: UserRole.manager);
      await _settle(t);
      expect(find.text('Chưa có địa điểm'), findsOneWidget);
    });

    testWidgets('lỗi tải địa điểm hiện Thử lại', (t) async {
      final s = FakeServer()..on('GET', '/api/locations', (_) => FakeServer.json({'message': 'Máy chủ lỗi'}, 500));
      await pumpScreen(t, s, const QrDisplayPage());
      await _settle(t);
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('một địa điểm: tự hiện QR đúng token, gọi API với locationId', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/locations', (_) => FakeServer.json(page([location(7, 'Cơ sở 1')])))
        ..on('GET', '/api/qr/current', (_) => FakeServer.json(_qr('SC1.7.111.aaa')));
      await pumpScreen(t, s, const QrDisplayPage());
      await _settle(t);

      expect(_qrData(t), 'SC1.7.111.aaa');
      expect(s.calls('GET', '/api/qr/current').single.queryParameters, {'locationId': 7});
      expect(find.text('Đổi mã sau 30s'), findsOneWidget);
      await _leave(t);
    });

    testWidgets('nhiều địa điểm: chọn rồi mới hiện QR', (t) async {
      final s = FakeServer()
        ..on('GET', '/api/locations', (_) => FakeServer.json(page([location(1, 'Cơ sở 1'), location(2, 'Cơ sở 2')])))
        ..on('GET', '/api/qr/current', (o) => FakeServer.json(_qr('SC1.${o.queryParameters['locationId']}.1.x')));
      await pumpScreen(t, s, const QrDisplayPage());
      await _settle(t);
      expect(find.byType(QrImageView), findsNothing);

      await t.tap(find.text('Cơ sở 2'));
      await _settle(t);
      expect(_qrData(t), 'SC1.2.1.x');
      await _leave(t);
    });

    testWidgets('đếm ngược theo giây và tự lấy mã mới sau 30 giây', (t) async {
      var n = 0;
      final s = FakeServer()
        ..on('GET', '/api/locations', (_) => FakeServer.json(page([location(1, 'Cơ sở 1')])))
        ..on('GET', '/api/qr/current', (_) => FakeServer.json(_qr('SC1.1.${++n}.sig')));
      await pumpScreen(t, s, const QrDisplayPage());
      await _settle(t);
      expect(_qrData(t), 'SC1.1.1.sig');

      await t.pump(const Duration(seconds: 10));
      expect(find.text('Đổi mã sau 20s'), findsOneWidget);
      expect(s.calls('GET', '/api/qr/current'), hasLength(1));

      await t.pump(const Duration(seconds: 20));
      await t.pump();
      expect(s.calls('GET', '/api/qr/current'), hasLength(2));
      expect(_qrData(t), 'SC1.1.2.sig');
      expect(find.text('Đổi mã sau 30s'), findsOneWidget);
      await _leave(t);
    });

    testWidgets('lấy mã mới lỗi: giữ mã cũ, báo lỗi; quá hạn thì báo hết hạn và có nút lấy mã mới', (t) async {
      var fail = false;
      final s = FakeServer()
        ..on('GET', '/api/locations', (_) => FakeServer.json(page([location(1, 'Cơ sở 1')])))
        ..on('GET', '/api/qr/current', (_) => fail ? FakeServer.json({'message': 'Máy chủ lỗi'}, 500) : FakeServer.json(_qr('SC1.1.1.sig')));
      await pumpScreen(t, s, const QrDisplayPage());
      await _settle(t);

      fail = true;
      await t.pump(const Duration(seconds: 30));
      await t.pump();
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
      expect(_qrData(t), 'SC1.1.1.sig'); // mã 30s tuổi vẫn còn hạn (45s)
      expect(find.text('Mã đã hết hạn'), findsNothing);

      await t.pump(const Duration(seconds: 15));
      expect(find.text('Mã đã hết hạn'), findsOneWidget);

      fail = false;
      await t.tap(find.text('Lấy mã mới'));
      await _settle(t);
      expect(find.text('Mã đã hết hạn'), findsNothing);
      expect(find.text('Máy chủ lỗi'), findsNothing);
      await _leave(t);
    });
  });

  group('Chấm công (nhân viên quét QR)', () {
    FakeServer server() => FakeServer();

    Map<String, dynamic> ok({String type = 'CheckIn', bool late = false, bool early = false, List<String> flags = const []}) => {
          'id': 5,
          'type': type,
          'timeLocal': '2026-10-29T08:05:00+07:00',
          'isLate': late,
          'isEarlyLeave': early,
          'distance': 12.0,
          'flags': flags,
        };

    Future<void> scan(WidgetTester t) async {
      await t.tap(find.textContaining('Quét mã QR'));
      await _settle(t);
    }

    testWidgets('mở màn hình thì đọc GPS và hiện toạ độ, sai số', (t) async {
      final gpsFake = FakeLocation(reading: gps(lat: 10.80191, lng: 106.71442, accuracy: 7.6));
      await pumpScreen(t, server(), CheckPage(scan: (_) async => null, verifyFace: _faceOk), location: gpsFake);
      await _settle(t);
      expect(gpsFake.reads, 1);
      expect(find.text('10.80191, 106.71442'), findsOneWidget);
      expect(find.text('Sai số khoảng 8 m'), findsOneWidget);
    });

    testWidgets('không lấy được GPS: báo lỗi, không mở camera, Thử lại thì chạy tiếp', (t) async {
      var scans = 0;
      final gpsFake = FakeLocation(error: const LocationException(LocationProblem.timeout));
      await pumpScreen(t, server(), CheckPage(scan: (_) async {
        scans++;
        return null;
      }, verifyFace: _faceOk), location: gpsFake);
      await _settle(t);
      expect(find.byKey(const Key('location-problem')), findsOneWidget);
      expect(find.textContaining('Chưa lấy được vị trí'), findsOneWidget);

      await scan(t); // vẫn lỗi → không được mở camera
      expect(scans, 0);

      gpsFake.error = null;
      await t.tap(find.text('Thử lại'));
      await _settle(t);
      expect(find.byKey(const Key('location-problem')), findsNothing);
      await scan(t);
      expect(scans, 1);
    });

    testWidgets('GPS tắt: có nút mở cài đặt vị trí', (t) async {
      final gpsFake = FakeLocation(error: const LocationException(LocationProblem.serviceOff));
      await pumpScreen(t, server(), CheckPage(scan: (_) async => null, verifyFace: _faceOk), location: gpsFake);
      await _settle(t);
      await t.tap(find.text('Mở cài đặt vị trí'));
      await t.pump();
      expect(gpsFake.openedSettingsFor, LocationProblem.serviceOff);
    });

    testWidgets('từ chối quyền vĩnh viễn: có nút mở cài đặt ứng dụng', (t) async {
      final gpsFake = FakeLocation(error: const LocationException(LocationProblem.deniedForever));
      await pumpScreen(t, server(), CheckPage(scan: (_) async => null, verifyFace: _faceOk), location: gpsFake);
      await _settle(t);
      await t.tap(find.text('Mở cài đặt ứng dụng'));
      await t.pump();
      expect(gpsFake.openedSettingsFor, LocationProblem.deniedForever);
    });

    testWidgets('từ chối quyền thường: chỉ có Thử lại, không có nút Cài đặt', (t) async {
      final gpsFake = FakeLocation(error: const LocationException(LocationProblem.denied));
      await pumpScreen(t, server(), CheckPage(scan: (_) async => null, verifyFace: _faceOk), location: gpsFake);
      await _settle(t);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('Mở cài đặt'), findsNothing);
    });

    testWidgets('GPS yếu (> 100 m) được báo trước', (t) async {
      await pumpScreen(t, server(), CheckPage(scan: (_) async => null, verifyFace: _faceOk), location: FakeLocation(reading: gps(accuracy: 180)));
      await _settle(t);
      expect(find.textContaining('GPS đang yếu'), findsOneWidget);
    });

    testWidgets('vào ca thành công: gửi nguyên chuỗi QR, toạ độ/sai số/isMocked từ GPS và deviceId', (t) async {
      final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json(ok()));
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.999.sig', verifyFace: _faceOk), location: FakeLocation(reading: gps(lat: 10.81, lng: 106.72, accuracy: 12.5)));
      await _settle(t);
      await scan(t);

      final body = bodyOf(s.calls('POST', '/api/attendance/check-in').single) as Map;
      expect(body, {
        'qrToken': 'SC1.1.999.sig',
        'latitude': 10.81,
        'longitude': 106.72,
        'accuracy': 12.5,
        'isMocked': false,
        'deviceId': 'test-device',
        'faceVerified': true,
      });
      expect(find.byKey(const Key('check-success')), findsOneWidget);
      expect(find.text('Chấm công vào ca thành công'), findsOneWidget);
      expect(find.textContaining('12 m'), findsOneWidget);
      expect(find.text('Đúng giờ'), findsOneWidget);
    });

    testWidgets('vị trí còn mới thì không đọc lại trước khi quét', (t) async {
      final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json(ok()));
      final fresh = FakeLocation();
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk), location: fresh);
      await _settle(t);
      await scan(t);
      expect(fresh.reads, 1);
    });

    testWidgets('vị trí cũ hơn 30 giây thì đọc lại trước khi quét', (t) async {
      final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json(ok()));
      final stale = FakeLocation(reading: gps(at: DateTime.now().subtract(const Duration(minutes: 2))));
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk), location: stale);
      await _settle(t);
      await scan(t);
      expect(stale.reads, 2);
    });

    testWidgets('GPS giả lập: vẫn gửi isMocked=true để server chặn và ghi cảnh báo, kết quả hiện lý do', (t) async {
      final s = server()
        ..on('POST', '/api/attendance/check-in', (_) => FakeServer.json({
              'code': 'FRAUD_SUSPECTED',
              'message': 'Chấm công bị từ chối',
              'reasons': ['Thiết bị báo vị trí giả lập (mock location)']
            }, 403));
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk), location: FakeLocation(reading: gps(mocked: true)));
      await _settle(t);
      expect(find.byKey(const Key('location-mocked')), findsOneWidget);
      await scan(t);

      expect((bodyOf(s.calls('POST', '/api/attendance/check-in').single) as Map)['isMocked'], true);
      expect(find.text('Nghi ngờ gian lận'), findsOneWidget);
      expect(find.textContaining('mock location'), findsOneWidget);
    });

    testWidgets('ra ca gọi /check-out và hiện "Về sớm"', (t) async {
      final s = server()..on('POST', '/api/attendance/check-out', (_) => FakeServer.json(ok(type: 'CheckOut', early: true)));
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk));
      await _settle(t);
      await t.tap(find.text('Ra ca'));
      await t.pump();
      await scan(t);

      expect(s.calls('POST', '/api/attendance/check-out'), hasLength(1));
      expect(s.calls('POST', '/api/attendance/check-in'), isEmpty);
      expect(find.text('Chấm công ra ca thành công'), findsOneWidget);
      expect(find.text('Về sớm'), findsOneWidget);
    });

    testWidgets('khuôn mặt: xác thực trước khi quét QR; không vượt qua thì không quét và không gửi gì', (t) async {
      final order = <String>[];
      final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json(ok()));
      await pumpScreen(t, s, CheckPage(
        verifyFace: (_) async {
          order.add('face');
          return false;
        },
        scan: (_) async {
          order.add('scan');
          return 'SC1.1.1.x';
        },
      ));
      await _settle(t);
      await scan(t);
      expect(order, ['face']);
      expect(s.calls('POST', '/api/attendance/check-in'), isEmpty);
      expect(find.byKey(const Key('check-success')), findsNothing);
    });

    testWidgets('khuôn mặt vượt qua: thứ tự khuôn mặt rồi QR, gửi faceVerified=true', (t) async {
      final order = <String>[];
      final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json(ok()));
      await pumpScreen(t, s, CheckPage(
        verifyFace: (_) async {
          order.add('face');
          return true;
        },
        scan: (_) async {
          order.add('scan');
          return 'SC1.1.1.x';
        },
      ));
      await _settle(t);
      await scan(t);
      expect(order, ['face', 'scan']);
      expect((bodyOf(s.calls('POST', '/api/attendance/check-in').single) as Map)['faceVerified'], true);
    });

    testWidgets('server báo FACE_REQUIRED / FACE_MISMATCH vẫn hiện đúng thông báo sau khi qua bước khuôn mặt', (t) async {
      final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json({'code': 'FACE_MISMATCH', 'message': 'Khuôn mặt không khớp'}, 403));
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk));
      await _settle(t);
      await scan(t);
      expect(find.text('Khuôn mặt không khớp'), findsOneWidget);
    });

    testWidgets('vào ca trễ và có cờ cảnh báo thì hiện đủ', (t) async {
      final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json(ok(late: true, flags: ['Trùng toạ độ y hệt với nhân viên khác'])));
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk));
      await _settle(t);
      await scan(t);
      expect(find.text('Đi trễ'), findsOneWidget);
      expect(find.text('Trùng toạ độ y hệt với nhân viên khác'), findsOneWidget);
    });

    testWidgets('đóng màn quét (không đọc được mã) thì không gửi gì', (t) async {
      final s = server();
      await pumpScreen(t, s, CheckPage(scan: (_) async => null, verifyFace: _faceOk));
      await _settle(t);
      await scan(t);
      expect(s.calls('POST', '/api/attendance/check-in'), isEmpty);
      expect(find.byKey(const Key('check-success')), findsNothing);
      expect(find.byKey(const Key('check-failure')), findsNothing);
    });

    final cases = <String, (int, Map<String, dynamic>, List<String>)>{
      'Mã QR không dùng được': (400, {'code': 'QR_INVALID', 'message': 'QR đã hết hạn, hãy quét lại'}, ['quét lại mã đang hiển thị']),
      'Ngoài phạm vi chấm công': (400, {'code': 'OUT_OF_RANGE', 'message': 'Bạn cách điểm chấm công 500 m (cho phép 150 m)'}, ['500 m']),
      'Nghi ngờ gian lận': (403, {'code': 'FRAUD_SUSPECTED', 'message': 'Chấm công bị từ chối', 'reasons': ['Chấm công từ thiết bị chưa đăng ký']}, ['thiết bị chưa đăng ký']),
      'Bạn đã chấm công rồi': (409, {'code': 'ALREADY_DONE', 'message': 'Hôm nay bạn đã chấm công vào'}, ['Hôm nay bạn đã chấm công vào']),
      'Chưa chấm công vào': (409, {'code': 'NO_CHECKIN', 'message': 'Chưa chấm công vào'}, ['trước khi ra ca']),
      'Khuôn mặt không khớp': (403, {'code': 'FACE_MISMATCH', 'message': 'Khuôn mặt không khớp'}, ['không trùng với khuôn mặt đã đăng ký']),
      'Cần xác thực khuôn mặt': (400, {'code': 'FACE_REQUIRED', 'message': 'Cần xác thực khuôn mặt'}, ['đã đăng ký khuôn mặt']),
    };
    for (final e in cases.entries) {
      testWidgets('lỗi ${e.value.$2['code']} hiện "${e.key}"', (t) async {
        final (status, body, expectTexts) = e.value;
        final s = server()..on('POST', '/api/attendance/check-in', (_) => FakeServer.json(body, status));
        await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk));
        await _settle(t);
        await scan(t);
        expect(find.byKey(const Key('check-failure')), findsOneWidget);
        expect(find.text(e.key), findsOneWidget);
        for (final x in expectTexts) {
          expect(find.textContaining(x), findsWidgets);
        }
        expect(find.byKey(const Key('check-success')), findsNothing);
      });
    }

    testWidgets('lỗi quét được thì cho quét lại: kết quả cũ bị xoá khi quét lần mới', (t) async {
      var fail = true;
      final s = server()
        ..on('POST', '/api/attendance/check-in', (_) => fail ? FakeServer.json({'code': 'QR_INVALID', 'message': 'QR đã hết hạn, hãy quét lại'}, 400) : FakeServer.json(ok()));
      await pumpScreen(t, s, CheckPage(scan: (_) async => 'SC1.1.1.x', verifyFace: _faceOk));
      await _settle(t);
      await scan(t);
      expect(find.byKey(const Key('check-failure')), findsOneWidget);

      fail = false;
      await scan(t);
      expect(find.byKey(const Key('check-failure')), findsNothing);
      expect(find.byKey(const Key('check-success')), findsOneWidget);
    });
  });

  test('AttendanceType.parse hiểu chuỗi enum của server', () {
    expect(AttendanceType.parse('CheckOut'), AttendanceType.checkOut);
    expect(AttendanceType.parse('CheckIn'), AttendanceType.checkIn);
  });
}
