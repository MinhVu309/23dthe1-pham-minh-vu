import 'package:flutter/material.dart';

import 'settings.dart';

/// Bảng màu "Xanh lá & cam": đầu trang xanh lá, nút chính cam, điểm nhấn xanh dương, nền xám xanh rất nhạt.
/// Tên các màu giữ nguyên từ bảng màu cũ (ink = chữ/nền tối, amber = điểm nhấn) để các màn khác tự đổi theo.
class AppColors {
  AppColors._();
  static const ink = Color(0xFF2A3350); // chữ đậm, nền tối
  static const inkSoft = Color(0xFF55607F);
  static const inkFaint = Color(0xFF3A4566);
  static const brand = Color(0xFF43BB7A); // xanh lá chính
  static const brandLight = Color(0xFF63CE92);
  static const brandDark = Color(0xFF2B9C5F);
  static const amber = Color(0xFFFF7A1A); // cam: nút chính, nút giữa thanh dưới
  static const amberLight = Color(0xFFFF9A4D);
  static const amberDark = Color(0xFFE0620A); // chữ/viền cam trên nền sáng
  static const sky = Color(0xFF14A8F5); // xanh dương
  static const paper = Color(0xFFF1F3F8);
  static const paperDeep = Color(0xFFE3E7F0);
  static const danger = Color(0xFFE5484D);
  static const ok = Color(0xFF2FB46A);
  static const textMuted = Color(0xFF6F7992);

  static const brandGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandLight, brand]);
  static const amberGradient = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [amberLight, amber]);
}

/// [background] là màu nền người dùng chọn trong Cài đặt: nền các trang ([ThemeData.scaffoldBackgroundColor])
/// và tờ bo tròn ở trang chủ ([ColorScheme.surfaceContainerLowest]).
ThemeData buildTheme({AppBackground background = AppBackground.fog}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.brand,
    onPrimary: Colors.white,
    secondary: AppColors.amber,
    onSecondary: Colors.white,
    surface: background.page,
    surfaceContainerLowest: background.sheet,
    error: AppColors.danger,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background.page,
    appBarTheme: AppBarTheme(
      backgroundColor: background.page,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.paperDeep),
      enabledBorder: border(AppColors.paperDeep),
      focusedBorder: border(AppColors.brand, 1.6),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.ink, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.brandDark),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
