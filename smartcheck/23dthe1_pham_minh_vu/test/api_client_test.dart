import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pham_minh_vu_23dthe1/core/api_client.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

ApiClient _client(_Adapter a, {String? token}) {
  final dio = Dio()..httpClientAdapter = a;
  return ApiClient(tokenProvider: () => token, dio: dio, baseUrl: 'https://api.test');
}

void main() {
  test('gắn Authorization Bearer khi có token', () async {
    final a = _Adapter((_) => _json({'ok': true}, 200));
    await _client(a, token: 'abc').get('/api/auth/me');
    expect(a.requests.single.headers['Authorization'], 'Bearer abc');
    expect(a.requests.single.uri.toString(), 'https://api.test/api/auth/me');
  });

  test('không gắn Authorization khi chưa đăng nhập', () async {
    final a = _Adapter((_) => _json({}, 200));
    await _client(a).post('/api/auth/login', body: {'a': 1});
    expect(a.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('401 có JWT thì báo onUnauthorized', () async {
    final a = _Adapter((_) => _json({'message': 'x'}, 401));
    final c = _client(a, token: 'abc');
    var called = 0;
    c.onUnauthorized = () => called++;
    await expectLater(c.get('/api/leaves'), throwsA(isA<ApiException>()));
    expect(called, 1);
  });

  test('401 khi đăng nhập sai (không có JWT) không bị coi là hết phiên', () async {
    final a = _Adapter((_) => _json({'message': 'Sai tài khoản hoặc mật khẩu'}, 401));
    final c = _client(a);
    var called = 0;
    c.onUnauthorized = () => called++;
    try {
      await c.post('/api/auth/login', body: {});
      fail('phải ném lỗi');
    } on ApiException catch (e) {
      expect(e.message, 'Sai tài khoản hoặc mật khẩu');
      expect(e.status, 401);
    }
    expect(called, 0);
  });

  test('đọc {code, message, reasons} của chấm công', () async {
    final a = _Adapter((_) => _json({
          'code': 'FRAUD_SUSPECTED',
          'message': 'Chấm công bị từ chối',
          'reasons': ['Thiết bị báo vị trí giả lập (mock location)'],
        }, 403));
    try {
      await _client(a, token: 't').post('/api/attendance/check-in', body: {});
      fail('phải ném lỗi');
    } on ApiException catch (e) {
      expect(e.code, 'FRAUD_SUSPECTED');
      expect(e.status, 403);
      expect(e.reasons, ['Thiết bị báo vị trí giả lập (mock location)']);
    }
  });

  test('đọc {errors:[...]} của đăng ký (Identity) và dịch sang tiếng Việt', () async {
    final a = _Adapter((_) => _json({
          'errors': ["Passwords must have at least one digit ('0'-'9').", "Email 'a@b.co' is already taken."]
        }, 400));
    try {
      await _client(a).post('/api/auth/register', body: {});
      fail('phải ném lỗi');
    } on ApiException catch (e) {
      expect(e.message, 'Mật khẩu cần ít nhất một chữ số.\nEmail này đã được đăng ký.');
    }
  });

  test('đọc {errors:{Field:[...]}} của validation model', () async {
    final a = _Adapter((_) => _json({
          'title': 'One or more validation errors occurred.',
          'errors': {
            'Email': ['The Email field is not a valid e-mail address.'],
            'FullName': ['The FullName field is required.'],
            'Password': ["The field Password must be a string or array type with a minimum length of '6'."],
            'Khac': ['Lỗi lạ không có bản dịch'],
          }
        }, 400));
    try {
      await _client(a).post('/api/auth/register', body: {});
      fail('phải ném lỗi');
    } on ApiException catch (e) {
      expect(e.message,
          'Email không hợp lệ.\nNhập họ và tên.\nMật khẩu tối thiểu 6 ký tự.\nLỗi lạ không có bản dịch');
    }
  });

  test('thân phản hồi là HTML (lỗi IIS) thì dùng thông báo theo mã HTTP', () async {
    final a = _Adapter((_) => ResponseBody.fromString('<html>500</html>', 500, headers: {
          Headers.contentTypeHeader: ['text/html']
        }));
    try {
      await _client(a).get('/x');
      fail('phải ném lỗi');
    } on ApiException catch (e) {
      expect(e.message, contains('HTTP 500'));
    }
  });

  test('mất mạng thì isNetwork = true', () async {
    final a = _Adapter((o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'));
    try {
      await _client(a).get('/x');
      fail('phải ném lỗi');
    } on ApiException catch (e) {
      expect(e.isNetwork, isTrue);
      expect(e.message, contains('kết nối'));
    }
  });
}
