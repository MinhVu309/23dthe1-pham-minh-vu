import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../theme/app_theme.dart';
import 'safe_network_image.dart';

/// Đầu trang cá nhân: ảnh bìa, avatar lớn đè lên mép dưới ảnh bìa, tên, giới thiệu và số bài viết.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile});

  final Profile profile;

  static const _coverHeight = 170.0;
  static const _avatarSize = 104.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: _coverHeight,
                width: double.infinity,
                child: SafeNetworkImage(
                  url: profile.coverUrl,
                  width: double.infinity,
                  height: _coverHeight,
                  fallbackIcon: Icons.landscape_outlined,
                ),
              ),
              Positioned(
                left: 16,
                bottom: -_avatarSize / 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                  child: ClipOval(
                    child: SafeNetworkImage(
                      url: profile.avatarUrl,
                      width: _avatarSize,
                      height: _avatarSize,
                      fallbackIcon: Icons.person,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _avatarSize / 2 + 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(profile.bio, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.article_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('${profile.postCount} bài viết', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
