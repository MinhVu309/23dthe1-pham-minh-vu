import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'auth.dart';

/// Navigator toàn cục để chuyển về LoginScreen từ nơi không có BuildContext (VD khi API trả 401).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Đăng xuất: xóa token rồi về LoginScreen và xóa toàn bộ các màn hình phía trước
/// (pushAndRemoveUntil chứ không dùng popUntil(isFirst), vì màn hình đầu chưa chắc là LoginScreen).
Future<void> logout({String? notice}) async {
  await Auth.logout();
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => LoginScreen(notice: notice)),
    (route) => false,
  );
}

/// Gọi khi server từ chối token (401): đăng xuất kèm thông báo.
Future<void> forceLogout() => logout(notice: 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
