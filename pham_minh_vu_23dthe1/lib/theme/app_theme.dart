import 'package:flutter/material.dart';

/// Bảng màu giao diện kiểu Facebook (chỉ lấy bố cục và màu).
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1877F2); // xanh chủ đạo
  static const background = Color(0xFFF0F2F5); // nền trang
  static const card = Colors.white; // thẻ
  static const textPrimary = Color(0xFF050505); // chữ chính
  static const textSecondary = Color(0xFF65676B); // chữ phụ, icon chưa chọn
  static const divider = Color(0xFFCED0D4); // đường kẻ
  static const buttonGray = Color(0xFFE4E6EB); // nút phụ xám
  static const green = Color(0xFF42B72A); // nút "Tạo tài khoản"
  static const danger = Color(0xFFD93025); // lỗi / xóa
}

/// Chủ đề sáng. Chế độ tối chưa làm: Đăng nhập/Chợ/Admin còn dùng màu cố định và sẽ được làm lại ở bước sau,
/// bật chế độ tối lúc này sẽ gây chữ sáng trên nền sáng.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.divider,
      outlineVariant: AppColors.divider,
      surfaceContainerHighest: AppColors.buttonGray,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.divider,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
    );
  }
}
