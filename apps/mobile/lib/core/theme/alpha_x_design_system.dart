import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Alpha X Gym - Core Color System
/// Deep black surfaces + gold brand accent + crisp typography
class AlphaXColors {
  // Dark Background & Surfaces
  static const Color background = AppColors.background;
  static const Color secondaryBackground = AppColors.secondaryBackground;
  static const Color surface = AppColors.surface;
  static const Color card = AppColors.card;
  static const Color surfaceCard = AppColors.surfaceCard;
  static const Color secondaryCard = AppColors.secondaryCard;
  static const Color surfaceElevated = AppColors.surfaceElevated;
  static const Color surfaceGlass = AppColors.surfaceGlass;

  // Primary Gold Accent (CTA, highlights, active states)
  static const Color primary = AppColors.primary;
  static const Color primaryGold = AppColors.primaryGold;
  static const Color brightGold = AppColors.brightGold;
  static const Color lightGold = AppColors.lightGold;
  static const Color primaryPressed = AppColors.primaryPressed;
  static const Color onPrimary = AppColors.onPrimary;
  static const Color glow = AppColors.glow;

  // Backward compatibility aliases
  static const Color redAccent = AppColors.primary;
  static const Color redAccentHover = AppColors.primaryPressed;
  static const Color redGlow = AppColors.glow;
  static const Color redSubtle = Color(0x26D4AF37);

  // High-Contrast Borders
  static const Color border = AppColors.border;
  static const Color borderSubtle = AppColors.borderSubtle;
  static const Color borderActive = AppColors.borderActive;

  // Typography
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textTertiary = AppColors.textTertiary;
  static const Color textMuted = AppColors.textMuted;
  static const Color textDisabled = AppColors.textDisabled;

  // Functional Status
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;
  static const Color danger = AppColors.danger;
  static const Color info = AppColors.info;

  // Metal Badges
  static const Color gold = AppColors.gold;
  static const Color silver = AppColors.silver;
  static const Color bronze = AppColors.bronze;

  // Gradients
  static const LinearGradient gradientGold = AppColors.gradientGold;
  static const LinearGradient gradientEnergy = AppColors.gradientEnergy;
  static const LinearGradient gradientViolet = AppColors.gradientViolet;
}

/// Alpha X Gym - 8pt Spacing Tokens
class AlphaXSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Screen standard padding
  static const double screenPadding = 20.0;
}

/// Alpha X Gym - Shape & Corner Radius Tokens
/// Card radius: 14-18, Buttons: 14-16, Dialogs: 18-20
class AlphaXRadius {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 14.0;
  static const double lg = 16.0;
  static const double xl = 18.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  static BorderRadius get roundedXs => BorderRadius.circular(xs);
  static BorderRadius get roundedSm => BorderRadius.circular(sm);
  static BorderRadius get roundedMd => BorderRadius.circular(md);
  static BorderRadius get roundedLg => BorderRadius.circular(lg);
  static BorderRadius get roundedXl => BorderRadius.circular(xl);
  static BorderRadius get roundedXxl => BorderRadius.circular(xxl);
  static BorderRadius get roundedFull => BorderRadius.circular(full);
}

/// Alpha X Gym - Controlled Shadows System
class AlphaXShadows {
  static List<BoxShadow> darkCard = [
    BoxShadow(
      color: Colors.black.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> darkCardElevated = [
    BoxShadow(
      color: Colors.black.withOpacity(0.45),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> lightCard = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> lightCardElevated = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> goldGlow = [
    const BoxShadow(
      color: Color(0x33D4AF37),
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 4),
    ),
  ];
}

/// Alpha X Gym - Athletic Premium Typography System - Poppins (Design Specification)
/// Headings & Body: Poppins (Aa)
class AlphaXTypography {
  static const String headingFont = 'Poppins';
  static const String bodyFont = 'Poppins';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 34.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AlphaXColors.textPrimary,
    height: 1.15,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: headingFont,
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AlphaXColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: headingFont,
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: headingFont,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AlphaXColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    color: AlphaXColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AlphaXColors.textTertiary,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: bodyFont,
    fontSize: 11.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AlphaXColors.textMuted,
  );

  static const TextStyle metricLarge = TextStyle(
    fontFamily: headingFont,
    fontSize: 48.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AppColors.primary,
  );

  static const TextStyle metricMedium = TextStyle(
    fontFamily: headingFont,
    fontSize: 32.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AlphaXColors.textPrimary,
  );

  static const TextStyle tag = TextStyle(
    fontFamily: bodyFont,
    fontSize: 11.0,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.primary,
  );
}

// Global Aliases requested in theme architecture
typedef AppTextStyles = AlphaXTypography;
typedef AppSpacing = AlphaXSpacing;
typedef AppRadius = AlphaXRadius;
typedef AppShadows = AlphaXShadows;
