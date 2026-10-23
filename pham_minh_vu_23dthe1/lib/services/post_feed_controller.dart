import 'package:flutter/foundation.dart';

import '../models/post.dart';
import 'api_service.dart';

/// Quản lý một danh sách bài đăng phân trang (Bảng tin, trang cá nhân): tải trang đầu, tải thêm khi cuộn,
/// làm mới, thêm/sửa/xóa tại chỗ và thích kiểu optimistic (đổi ngay, lỗi thì hoàn tác).
class PostFeedController extends ChangeNotifier {
  PostFeedController(this._fetchPage, {this.pageSize = 10, ApiService? api}) : _api = api ?? apiService;

  final Future<PagedPosts> Function(int page, int pageSize) _fetchPage;
  final ApiService _api;
  final int pageSize;

  final List<Post> items = [];
  bool loading = false; // đang tải trang đầu / làm mới
  bool loadingMore = false;
  bool hasMore = true;
  bool loaded = false;
  String? error; // lỗi khi tải trang đầu
  String? loadMoreError;

  int _page = 0;
  int _generation = 0; // tăng mỗi lần làm mới để bỏ kết quả của yêu cầu cũ về muộn
  final Set<int> _likeBusy = {};

  /// Tải lại từ trang 1. Giữ danh sách cũ trên màn hình cho tới khi có dữ liệu mới.
  Future<void> refresh() async {
    final gen = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _fetchPage(1, pageSize);
      if (gen != _generation) return;
      items
        ..clear()
        ..addAll(result.items);
      _page = 1;
      hasMore = result.hasMore;
      loadMoreError = null;
      loaded = true;
    } on ApiException catch (e) {
      if (gen != _generation) return;
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || !loaded) return;
    final gen = _generation;
    loadingMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _fetchPage(_page + 1, pageSize);
      if (gen != _generation) return;
      // Bài mới đăng làm các trang lệch nhau: bỏ bài đã có để không bị lặp
      final existing = items.map((p) => p.id).toSet();
      items.addAll(result.items.where((p) => !existing.contains(p.id)));
      _page += 1;
      hasMore = result.hasMore;
    } on ApiException catch (e) {
      if (gen != _generation) return;
      loadMoreError = e.message;
    }
    loadingMore = false;
    notifyListeners();
  }

  void insertTop(Post post) {
    items.removeWhere((p) => p.id == post.id);
    items.insert(0, post);
    notifyListeners();
  }

  void replace(Post post) {
    final i = items.indexWhere((p) => p.id == post.id);
    if (i < 0) return;
    items[i] = post;
    notifyListeners();
  }

  void remove(int postId) {
    items.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  /// Cộng/trừ số bình luận khi thêm/xóa bình luận trong bottom sheet.
  void adjustCommentCount(int postId, int delta) {
    final i = items.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final post = items[i];
    items[i] = post.copyWith(commentCount: (post.commentCount + delta).clamp(0, 1 << 30));
    notifyListeners();
  }

  /// Thích/bỏ thích: cập nhật giao diện NGAY, gọi API, rồi đồng bộ số thật từ server.
  /// Lỗi thì hoàn tác và trả về thông báo lỗi (null nếu thành công). Đang gửi dở cho cùng bài thì bỏ qua lần bấm.
  Future<String?> toggleLike(Post post) async {
    if (!_likeBusy.add(post.id)) return null;
    final before = items.firstWhere((p) => p.id == post.id, orElse: () => post);
    final optimistic = before.copyWith(
      likedByMe: !before.likedByMe,
      likeCount: (before.likeCount + (before.likedByMe ? -1 : 1)).clamp(0, 1 << 30),
    );
    replace(optimistic);
    try {
      final result = await _api.toggleLike(post.id);
      final latest = items.firstWhere((p) => p.id == post.id, orElse: () => optimistic);
      replace(latest.copyWith(likedByMe: result.liked, likeCount: result.likeCount));
      return null;
    } on ApiException catch (e) {
      final latest = items.firstWhere((p) => p.id == post.id, orElse: () => optimistic);
      replace(latest.copyWith(likedByMe: before.likedByMe, likeCount: before.likeCount));
      return e.message;
    } finally {
      _likeBusy.remove(post.id);
    }
  }
}
