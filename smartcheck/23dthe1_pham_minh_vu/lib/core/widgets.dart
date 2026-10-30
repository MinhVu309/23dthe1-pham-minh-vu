import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Mặt đồng hồ mờ làm hoạ tiết nền cho phần đầu các màn hình.
class DialPainter extends CustomPainter {
  const DialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.86, size.height * 0.28);
    final r = size.shortestSide * 0.62;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.inkSoft.withValues(alpha: 0.7);
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.72, ring..color = AppColors.inkSoft.withValues(alpha: 0.45));

    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      tick
        ..strokeWidth = major ? 2.4 : 1
        ..color = (major ? AppColors.amber : AppColors.inkSoft).withValues(alpha: major ? 0.85 : 0.6);
      final a = i * math.pi / 30;
      final from = c + Offset(math.cos(a), math.sin(a)) * (r - (major ? 14 : 8));
      final to = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(from, to, tick);
    }
    // kim giờ + kim phút
    final hand = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = AppColors.amber;
    canvas.drawLine(c, c + Offset(math.cos(-0.9), math.sin(-0.9)) * r * 0.42, hand);
    canvas.drawLine(c, c + Offset(math.cos(0.35), math.sin(0.35)) * r * 0.6, hand..strokeWidth = 2);
    canvas.drawCircle(c, 5, Paint()..color = AppColors.amber);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Nền đầu trang: gradient xanh lá với vài dải chéo mờ (dùng cho đăng nhập và trang chủ).
class HeaderBackdrop extends StatelessWidget {
  const HeaderBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.brandGradient),
        child: SizedBox.expand(child: CustomPaint(painter: _BandsPainter())),
      );
}

class _BandsPainter extends CustomPainter {
  const _BandsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    // Hai dải chéo rộng từ góc phải xuống, tạo cảm giác chiều sâu nhẹ.
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.35, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * 0.55)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.15)
        ..lineTo(size.width * 0.55, 0)
        ..lineTo(size.width * 0.8, 0)
        ..lineTo(0, size.height * 0.38)
        ..close(),
      paint..color = Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Nút hành động chính màu cam gradient, có quầng sáng (như nút "Show Ticket" trong mẫu).
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.amberGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.amber.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  else if (icon != null)
                    Icon(icon, color: Colors.white),
                  if (busy || icon != null) const SizedBox(width: 10),
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút vuông bo tròn một biểu tượng (nút xanh lá / xanh dương cạnh nút chính).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.color, required this.onPressed, this.tooltip});

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: SizedBox(width: 56, height: 56, child: Icon(icon, color: Colors.white)),
            ),
          ),
        ),
      );
}

/// Khung các màn đăng nhập/đăng ký: mảng mực phía trên, tờ giấy trượt lên đè.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brand,
      body: Stack(
        children: [
          const Positioned.fill(child: HeaderBackdrop()),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
                        child: SizedBox(
                          height: 48,
                          child: showBack
                              ? IconButton(
                                  color: Colors.white,
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  onPressed: () => Navigator.of(context).maybePop(),
                                )
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.1)),
                            const SizedBox(height: 8),
                            Text(subtitle,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15)),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(minHeight: box.maxHeight - 190),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút chính có trạng thái đang tải.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label),
      );
}

/// Khung báo lỗi/thông tin ngay trong form.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.message, {super.key, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.ok;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, height: 1.35))),
        ],
      ),
    );
  }
}
