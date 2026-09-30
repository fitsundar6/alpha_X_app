import 'package:flutter/material.dart';

/// Alpha X Gym - Core Color System
/// Pure Black + Soft Dark Surfaces + White Typography + Subtle Red Accent
class AlphaXColors {
  // Pure Black & Dark Surfaces
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF101010);
  static const Color surfaceCard = Color(0xFF161616);
  static const Color surfaceElevated = Color(0xFF1E1E1E);
  static const Color surfaceGlass = Color(0xCC161616);

  // Subtle Red Accent (Luxury athletic intensity)
  static const Color redAccent = Color(0xFFE50914);
  static const Color redAccentHover = Color(0xFFCC0812);
  static const Color redGlow = Color(0x33E50914);
  static const Color redSubtle = Color(0x1AE50914);

  // High-Contrast Borders
  static const Color border = Color(0xFF242424);
  static const Color borderSubtle = Color(0xFF1A1A1A);
  static const Color borderActive = Color(0xFFE50914);

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA5A5A5);
  static const Color textTertiary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF4A4A4A);

  // Functional Status
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  // Metal Badges
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFE0E0E0);
  static const Color bronze = Color(0xFFCD7F32);
}

/// Alpha X Gym - Spacing Tokens
class AlphaXSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Alpha X Gym - Corner Radius Tokens
class AlphaXRadius {
  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 18.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  static BorderRadius get roundedXs => BorderRadius.circular(xs);
  static BorderRadius get roundedSm => BorderRadius.circular(sm);
  static BorderRadius get roundedMd => BorderRadius.circular(md);
  static BorderRadius get roundedLg => BorderRadius.circular(lg);
  static BorderRadius get roundedXl => BorderRadius.circular(xl);
  static BorderRadius get roundedFull => BorderRadius.circular(full);
}

/// Alpha X Gym - Typography System
class AlphaXTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 36.0,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    color: AlphaXColors.textPrimary,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AlphaXColors.textPrimary,
    height: 1.15,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.0,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AlphaXColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    color: AlphaXColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AlphaXColors.textTertiary,
  );

  static const TextStyle metricLarge = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AlphaXColors.textPrimary,
    fontFamily: 'monospace',
  );

  static const TextStyle metricMedium = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w800,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle tag = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AlphaXColors.redAccent,
  );
}
