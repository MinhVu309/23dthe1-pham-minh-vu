import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/config_url.dart';
import '../models/category.dart';
import '../models/post.dart';
import '../models/product_post.dart';
import 'api_client.dart';

/// Lỗi gọi API, có thông điệp tiếng Việt để hiện trên SnackBar.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Toàn bộ lời gọi API nghiệp vụ (sản phẩm, bài đăng) nằm ở đây.
/// Request đi qua ApiClient nên tự gắn token và xử lý 401.
class ApiService {
  ApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static const _timeout = Duration(seconds: 10);

  /// Gửi request, đổi mọi lỗi mạng/timeout/HTTP thành ApiException.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final res = await request().timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return res;
      throw ApiException(_errorMessage(res));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Hết thời gian chờ, kiểm tra backend đã chạy chưa');
    } on SocketException {
      throw ApiException('Không kết nối được tới ${Config_URL.baseUrl}');
    } on http.ClientException {
      throw ApiException('Không kết nối được tới ${Config_URL.baseUrl}');
    }
  }

  String _errorMessage(http.Response res) {
    switch (res.statusCode) {
      case 401:
        return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này';
      case 404:
        return 'Không tìm thấy dữ liệu (404)';
    }
    // Nếu server có kèm "message" (VD lỗi validate 400) thì hiển thị luôn
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
    } catch (_) {}
    return 'Máy chủ trả về lỗi ${res.statusCode}';
  }

  dynamic _decode(http.Response res) => jsonDecode(utf8.decode(res.bodyBytes));

  List<T> _list<T>(http.Response res, T Function(Map<String, dynamic>) fromJson) =>
      (_decode(res) as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();

  // ---------------- Sản phẩm: api/ProductApi ----------------

  Future<List<ProductPost>> getProducts() async {
    final res = await _send(() => _client.get('ProductApi'));
    return _list(res, ProductPost.fromJson);
  }

  Future<ProductPost> getProductById(int id) async {
    final res = await _send(() => _client.get('ProductApi/$id'));
    return ProductPost.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// GET api/ProductApi/search?name=...
  Future<List<ProductPost>> searchProducts(String name) async {
    final res = await _send(
      () => _client.get('ProductApi/search?name=${Uri.encodeQueryComponent(name)}'),
    );
    return _list(res, ProductPost.fromJson);
  }

  Future<ProductPost> addProduct(ProductPost product) async {
    final res = await _send(() => _client.post('ProductApi', body: product.toJson()));
    return ProductPost.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<void> updateProduct(ProductPost product) async {
    await _send(() => _client.put('ProductApi/${product.id}', body: product.toJson()));
  }

  Future<void> deleteProduct(int id) async {
    await _send(() => _client.delete('ProductApi/$id'));
  }

  // ---------------- Danh mục: api/CategoryApi (thêm/sửa/xóa chỉ Admin) ----------------

  Future<List<Category>> getCategories() async {
    final res = await _send(() => _client.get('CategoryApi'));
    return _list(res, Category.fromJson);
  }

  Future<Category> addCategory(Category category) async {
    final res = await _send(() => _client.post('CategoryApi', body: category.toJson()));
    return Category.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<void> updateCategory(Category category) async {
    await _send(() => _client.put('CategoryApi/${category.id}', body: category.toJson()));
  }

  Future<void> deleteCategory(int id) async {
    await _send(() => _client.delete('CategoryApi/$id'));
  }

  // ---------------- Bài đăng: api/PostApi ----------------

  Future<List<Post>> getPosts() async {
    final res = await _send(() => _client.get('PostApi'));
    return _list(res, Post.fromJson);
  }

  Future<Post> addPost(Post post) async {
    final res = await _send(() => _client.post('PostApi', body: post.toJson()));
    return Post.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<void> updatePost(Post post) async {
    await _send(() => _client.put('PostApi/${post.id}', body: post.toJson()));
  }

  Future<void> deletePost(int id) async {
    await _send(() => _client.delete('PostApi/$id'));
  }
}

/// Dùng chung một instance cho toàn app.
final apiService = ApiService();
