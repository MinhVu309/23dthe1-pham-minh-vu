import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_avatar.dart';

/// Ô soạn bài đầu trang: avatar + "Bạn đang nghĩ gì?" + nút ảnh.
class ComposerCard extends StatelessWidget {
  const ComposerCard({super.key, required this.avatarUrl, required this.onCompose, required this.onPickPhoto});

  final String avatarUrl;
  final VoidCallback onCompose;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      color: AppColors.card,
      child: Row(
        children: [
          AppAvatar(url: avatarUrl, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Tạo bài viết mới',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onCompose,
                child: Container(
                  height: 48,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Bạn đang nghĩ gì?',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Đăng ảnh',
            iconSize: 28,
            onPressed: onPickPhoto,
            icon: const Icon(Icons.photo_library, color: AppColors.green),
          ),
        ],
      ),
    );
  }
}
