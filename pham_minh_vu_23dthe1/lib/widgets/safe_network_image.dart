import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ảnh mạng có cache. Dữ liệu mẫu có thể là "Cập nhật sau" (không phải URL), nên chỉ tải khi chuỗi
/// bắt đầu bằng http; lỗi hoặc không hợp lệ thì hiện icon thay thế.
class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholderHeight,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  /// Chiều cao của khung chờ/ảnh lỗi khi [height] chưa biết (ảnh bài viết cao theo tỉ lệ thật sau khi tải xong).
  final double? placeholderHeight;
  final IconData fallbackIcon;

  static bool isUrl(String? value) => value != null && value.trim().toLowerCase().startsWith('http');

  Widget _fallback() => Container(
        width: width,
        height: height ?? placeholderHeight,
        color: AppColors.buttonGray,
        child: Icon(fallbackIcon, color: AppColors.textSecondary),
      );

  @override
  Widget build(BuildContext context) {
    if (!isUrl(url)) return _fallback();
    return CachedNetworkImage(
      imageUrl: url!.trim(),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, _) => Container(
        width: width,
        height: height ?? placeholderHeight,
        color: AppColors.buttonGray,
        child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      errorWidget: (context, _, _) => _fallback(),
    );
  }
}
