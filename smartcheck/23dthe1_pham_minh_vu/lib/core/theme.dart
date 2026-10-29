import 'package:flutter/material.dart';

/// Bảng màu "Mực & hổ phách": xanh mực đậm, điểm nhấn hổ phách, nền giấy ấm.
class AppColors {
  AppColors._();
  static const ink = Color(0xFF12343B);
  static const inkSoft = Color(0xFF2D5A61);
  static const inkFaint = Color(0xFF1C4A52);
  static const amber = Color(0xFFF2A541);
  static const amberDark = Color(0xFFB7791F); // chữ/viền hổ phách trên nền sáng
  static const paper = Color(0xFFF6F1E7);
  static const paperDeep = Color(0xFFEAE2D1);
  static const danger = Color(0xFFB83A2E);
  static const ok = Color(0xFF2E7D5B);
  static const textMuted = Color(0xFF5E6F72);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.ink,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.amber,
    onSecondary: AppColors.ink,
    surface: AppColors.paper,
    error: AppColors.danger,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
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
      focusedBorder: border(AppColors.ink, 1.6),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
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
      style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
