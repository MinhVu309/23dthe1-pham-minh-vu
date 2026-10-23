import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Nút icon tròn nền xám (tìm kiếm, tin nhắn trên AppBar). Hình 40dp nhưng vùng bấm 48dp.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.buttonGray,
        foregroundColor: AppColors.textPrimary,
        fixedSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: Icon(icon, size: 22),
    );
  }
}
