import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import 'api_service.dart';

/// Hồ sơ của người đang đăng nhập (tên, ảnh đại diện, vai trò) để các màn hình dùng chung
/// mà không phải gọi lại API. Xóa khi đăng xuất.
class CurrentUserStore extends ChangeNotifier {
  Profile? _profile;
  Object? _error;

  Profile? get profile => _profile;
  Object? get error => _error;

  /// Tải (hoặc tải lại) hồ sơ của tôi. Lỗi thì giữ nguyên hồ sơ cũ và ghi lại lỗi.
  Future<void> load() async {
    try {
      _profile = await apiService.getMyProfile();
      _error = null;
    } on ApiException catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  void clear() {
    _profile = null;
    _error = null;
    notifyListeners();
  }
}

final currentUser = CurrentUserStore();
