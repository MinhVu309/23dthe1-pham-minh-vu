import 'package:flutter/material.dart';

import '../utils/session.dart';
import 'error_view.dart';

/// Nút đăng xuất trên AppBar (có hộp thoại xác nhận).
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Đăng xuất',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        final ok = await confirmDialog(
          context,
          title: 'Đăng xuất',
          message: 'Bạn có chắc muốn đăng xuất?',
          confirmText: 'Đăng xuất',
        );
        if (ok) await logout();
      },
    );
  }
}
