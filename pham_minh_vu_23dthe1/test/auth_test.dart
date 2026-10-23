import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pham_minh_vu_23dthe1/models/auth_session.dart';
import 'package:pham_minh_vu_23dthe1/models/category.dart';
import 'package:pham_minh_vu_23dthe1/models/product_post.dart';
import 'package:pham_minh_vu_23dthe1/services/api_client.dart';
import 'package:pham_minh_vu_23dthe1/services/auth_service.dart';
import 'package:pham_minh_vu_23dthe1/services/token_storage.dart';
import 'package:pham_minh_vu_23dthe1/utils/jwt_claims.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _roleKey = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
const _nameKey = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';

/// Tạo JWT giả (không ký) để thử phần giải mã.
String fakeJwt(Map<String, dynamic> payload) {
  String enc(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.signature';
}

int _exp(Duration fromNow) => DateTime.now().add(fromNow).millisecondsSinceEpoch ~/ 1000;

String tokenFor(String role, {Duration life = const Duration(hours: 1), String user = 'tester'}) =>
    fakeJwt({_nameKey: user, _roleKey: role, 'exp': _exp(life)});

http.Response json(int status, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.onUnauthorized = null;
  });

  group('jwt_claims', () {
    test('role dạng chuỗi (tên claim thật của backend)', () {
      expect(extractRole({_roleKey: 'Admin'}), 'Admin');
      expect(extractRole({_roleKey: 'User'}), 'User');
    });

    test('role dạng mảng và tên rút gọn', () {
      expect(extractRole({'role': ['User', 'Admin']}), 'Admin'); // có Admin thì ưu tiên Admin
      expect(extractRole({'roles': ['user']}), 'User');
    });

    test('không có role hoặc role lạ -> null', () {
      expect(extractRole({}), isNull);
      expect(extractRole({_roleKey: 'SuperAdmin'}), isNull);
    });

    test('username', () {
      expect(extractUsername({_nameKey: 'abc'}), 'abc');
      expect(extractUsername({'unique_name': 'xyz'}), 'xyz');
      expect(extractUsername({}), isNull);
    });
  });

  group('AuthSession.tryParse', () {
    test('token hợp lệ', () {
      final s = AuthSession.tryParse(tokenFor('Admin', user: 'admin1'))!;
      expect(s.username, 'admin1');
      expect(s.isAdmin, isTrue);
      expect(s.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    test('token hết hạn / hỏng / role lạ -> null', () {
      expect(AuthSession.tryParse(tokenFor('User', life: const Duration(seconds: -5))), isNull);
      expect(AuthSession.tryParse('khong-phai-jwt'), isNull);
      expect(AuthSession.tryParse(tokenFor('Hacker')), isNull);
    });
  });

  group('AuthService', () {
    AuthService serviceWith(MockClient mock) => AuthService(client: ApiClient(baseUrl: 'http://x/api/', client: mock));

    test('đăng nhập Admin: lưu token và trả role/username lấy từ token', () async {
      final token = tokenFor('Admin', user: 'admin1');
      final service = serviceWith(MockClient((req) async {
        expect(req.url.toString(), 'http://x/api/Authenticate/login');
        expect(req.headers.containsKey('Authorization'), isFalse); // đăng nhập không gắn token
        return json(200, {'status': true, 'message': 'ok', 'token': token});
      }));
      final r = await service.login('admin1', 'pw');
      expect(r['success'], isTrue);
      expect(r['role'], 'Admin');
      expect(r['username'], 'admin1');
      expect(await TokenStorage.read(), token);
    });

    test('sai mật khẩu (401): báo lỗi của server, không lưu token, không bị coi là hết phiên', () async {
      var forced = false;
      ApiClient.onUnauthorized = () async => forced = true;
      await TokenStorage.save(tokenFor('User')); // đang có token cũ
      final service = serviceWith(MockClient(
        (_) async => json(401, {'status': false, 'message': 'Sai tên đăng nhập hoặc mật khẩu'}),
      ));
      final r = await service.login('a', 'b');
      expect(r['success'], isFalse);
      expect(r['message'], 'Sai tên đăng nhập hoặc mật khẩu');
      expect(forced, isFalse);
    });

    test('token có role lạ: không cho vào và không lưu token', () async {
      final service = serviceWith(MockClient(
        (_) async => json(200, {'status': true, 'message': 'ok', 'token': tokenFor('Hacker')}),
      ));
      final r = await service.login('a', 'b');
      expect(r['success'], isFalse);
      expect(await TokenStorage.read(), isNull);
    });

    test('đăng ký: chuẩn hóa status -> success và giữ thông báo lỗi của server', () async {
      final ok = await serviceWith(MockClient((_) async => json(200, {'status': true, 'message': 'Tạo tài khoản thành công'})))
          .register(username: 'u', email: 'u@x.com', password: 'Abc@123');
      expect(ok['success'], isTrue);

      final bad = await serviceWith(MockClient((_) async => json(400, {'status': false, 'message': 'Tên đăng nhập đã tồn tại'})))
          .register(username: 'u', email: 'u@x.com', password: 'Abc@123');
      expect(bad['success'], isFalse);
      expect(bad['message'], 'Tên đăng nhập đã tồn tại');
    });

    test('currentSession: token còn hạn thì trả phiên, hết hạn thì xóa token', () async {
      final service = serviceWith(MockClient((_) async => json(200, {})));
      expect(await service.currentSession(), isNull); // chưa đăng nhập

      await TokenStorage.save(tokenFor('Admin'));
      expect((await service.currentSession())!.isAdmin, isTrue);

      await TokenStorage.save(tokenFor('Admin', life: const Duration(seconds: -1)));
      expect(await service.currentSession(), isNull);
      expect(await TokenStorage.read(), isNull); // token hết hạn đã bị xóa
    });

    test('đăng xuất xóa token', () async {
      await TokenStorage.save(tokenFor('User'));
      await serviceWith(MockClient((_) async => json(200, {}))).logout();
      expect(await TokenStorage.read(), isNull);
    });
  });

  group('ApiClient', () {
    test('tự gắn Authorization: Bearer khi đã có token', () async {
      final token = tokenFor('User');
      await TokenStorage.save(token);
      String? header;
      final client = ApiClient(baseUrl: 'http://x/api/', client: MockClient((req) async {
        header = req.headers['Authorization'];
        return json(200, []);
      }));
      await client.get('ProductApi');
      expect(header, 'Bearer $token');
    });

    test('server trả 401 khi đã có token -> xóa token và gọi onUnauthorized', () async {
      await TokenStorage.save(tokenFor('User'));
      var forced = 0;
      ApiClient.onUnauthorized = () async => forced++;
      final client = ApiClient(baseUrl: 'http://x/api/', client: MockClient((_) async => json(401, {})));
      await client.get('ProductApi');
      expect(forced, 1);
      expect(await TokenStorage.read(), isNull);
    });
  });

  group('Danh mục', () {
    test('ProductPost đọc categoryId và tên danh mục; không có thì null', () {
      final p = ProductPost.fromJson({
        'id': 5, 'name': 'a', 'price': 1,
        'categoryId': 2, 'category': {'id': 2, 'name': 'Thời trang'},
      });
      expect(p.categoryId, 2);
      expect(p.categoryName, 'Thời trang');

      final none = ProductPost.fromJson({'id': 1, 'name': 'b', 'price': 1, 'categoryId': null, 'category': null});
      expect(none.categoryId, isNull);
      expect(none.categoryName, isNull);
    });

    test('toJson luôn gửi categoryId (null để bỏ khỏi danh mục)', () {
      expect(const ProductPost(id: 1, name: 'a', price: 1).toJson().containsKey('categoryId'), isTrue);
      expect(const ProductPost(name: 'a', price: 1, categoryId: 3).toJson()['categoryId'], 3);
    });

    test('Category: thêm không gửi id, sửa gửi id', () {
      expect(const Category(name: 'x').toJson().containsKey('id'), isFalse);
      expect(const Category(id: 4, name: 'x').toJson()['id'], 4);
    });
  });
}
