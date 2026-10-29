import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/data/models/shift.dart';
import 'package:pham_minh_vu_23dthe1/data/models/work_location.dart';
import 'package:pham_minh_vu_23dthe1/features/admin/locations_page.dart';

import 'support/fake_server.dart';

final _shifts = [
  Shift.fromJson(shift(1, 'Hành chính')),
  Shift.fromJson(shift(2, 'Ca chiều', '13:00:00', '21:00:00')),
];

/// Màn hình giả đủ cao để ListView dựng hết các ô (form có bản đồ 300 px ở giữa).
void _tallScreen(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 4200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('toạ độ sai bị chặn, nhập đúng thì gửi body đầy đủ (kèm ca đã chọn)', (t) async {
    _tallScreen(t);
    final s = FakeServer()..on('POST', '/api/locations', (_) => FakeServer.json(location(9, 'Chi nhánh'), 201));
    await pumpScreen(t, s, LocationFormPage(shifts: _shifts));
    await t.pump();
    expect(find.byType(FlutterMap), findsOneWidget);

    await t.enterText(find.widgetWithText(TextFormField, 'Tên địa điểm'), 'Chi nhánh');
    await t.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '123');
    await t.enterText(find.widgetWithText(TextFormField, 'Kinh độ'), 'abc');
    await t.ensureVisible(find.text('Lưu địa điểm'));
    await t.tap(find.text('Lưu địa điểm'));
    await t.pump();
    expect(find.text('vĩ độ trong khoảng ±90'), findsOneWidget);
    expect(find.text('Nhập kinh độ'), findsOneWidget);
    expect(s.calls('POST', '/api/locations'), isEmpty);

    await t.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '10,7769'); // chấp nhận dấu phẩy
    await t.enterText(find.widgetWithText(TextFormField, 'Kinh độ'), '106.7009');
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Ca chiều').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Lưu địa điểm'));
    await t.tap(find.text('Lưu địa điểm'));
    await t.pumpAndSettle();

    expect(s.calls('POST', '/api/locations').single.data, {
      'name': 'Chi nhánh',
      'address': null,
      'latitude': 10.7769,
      'longitude': 106.7009,
      'radiusMeters': 100,
      'shiftId': 2,
    });
  });

  testWidgets('sửa địa điểm: nạp sẵn dữ liệu cũ và gọi PUT', (t) async {
    _tallScreen(t);
    final s = FakeServer()..on('PUT', '/api/locations/5', (_) => FakeServer.json(location(5, 'VP mới')));
    final existing = WorkLocation.fromJson(location(5, 'Văn phòng chính'));
    await pumpScreen(t, s, LocationFormPage(existing: existing, shifts: _shifts));
    await t.pump();
    expect(find.text('Văn phòng chính'), findsOneWidget);
    expect(find.text('150 m'), findsWidgets);

    await t.enterText(find.widgetWithText(TextFormField, 'Tên địa điểm'), 'VP mới');
    await t.ensureVisible(find.text('Lưu địa điểm'));
    await t.tap(find.text('Lưu địa điểm'));
    await t.pumpAndSettle();
    final body = s.calls('PUT', '/api/locations/5').single.data as Map;
    expect(body['name'], 'VP mới');
    expect(body['radiusMeters'], 150);
    expect(body['shiftId'], 1);
  });
}
