import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Khối xám có ánh sáng quét ngang (hiệu ứng "đang tải"), tự viết, không dùng thư viện.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key, this.width, required this.height, this.radius = 6, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 3 - 1; // vệt sáng đi từ trái sang phải
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: const [AppColors.buttonGray, Color(0xFFF5F6F7), AppColors.buttonGray],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// Khung xám giả một thẻ bài viết, hiện khi tải lần đầu.
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key, this.withImage = true});

  final bool withImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ShimmerBox(width: 40, height: 40, circle: true),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ShimmerBox(width: 130, height: 12), SizedBox(height: 8), ShimmerBox(width: 80, height: 10)],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ShimmerBox(height: 12), SizedBox(height: 8), ShimmerBox(width: 220, height: 12)],
            ),
          ),
          if (withImage) ...[
            const SizedBox(height: 14),
            const ShimmerBox(height: 200, radius: 0),
          ],
        ],
      ),
    );
  }
}
