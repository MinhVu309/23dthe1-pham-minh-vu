import 'package:flutter/material.dart';

import 'safe_network_image.dart';

/// Ảnh bài viết full-width. Bấm đúp để thích: luôn hiện trái tim bay lên ở giữa ảnh,
/// còn việc thích thật sự do [onDoubleTap] quyết định (chỉ thích khi chưa thích).
class DoubleTapImage extends StatefulWidget {
  const DoubleTapImage({super.key, required this.url, this.onDoubleTap, this.maxHeight = 480});

  final String url;
  final VoidCallback? onDoubleTap;
  final double maxHeight;

  @override
  State<DoubleTapImage> createState() => _DoubleTapImageState();
}

class _DoubleTapImageState extends State<DoubleTapImage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
  ]).animate(_controller);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    _controller.forward(from: 0);
    widget.onDoubleTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ảnh rộng hết khung, cao theo tỉ lệ thật nhưng không quá maxHeight (phần dư bị cắt ở dưới)
            ClipRect(
              child: SafeNetworkImage(
                url: widget.url,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                placeholderHeight: 240,
              ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => !_controller.isAnimating
                    ? const SizedBox.shrink()
                    : Opacity(
                        opacity: _opacity.value,
                        child: Transform.scale(
                          scale: _scale.value,
                          child: const Icon(
                            Icons.favorite,
                            size: 96,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 16)],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
