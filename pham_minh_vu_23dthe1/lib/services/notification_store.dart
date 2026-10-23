import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import 'api_service.dart';

/// Thông báo (lượt thích/bình luận trên bài của tôi, 7 ngày gần nhất) và số chưa xem để hiện badge.
/// Server không lưu trạng thái "đã xem", nên mốc xem gần nhất được lưu trên máy (theo từng tài khoản).
class NotificationStore extends ChangeNotifier {
  NotificationStore({required this.userId, ApiService? api}) : _api = api ?? apiService;

  final String userId;
  final ApiService _api;

  List<AppNotification> _items = const [];
  DateTime? _lastSeen; // mốc xem gần nhất: dùng tính badge
  DateTime? _highlightAfter; // mốc xem của lần mở TRƯỚC: các mục mới hơn mốc này được tô nổi khi đang ở tab
  Object? _error;
  bool _loading = false;
  bool _loaded = false;

  List<AppNotification> get items => _items;
  Object? get error => _error;
  bool get loading => _loading;
  bool get loaded => _loaded;
  DateTime? get lastSeen => _lastSeen;

  String get _key => 'notif_last_seen_$userId';

  /// Số thông báo mới hơn mốc xem gần nhất (chưa từng xem thì tính tất cả).
  int get unreadCount {
    final seen = _lastSeen;
    if (seen == null) return _items.length;
    return _items.where((n) => n.createdAt.isAfter(seen)).length;
  }

  /// Mục có được tô nổi (mới từ lần mở tab trước) không. Chưa mở lần nào thì tô tất cả.
  bool isHighlighted(AppNotification n) => _highlightAfter == null || n.createdAt.isAfter(_highlightAfter!);

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _lastSeen ??= await _readLastSeen();
      _items = await _api.getNotifications();
      _error = null;
    } on ApiException catch (e) {
      _error = e;
    }
    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  /// Gọi khi người dùng mở tab Thông báo: đặt mốc xem = bây giờ (badge về 0).
  /// Các mục mới vẫn được tô nổi trong lúc đang ở tab (theo _highlightAfter), badge thì về 0.
  Future<void> markAllSeen({DateTime? now}) async {
    _highlightAfter = _lastSeen;
    _lastSeen = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _lastSeen!.toUtc().toIso8601String());
    notifyListeners();
  }

  Future<DateTime?> _readLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }
}
