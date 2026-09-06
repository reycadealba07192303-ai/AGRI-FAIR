import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF5F2E8);
  static const Color primaryDark = Color(0xFF1B3829);
  static const Color primaryMedium = Color(0xFF4A7C59);
  static const Color primaryLight = Color(0xFF8DB89A);
  static const Color accent = Color(0xFFC9A96E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1B3829);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFD1D5DB);
  static const Color inputFill = Color(0xFFFAF9F5);
  static const Color error = Color(0xFFDC2626);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryDark,
      secondary: AppColors.primaryMedium,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    fontFamily: 'serif',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppColors.primaryMedium, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      labelStyle: const TextStyle(color: AppColors.textMuted),
    ),
  );
}
