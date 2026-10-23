import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'safe_network_image.dart';

/// Avatar tròn. Không có ảnh (hoặc lỗi tải) thì hiện hình người xám.
/// [ring] vẽ viền xanh quanh avatar (dùng cho hàng "vừa đăng bài").
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.url, this.size = 40, this.ring = false});

  final String? url;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: SafeNetworkImage(url: url, width: size, height: size, fallbackIcon: Icons.person),
      ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2.5),
      ),
      child: avatar,
    );
  }
}

/// Giữ import của CachedNetworkImage ở một chỗ để dễ xóa cache khi cần (VD đổi ảnh đại diện).
Future<void> evictImage(String url) => CachedNetworkImage.evictFromCache(url);
