import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pham_minh_vu_23dthe1/core/api_client.dart';
import 'package:pham_minh_vu_23dthe1/data/models/session.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/auth_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/attendance_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/department_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/employee_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/leave_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/location_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/qr_repository.dart';
import 'package:pham_minh_vu_23dthe1/data/repositories/shift_repository.dart';
import 'package:pham_minh_vu_23dthe1/features/auth/auth_controller.dart';
import 'package:pham_minh_vu_23dthe1/services/device_id.dart';
import 'package:pham_minh_vu_23dthe1/core/theme.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

class FixedDeviceId implements DeviceIdProvider {
  @override
  Future<String> get() async => 'test-device';
}

typedef Handler = ResponseBody Function(RequestOptions o);

/// Máy chủ giả: đăng ký route theo `METHOD /path`, ghi lại mọi request để test kiểm tra.
class FakeServer implements HttpClientAdapter {
  final _routes = <String, Handler>{};
  final requests = <RequestOptions>[];

  void on(String method, String path, Handler h) => _routes['$method $path'] = h;

  static ResponseBody json(Object? body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  static ResponseBody empty([int status = 204]) => ResponseBody.fromString('', status);

  Iterable<RequestOptions> calls(String method, String path) => requests.where((r) => r.method == method && r.uri.path == path);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final h = _routes['${options.method} ${options.uri.path}'];
    if (h == null) return json({'message': 'Không có route giả cho ${options.method} ${options.uri.path}'}, 404);
    return h(options);
  }

  @override
  void close({bool force = false}) {}
}

ApiClient clientFor(FakeServer s) =>
    ApiClient(tokenProvider: () => 'jwt', dio: Dio()..httpClientAdapter = s, baseUrl: 'https://api.test');

/// Dựng một màn hình với đủ repository chạy qua [FakeServer] và phiên đăng nhập theo [role].
Future<AuthController> pumpScreen(
  dynamic tester,
  FakeServer server,
  Widget screen, {
  UserRole role = UserRole.admin,
  String? userId,
}) async {
  final api = clientFor(server);
  final session = sessionFor(role);
  final auth = AuthController(
    api: FakeAuthApi(role: role),
    store: MemoryStore(userId == null
        ? session
        : Session(token: session.token, role: role, userId: userId, fullName: session.fullName, email: session.email)),
    google: FakeGoogle(),
  );
  await auth.restore();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      Provider<AuthApi>.value(value: AuthRepository(api)),
      Provider<EmployeeRepository>.value(value: EmployeeRepository(api)),
      Provider<DepartmentRepository>.value(value: DepartmentRepository(api)),
      Provider<ShiftRepository>.value(value: ShiftRepository(api)),
      Provider<LocationRepository>.value(value: LocationRepository(api)),
      Provider<LeaveRepository>.value(value: LeaveRepository(api)),
      Provider<QrRepository>.value(value: QrRepository(api)),
      Provider<AttendanceRepository>.value(value: AttendanceRepository(api)),
      Provider<DeviceIdProvider>.value(value: FixedDeviceId()),
    ],
    child: MaterialApp(theme: buildTheme(), home: screen),
  ));
  return auth;
}

Map<String, dynamic> page(List<Map<String, dynamic>> items, {int? total, int pageNo = 1, int pageSize = 50}) =>
    {'total': total ?? items.length, 'page': pageNo, 'pageSize': pageSize, 'items': items};

Map<String, dynamic> dept(int id, String name, [String? desc]) => {'id': id, 'name': name, 'description': desc, 'employees': []};

Map<String, dynamic> shift(int id, String name, [String start = '08:00:00', String end = '17:00:00', int tol = 10]) =>
    {'id': id, 'name': name, 'startTime': start, 'endTime': end, 'lateToleranceMinutes': tol};

Map<String, dynamic> location(int id, String name, {int shiftId = 1}) => {
      'id': id,
      'name': name,
      'address': 'Số 1',
      'latitude': 10.8019,
      'longitude': 106.7144,
      'radiusMeters': 150,
      'shiftId': shiftId,
      'shift': null,
    };

Map<String, dynamic> employee(String id, String name, {String? code, int? deptId, String? deptName, bool active = true, String? role}) => {
      'id': id,
      'fullName': name,
      'email': '${name.toLowerCase().replaceAll(' ', '.')}@test.local',
      'employeeCode': code,
      'departmentId': deptId,
      'department': deptName,
      'isActive': active,
      'hasFace': false,
      'role': ?role,
    };

Map<String, dynamic> leave(int id, String who, String status, {String from = '2026-11-02', String to = '2026-11-03', String reason = 'Việc gia đình'}) =>
    {'id': id, 'userId': 'u-$id', 'userName': who, 'fromDate': from, 'toDate': to, 'reason': reason, 'status': status, 'createdAt': '2026-10-29T03:00:00Z'};

Object? bodyOf(RequestOptions o) => o.data;
