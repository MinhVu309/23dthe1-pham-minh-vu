import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/clock.dart';
import 'package:pham_minh_vu_23dthe1/data/models/attendance.dart';
import 'package:pham_minh_vu_23dthe1/data/models/attendance_report.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/features/reports/attendance_history_page.dart';
import 'package:pham_minh_vu_23dthe1/features/reports/report_format.dart';
import 'package:pham_minh_vu_23dthe1/features/reports/timesheet_page.dart';

import 'support/fake_server.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
}

/// Giờ cố định để test chuyển tháng không phụ thuộc ngày chạy test.
void _fixNow(DateTime now) {
  nowProvider = () => now;
  addTearDown(() => nowProvider = DateTime.now);
}

/// `/my` dùng giờ UTC; dựng từ giờ máy để test không phụ thuộc múi giờ của máy chạy test.
Map<String, dynamic> mine(int id, DateTime local, {String type = 'CheckIn', bool late = false, bool early = false, String place = 'Văn phòng chính'}) => {
      'id': id,
      'type': type,
      'timestamp': local.toUtc().toIso8601String(),
      'isLate': late,
      'isEarlyLeave': early,
      'distanceMeters': 12.0,
      'location': place,
    };

Map<String, dynamic> report(int y, int m, List<Map<String, dynamic>> rows) => {'year': y, 'month': m, 'rows': rows};
Map<String, dynamic> row(String name, int days, int late, int early) => {'userId': 'u-$name', 'name': name, 'daysWorked': days, 'lateCount': late, 'earlyLeaveCount': early};

MyAttendance _a(DateTime t, AttendanceType type) => MyAttendance(id: t.millisecondsSinceEpoch, type: type, time: t, isLate: false, isEarlyLeave: false, distance: 0, location: 'x');

void main() {
  group('groupByDay / MonthlyReport (thuần Dart)', () {
    test('gom theo ngày giờ máy, ngày mới nhất trước; lấy vào sớm nhất và ra muộn nhất', () {
      final logs = groupByDay([
        _a(DateTime(2026, 10, 28, 8, 3), AttendanceType.checkIn),
        _a(DateTime(2026, 10, 28, 17, 5), AttendanceType.checkOut),
        _a(DateTime(2026, 10, 29, 8, 20), AttendanceType.checkIn),
        _a(DateTime(2026, 10, 29, 8, 5), AttendanceType.checkIn), // trùng: lấy lần sớm hơn
        _a(DateTime(2026, 10, 29, 12, 0), AttendanceType.checkOut),
        _a(DateTime(2026, 10, 29, 17, 30), AttendanceType.checkOut), // lấy lần muộn hơn
      ]);
      expect(logs.map((l) => l.day), [DateTime(2026, 10, 29), DateTime(2026, 10, 28)]);
      expect(logs[0].checkIn!.time, DateTime(2026, 10, 29, 8, 5));
      expect(logs[0].checkOut!.time, DateTime(2026, 10, 29, 17, 30));
    });

    test('ngày chỉ có lượt vào thì chưa có lượt ra; danh sách rỗng cho kết quả rỗng', () {
      final logs = groupByDay([_a(DateTime(2026, 10, 29, 8, 0), AttendanceType.checkIn)]);
      expect(logs.single.checkOut, isNull);
      expect(groupByDay(const []), isEmpty);
    });

    test('MonthlyReport cộng tổng và sắp xếp tên không phân biệt hoa thường', () {
      final r = MonthlyReport.fromJson(report(2026, 10, [row('lan', 10, 2, 0), row('An', 5, 0, 1), row('Binh', 20, 1, 1)]));
      expect(r.rows.map((e) => e.name), ['An', 'Binh', 'lan']);
      expect((r.totalDays, r.totalLate, r.totalEarly), (35, 3, 2));
    });

    test('định dạng thứ trong tuần không phụ thuộc locale', () {
      expect(formatDayWithWeekday(DateTime(2026, 10, 29)), 'Thứ năm, 29/10/2026');
      expect(formatDayWithWeekday(DateTime(2026, 11, 1)), 'Chủ nhật, 01/11/2026');
    });
  });

  group('Lịch sử chấm công (nhân viên)', () {
    testWidgets('gọi /my với 30 ngày, hiện từng ngày với giờ vào/ra và trạng thái', (t) async {
      final d1 = DateTime(2026, 10, 29, 8, 25), d1out = DateTime(2026, 10, 29, 16, 40), d2 = DateTime(2026, 10, 28, 8, 0);
      final s = FakeServer()
        ..on('GET', '/api/attendance/my', (_) => FakeServer.json([
              mine(1, d1, late: true),
              mine(2, d1out, type: 'CheckOut', early: true),
              mine(3, d2),
            ]));
      await pumpScreen(t, s, const AttendanceHistoryPage(), role: UserRole.employee);
      await _settle(t);

      expect(s.calls('GET', '/api/attendance/my').single.queryParameters, {'days': 30});
      expect(find.text('Thứ năm, 29/10/2026'), findsOneWidget);
      expect(find.text('Thứ tư, 28/10/2026'), findsOneWidget);
      expect(find.text(formatTime(d1)), findsOneWidget);
      expect(find.text(formatTime(d1out)), findsOneWidget);
      expect(find.text('Đi trễ'), findsOneWidget);
      expect(find.text('Về sớm'), findsOneWidget);
      expect(find.text('Chưa chấm công'), findsOneWidget); // ngày 28 chưa có lượt ra
    });

    testWidgets('đổi bộ lọc sang 7 ngày gọi lại với days=7', (t) async {
      final s = FakeServer()..on('GET', '/api/attendance/my', (_) => FakeServer.json([]));
      await pumpScreen(t, s, const AttendanceHistoryPage(), role: UserRole.employee);
      await _settle(t);
      await t.tap(find.widgetWithText(ChoiceChip, '7 ngày'));
      await _settle(t);
      expect(s.calls('GET', '/api/attendance/my').last.queryParameters, {'days': 7});
    });

    testWidgets('chưa có lượt nào thì báo trống', (t) async {
      final s = FakeServer()..on('GET', '/api/attendance/my', (_) => FakeServer.json([]));
      await pumpScreen(t, s, const AttendanceHistoryPage(), role: UserRole.employee);
      await _settle(t);
      expect(find.text('Chưa có lượt chấm công'), findsOneWidget);
    });

    testWidgets('lỗi mạng hiện thông báo; Thử lại tải được', (t) async {
      var fail = true;
      final s = FakeServer()..on('GET', '/api/attendance/my', (_) => fail ? FakeServer.json({'message': 'Máy chủ lỗi'}, 500) : FakeServer.json([mine(1, DateTime(2026, 10, 29, 8, 0))]));
      await pumpScreen(t, s, const AttendanceHistoryPage(), role: UserRole.employee);
      await _settle(t);
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Thử lại'));
      await _settle(t);
      expect(find.text('Thứ năm, 29/10/2026'), findsOneWidget);
    });

    testWidgets('tab Bảng công tháng: gọi /report tháng hiện tại không kèm userId, hiện 3 ô tổng', (t) async {
      _fixNow(DateTime(2026, 10, 29, 10));
      final s = FakeServer()
        ..on('GET', '/api/attendance/my', (_) => FakeServer.json([]))
        ..on('GET', '/api/attendance/report', (_) => FakeServer.json(report(2026, 10, [row('Tôi', 18, 3, 1)])));
      await pumpScreen(t, s, const AttendanceHistoryPage(), role: UserRole.employee);
      await _settle(t);
      await t.tap(find.text('Bảng công tháng'));
      await _settle(t);

      expect(s.calls('GET', '/api/attendance/report').single.queryParameters, {'year': 2026, 'month': 10});
      expect(find.text('Tháng 10/2026'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.textContaining('Theo nhân viên'), findsNothing); // nhân viên chỉ thấy của mình
    });

    testWidgets('chuyển tháng: lùi qua đầu năm sang tháng 12 năm trước; không tiến quá tháng hiện tại', (t) async {
      _fixNow(DateTime(2026, 1, 15));
      final s = FakeServer()
        ..on('GET', '/api/attendance/my', (_) => FakeServer.json([]))
        ..on('GET', '/api/attendance/report', (_) => FakeServer.json(report(2026, 1, [])));
      await pumpScreen(t, s, const AttendanceHistoryPage(), role: UserRole.employee);
      await _settle(t);
      await t.tap(find.text('Bảng công tháng'));
      await _settle(t);

      expect(t.widget<IconButton>(find.byKey(const Key('month-next'))).onPressed, isNull); // đang ở tháng hiện tại
      expect(find.text('Chưa có chấm công trong tháng này'), findsOneWidget);

      await t.tap(find.byKey(const Key('month-prev')));
      await _settle(t);
      expect(s.calls('GET', '/api/attendance/report').last.queryParameters, {'year': 2025, 'month': 12});
      expect(find.text('Tháng 12/2025'), findsOneWidget);
      expect(t.widget<IconButton>(find.byKey(const Key('month-next'))).onPressed, isNotNull);

      await t.tap(find.byKey(const Key('month-next')));
      await _settle(t);
      expect(find.text('Tháng 1/2026'), findsOneWidget);
    });
  });

  group('Bảng công (Admin/Manager)', () {
    final now = DateTime(2026, 10, 29, 10);

    Map<String, dynamic> rec(int id, String who, {String type = 'CheckIn', bool late = false}) => attendance(id, who, type: type, late: late);

    FakeServer serverWith(List<Map<String, dynamic>> items, {int? total}) => FakeServer()
      ..on('GET', '/api/employees', (_) => FakeServer.json(page([employee('u1', 'Trần Thị B'), employee('u2', 'Lê Văn C')])))
      ..on('GET', '/api/attendance', (_) => FakeServer.json({'total': total ?? items.length, 'items': items}))
      ..on('GET', '/api/attendance/report', (_) => FakeServer.json(report(2026, 10, [row('Trần Thị B', 12, 2, 0), row('Lê Văn C', 8, 0, 1)])));

    testWidgets('tab Theo ngày: mặc định hôm nay, gọi API với from/to của ngày và pageSize 50', (t) async {
      _fixNow(now);
      final s = serverWith([rec(1, 'Trần Thị B', late: true), rec(2, 'Lê Văn C', type: 'CheckOut')]);
      await pumpScreen(t, s, const TimesheetPage());
      await _settle(t);

      final q = s.calls('GET', '/api/attendance').single.queryParameters;
      expect(q['page'], 1);
      expect(q['pageSize'], 50);
      final from = DateTime.parse(q['from'] as String), to = DateTime.parse(q['to'] as String);
      expect(from.toLocal(), DateTime(2026, 10, 29));
      expect(to.difference(from), const Duration(days: 1) - const Duration(milliseconds: 1));
      expect(q.containsKey('userId'), isFalse);
      expect(find.text('Hôm nay, 29/10/2026'), findsOneWidget);
      expect(find.text('Trần Thị B'), findsWidgets);
      expect(find.text('Đi trễ'), findsOneWidget);
      expect(find.text('Hiển thị 2/2 lượt'), findsOneWidget);
      expect(t.widget<IconButton>(find.byKey(const Key('day-next'))).onPressed, isNull); // không xem ngày tương lai
    });

    testWidgets('ngày trước: tải lại với ngày 28 và đổi nhãn sang thứ/ngày', (t) async {
      _fixNow(now);
      final s = serverWith([]);
      await pumpScreen(t, s, const TimesheetPage());
      await _settle(t);
      await t.tap(find.byKey(const Key('day-prev')));
      await _settle(t);

      final from = DateTime.parse(s.calls('GET', '/api/attendance').last.queryParameters['from'] as String);
      expect(from.toLocal(), DateTime(2026, 10, 28));
      expect(find.text('Thứ tư, 28/10/2026'), findsOneWidget);
      expect(find.text('Không có lượt chấm công'), findsOneWidget);
      expect(t.widget<IconButton>(find.byKey(const Key('day-next'))).onPressed, isNotNull);
    });

    testWidgets('lọc theo nhân viên gửi userId', (t) async {
      _fixNow(now);
      final s = serverWith([rec(1, 'Trần Thị B')]);
      await pumpScreen(t, s, const TimesheetPage());
      await _settle(t);
      await t.tap(find.byKey(const Key('filter-employee')));
      await t.pumpAndSettle();
      await t.tap(find.text('Lê Văn C').last);
      await _settle(t);
      expect(s.calls('GET', '/api/attendance').last.queryParameters['userId'], 'u2');
    });

    testWidgets('phân trang: còn dữ liệu thì có Tải thêm và gọi trang 2, cộng dồn vào danh sách', (t) async {
      _fixNow(now);
      final s = FakeServer()
        ..on('GET', '/api/employees', (_) => FakeServer.json(page([])))
        ..on('GET', '/api/attendance', (o) => FakeServer.json({
              'total': 3,
              'items': o.queryParameters['page'] == 1 ? [rec(1, 'An'), rec(2, 'Bình')] : [rec(3, 'Chi')]
            }));
      await pumpScreen(t, s, const TimesheetPage());
      await _settle(t);
      expect(find.text('Hiển thị 2/3 lượt'), findsOneWidget);

      await t.tap(find.text('Tải thêm'));
      await _settle(t);
      expect(s.calls('GET', '/api/attendance').last.queryParameters['page'], 2);
      expect(find.text('Hiển thị 3/3 lượt'), findsOneWidget);
      expect(find.text('Tải thêm'), findsNothing);
      expect(find.text('Chi'), findsOneWidget);
    });

    testWidgets('lỗi tải hiện thông báo của server', (t) async {
      _fixNow(now);
      final s = FakeServer()
        ..on('GET', '/api/employees', (_) => FakeServer.json(page([])))
        ..on('GET', '/api/attendance', (_) => FakeServer.json({'message': 'Máy chủ lỗi'}, 500));
      await pumpScreen(t, s, const TimesheetPage());
      await _settle(t);
      expect(find.text('Máy chủ lỗi'), findsOneWidget);
    });

    testWidgets('tab Theo tháng: tổng, danh sách từng nhân viên sắp theo tên, chip trễ/sớm', (t) async {
      _fixNow(now);
      final s = serverWith([]);
      await pumpScreen(t, s, const TimesheetPage(), role: UserRole.manager);
      await _settle(t);
      await t.tap(find.text('Theo tháng'));
      await _settle(t);

      expect(s.calls('GET', '/api/attendance/report').single.queryParameters, {'year': 2026, 'month': 10});
      expect(find.text('20'), findsOneWidget); // 12 + 8 ngày công
      expect(find.text('Theo nhân viên (2)'), findsOneWidget);
      expect(find.text('12 ngày công'), findsOneWidget);
      expect(find.text('Đi trễ 2'), findsOneWidget);
      expect(find.text('Về sớm 1'), findsOneWidget);
      expect(find.text('Đi trễ 0'), findsOneWidget);
      // sắp theo tên: "Lê Văn C" đứng trước "Trần Thị B"
      expect(t.getTopLeft(find.text('Lê Văn C')).dy, lessThan(t.getTopLeft(find.text('Trần Thị B')).dy));
    });
  });
}
