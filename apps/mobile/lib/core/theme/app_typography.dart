import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Athletic Premium Typography System - Poppins (Design System Specification)
/// Headings & Body: Poppins (Aa)
/// Implemented as compile-time constants for optimal 60fps performance and const widget tree compatibility.
class AppTypography {
  static const String headingFont = 'Poppins';
  static const String bodyFont = 'Poppins';

  // Display styles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 34.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: headingFont,
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // Headlines
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: headingFont,
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: headingFont,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Titles
  static const TextStyle titleLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: bodyFont,
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );

  // Labels & Buttons
  static const TextStyle labelLarge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.onPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: bodyFont,
    fontSize: 11.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.textTertiary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: bodyFont,
    fontSize: 11.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );

  // Athletic Metric Numerals (Big stat numbers: 40-56 bold in primary)
  static const TextStyle metricLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 48.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AppColors.primary,
    height: 1.1,
  );

  static const TextStyle metricMedium = TextStyle(
    fontFamily: headingFont,
    fontSize: 32.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle metricSmall = TextStyle(
    fontFamily: headingFont,
    fontSize: 20.0,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  // Badges & Tags
  static const TextStyle tag = TextStyle(
    fontFamily: bodyFont,
    fontSize: 11.0,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.primary,
  );
}
