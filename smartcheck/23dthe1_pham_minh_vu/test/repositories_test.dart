import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/data/models/leave.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/data/models/shift.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/department_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/employee_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/leave_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/location_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/shift_repository.dart';

import 'support/fake_server.dart';

void main() {
  test('EmployeeRepository.list gửi q/departmentId/page và đọc dữ liệu', () async {
    final s = FakeServer()
      ..on('GET', '/api/employees', (_) => FakeServer.json(page([employee('1', 'An Nguyen', code: 'NV1', deptId: 2, deptName: 'Kỹ thuật')], total: 41, pageSize: 20)));
    final r = await EmployeeRepository(clientFor(s)).list(q: '  an ', departmentId: 2, page: 3, pageSize: 20);

    expect(s.requests.single.queryParameters, {'q': 'an', 'departmentId': 2, 'page': 3, 'pageSize': 20});
    expect(r.total, 41);
    expect(r.hasMore, isTrue);
    expect(r.items.single.departmentName, 'Kỹ thuật');
    expect(r.items.single.role, isNull); // danh sách không trả role
  });

  test('EmployeeRepository.list bỏ q rỗng và departmentId null', () async {
    final s = FakeServer()..on('GET', '/api/employees', (_) => FakeServer.json(page([])));
    await EmployeeRepository(clientFor(s)).list(q: '   ');
    expect(s.requests.single.queryParameters.containsKey('q'), isFalse);
    expect(s.requests.single.queryParameters.containsKey('departmentId'), isFalse);
  });

  test('EmployeeRepository.get đọc role, update role=null giữ nguyên role', () async {
    final s = FakeServer()
      ..on('GET', '/api/employees/9', (_) => FakeServer.json(employee('9', 'Bình', role: 'Manager')))
      ..on('PUT', '/api/employees/9', (_) => FakeServer.empty());
    final repo = EmployeeRepository(clientFor(s));
    expect((await repo.get('9')).role, UserRole.manager);

    await repo.update('9', fullName: 'Bình', isActive: false);
    expect(s.calls('PUT', '/api/employees/9').single.data, {'fullName': 'Bình', 'employeeCode': null, 'departmentId': null, 'role': null, 'isActive': false});
  });

  test('EmployeeRepository.create gửi role dạng chuỗi', () async {
    final s = FakeServer()..on('POST', '/api/employees', (_) => FakeServer.json({'id': 'x'}, 201));
    await EmployeeRepository(clientFor(s)).create(email: 'a@b.co', password: 'abc123', fullName: 'A', role: UserRole.manager, departmentId: 2);
    expect(s.requests.single.data, {'email': 'a@b.co', 'password': 'abc123', 'fullName': 'A', 'employeeCode': null, 'departmentId': 2, 'role': 'Manager'});
  });

  test('ShiftRepository: giờ gửi dạng HH:mm:ss, đọc "08:00:00"', () async {
    final s = FakeServer()
      ..on('POST', '/api/shifts', (_) => FakeServer.json(shift(5, 'Ca sáng', '07:30:00', '16:30:00', 5), 201))
      ..on('GET', '/api/shifts', (_) => FakeServer.json(page([shift(1, 'Hành chính')])));
    final repo = ShiftRepository(clientFor(s));
    final created = await repo.create(
        name: 'Ca sáng', start: Shift.formatApi(const TimeOfDay(hour: 7, minute: 30)), end: Shift.formatApi(const TimeOfDay(hour: 16, minute: 30)), lateToleranceMinutes: 5);
    expect(s.calls('POST', '/api/shifts').single.data, {'name': 'Ca sáng', 'startTime': '07:30:00', 'endTime': '16:30:00', 'lateToleranceMinutes': 5});
    expect(created.range, '07:30 – 16:30');
    expect((await repo.list()).items.single.start, const TimeOfDay(hour: 8, minute: 0));
  });

  test('LocationRepository gửi đủ trường', () async {
    final s = FakeServer()..on('POST', '/api/locations', (_) => FakeServer.json(location(3, 'VP'), 201));
    await LocationRepository(clientFor(s)).create(name: 'VP', latitude: 10.5, longitude: 106.5, radiusMeters: 120, shiftId: 1);
    expect(s.requests.single.data, {'name': 'VP', 'address': null, 'latitude': 10.5, 'longitude': 106.5, 'radiusMeters': 120, 'shiftId': 1});
  });

  test('DepartmentRepository tạo/sửa/xoá', () async {
    final s = FakeServer()
      ..on('POST', '/api/departments', (_) => FakeServer.json(dept(7, 'Kế toán', 'x'), 201))
      ..on('PUT', '/api/departments/7', (_) => FakeServer.json(dept(7, 'Kế toán 2')))
      ..on('DELETE', '/api/departments/7', (_) => FakeServer.empty());
    final repo = DepartmentRepository(clientFor(s));
    expect((await repo.create(name: 'Kế toán', description: 'x')).id, 7);
    await repo.update(7, name: 'Kế toán 2');
    await repo.delete(7);
    expect(s.calls('PUT', '/api/departments/7').single.data, {'name': 'Kế toán 2', 'description': null});
    expect(s.calls('DELETE', '/api/departments/7'), hasLength(1));
  });

  test('LeaveRepository: lọc status, ngày dạng yyyy-MM-dd, duyệt đơn', () async {
    final s = FakeServer()
      ..on('GET', '/api/leaves', (_) => FakeServer.json([leave(1, 'An', 'Pending')]))
      ..on('POST', '/api/leaves', (_) => FakeServer.json({'id': 2}, 201))
      ..on('POST', '/api/leaves/1/review', (_) => FakeServer.empty());
    final repo = LeaveRepository(clientFor(s));

    final list = await repo.list(status: LeaveStatus.pending);
    expect(s.calls('GET', '/api/leaves').single.queryParameters, {'status': 'Pending'});
    expect(list.single.status, LeaveStatus.pending);
    expect(list.single.fromDate, DateTime(2026, 11, 2));

    await repo.create(from: DateTime(2026, 11, 5), to: DateTime(2026, 11, 7), reason: 'Nghỉ');
    expect(s.calls('POST', '/api/leaves').single.data, {'fromDate': '2026-11-05', 'toDate': '2026-11-07', 'reason': 'Nghỉ'});

    await repo.review(1, approve: false);
    expect(s.calls('POST', '/api/leaves/1/review').single.data, {'approve': false});
  });

  test('Leave.formatApiDate đệm số 0', () {
    expect(Leave.formatApiDate(DateTime(2026, 1, 3)), '2026-01-03');
  });

  test('LeaveStatus.parse: lạ thì coi là Pending', () {
    expect(LeaveStatus.parse('Approved'), LeaveStatus.approved);
    expect(LeaveStatus.parse('Rejected'), LeaveStatus.rejected);
    expect(LeaveStatus.parse('???'), LeaveStatus.pending);
  });
}
