import 'package:flutter/material.dart';

import '../services/current_user_store.dart';
import '../theme/app_theme.dart';
import '../utils/session.dart';
import '../widgets/app_avatar.dart';
import '../widgets/error_view.dart';
import 'admin_screen.dart';

/// Tab Menu: thông tin tài khoản, vào trang quản trị (chỉ Admin) và đăng xuất.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.onOpenProfile});

  /// Chuyển sang tab "Cá nhân".
  final VoidCallback onOpenProfile;

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc muốn đăng xuất?',
      confirmText: 'Đăng xuất',
    );
    if (ok) await logout(); // xóa token rồi về màn hình đăng nhập
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: currentUser,
      builder: (context, _) {
        final profile = currentUser.profile;
        return ListView(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppColors.card,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: AppAvatar(url: profile?.avatarUrl, size: 56),
                title: Text(
                  profile?.displayName ?? '...',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    if (profile != null && profile.email.isNotEmpty) profile.email,
                    if (profile != null) (profile.isAdmin ? 'Quản trị viên' : 'Người dùng'),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenProfile,
              ),
            ),
            Container(
              color: AppColors.card,
              child: Column(
                children: [
                  if (profile?.isAdmin ?? false) ...[
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                      title: const Text('Trang quản trị'),
                      subtitle: const Text('Quản lý sản phẩm và danh mục'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                  ],
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.danger),
                    title: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger)),
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
