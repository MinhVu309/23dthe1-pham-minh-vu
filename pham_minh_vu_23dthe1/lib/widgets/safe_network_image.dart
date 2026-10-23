import 'package:flutter/material.dart';

/// Ảnh mạng an toàn: dữ liệu mẫu có thể là "Cập nhật sau" (không phải URL),
/// nên chỉ load khi chuỗi bắt đầu bằng http; lỗi/không hợp lệ thì hiện icon.
class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  bool get _isUrl => url != null && url!.trim().toLowerCase().startsWith('http');

  Widget _fallback(BuildContext context) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(fallbackIcon, color: Theme.of(context).colorScheme.outline),
      );

  @override
  Widget build(BuildContext context) {
    if (!_isUrl) return _fallback(context);
    return Image.network(
      url!.trim(),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) => _fallback(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}
