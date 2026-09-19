import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textInverse,
        onSecondary: AppColors.textInverse,
        onSurface: AppColors.textMain,
        onError: AppColors.textInverse,
      ),

      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: AppColors.textMain),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: AppColors.textMain),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: AppColors.textMain),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(color: AppColors.textMain),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: AppColors.textMain),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: AppColors.textMain),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: AppColors.textMain, fontWeight: FontWeight.bold),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: AppColors.textMain, fontWeight: FontWeight.w600),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: AppColors.textMain, fontWeight: FontWeight.w500),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: AppColors.textMain),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: AppColors.textMain),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: AppColors.textSub),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0), // slate-200
        thickness: 1,
        space: 1,
      ),
    );
  }
}
