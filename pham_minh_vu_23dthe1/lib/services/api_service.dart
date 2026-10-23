import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/config_url.dart';
import '../models/app_notification.dart';
import '../models/category.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/profile.dart';
import '../models/product_post.dart';
import '../utils/image_type.dart';
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
  Future<http.Response> _send(Future<http.Response> Function() request, {Duration timeout = _timeout}) async {
    try {
      final res = await request().timeout(timeout);
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
    if (res.statusCode == 401) return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';

    // Server kèm "message" (VD lỗi validate, 403 chủ bài, 413 ảnh quá lớn) thì hiển thị đúng nội dung đó
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
    } catch (_) {}

    switch (res.statusCode) {
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này';
      case 404:
        return 'Không tìm thấy dữ liệu (404)';
      case 413:
        return 'Tệp quá lớn (tối đa 5MB)';
    }
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

  /// Một trang bài đăng, mới nhất trước.
  Future<PagedPosts> getPostsPage({int page = 1, int pageSize = 10}) async {
    final res = await _send(() => _client.get('PostApi?page=$page&pageSize=$pageSize'));
    return PagedPosts.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<Post> getPostById(int id) async {
    final res = await _send(() => _client.get('PostApi/$id'));
    return Post.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// Chủ bài, tên, ảnh đại diện do server gán từ token; client chỉ gửi nội dung và ảnh.
  Future<Post> createPost({required String content, String? image}) async {
    final res = await _send(() => _client.post('PostApi', body: {'content': content, 'image': image}));
    return Post.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<void> updatePost(int id, {required String content, String? image}) async {
    await _send(() => _client.put('PostApi/$id', body: {'id': id, 'content': content, 'image': image}));
  }

  Future<void> deletePost(int id) async {
    await _send(() => _client.delete('PostApi/$id'));
  }

  /// Bật/tắt thích. Trả về trạng thái thật và tổng số thích từ server.
  Future<({bool liked, int likeCount})> toggleLike(int postId) async {
    final res = await _send(() => _client.post('PostApi/$postId/like'));
    final data = _decode(res) as Map<String, dynamic>;
    return (liked: data['liked'] as bool? ?? false, likeCount: (data['likeCount'] as num?)?.toInt() ?? 0);
  }

  // ---------------- Bình luận ----------------

  Future<CommentPage> getComments(int postId, {int page = 1, int pageSize = 50}) async {
    final res = await _send(() => _client.get('PostApi/$postId/comments?page=$page&pageSize=$pageSize'));
    final items = _list(res, Comment.fromJson);
    final total = int.tryParse(res.headers['x-total-count'] ?? '') ?? items.length;
    return CommentPage(items: items, total: total);
  }

  Future<Comment> addComment(int postId, String content) async {
    final res = await _send(() => _client.post('PostApi/$postId/comments', body: {'content': content}));
    return Comment.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<void> deleteComment(int postId, int commentId) async {
    await _send(() => _client.delete('PostApi/$postId/comments/$commentId'));
  }

  // ---------------- Upload ảnh, hồ sơ, thông báo ----------------

  /// Upload ảnh (jpg/png/webp, tối đa 5MB) và trả về URL đầy đủ để gắn vào bài đăng.
  /// Đuôi tên tệp được đặt theo NỘI DUNG thật (không tin tên tệp từ trình chọn ảnh), vì server đối chiếu cả hai.
  Future<String> uploadImage(String filePath) async {
    final header = <int>[];
    await for (final chunk in File(filePath).openRead(0, 12)) {
      header.addAll(chunk);
    }
    final extension = detectImageExtension(header);
    if (extension == null) throw const ApiException('Chỉ đăng được ảnh JPG, PNG hoặc WEBP');

    final res = await _send(
      () => _client.postFile('UploadApi', field: 'file', filePath: filePath, filename: 'photo$extension'),
      timeout: const Duration(seconds: 60),
    );
    final url = (_decode(res) as Map<String, dynamic>)['url'] as String?;
    if (url == null || url.isEmpty) throw const ApiException('Server không trả về đường dẫn ảnh');
    return url;
  }

  Future<Profile> getMyProfile() async {
    final res = await _send(() => _client.get('ProfileApi/me'));
    return Profile.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<Profile> getProfile(String userId) async {
    final res = await _send(() => _client.get('ProfileApi/${Uri.encodeComponent(userId)}'));
    return Profile.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<PagedPosts> getProfilePosts(String userId, {int page = 1, int pageSize = 10}) async {
    final res = await _send(
      () => _client.get('ProfileApi/${Uri.encodeComponent(userId)}/posts?page=$page&pageSize=$pageSize'),
    );
    return PagedPosts.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<AppNotification>> getNotifications() async {
    final res = await _send(() => _client.get('NotificationApi'));
    return _list(res, AppNotification.fromJson);
  }
}

/// Dùng chung một instance cho toàn app.
final apiService = ApiService();
