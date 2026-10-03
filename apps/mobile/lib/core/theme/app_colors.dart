import 'package:flutter/material.dart';

/// Athletic Premium Design Tokens
/// Bold, energetic, confident — deep near-black backgrounds + electric-lime neon accent.
class AppColors {
  // ===========================================================================
  // DARK THEME TOKENS (Default)
  // ===========================================================================
  static const Color background = Color(0xFF0A0B0D);
  static const Color surface = Color(0xFF141619);
  static const Color surfaceElevated = Color(0xFF1D2025);
  static const Color surfaceCard = Color(0xFF141619);
  static const Color surfaceGlass = Color(0xE6141619);

  // Borders
  static const Color border = Color(0xFF26292F);
  static const Color borderSubtle = Color(0xFF1D2025);
  static const Color borderActive = Color(0xFFC6FF3A);

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A7B3);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B515D);

  // Primary Accent: Electric Lime
  static const Color primary = Color(0xFFC6FF3A);
  static const Color primaryPressed = Color(0xFFA8E22E);
  static const Color onPrimary = Color(0xFF0A0B0D); // Always dark text on lime, never white

  // Secondary & Accents
  static const Color secondary = Color(0xFF7C5CFF);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFB5B5B);
  static const Color error = Color(0xFFFB5B5B);
  static const Color info = Color(0xFF7C5CFF);

  // Glow
  static const Color glow = Color(0x59C6FF3A); // rgba(198, 255, 58, 0.35)

  // ===========================================================================
  // LIGHT THEME TOKENS
  // ===========================================================================
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFECEEF2);
  static const Color lightBorder = Color(0xFFE6E8EC);
  static const Color lightTextPrimary = Color(0xFF0A0B0D);
  static const Color lightTextSecondary = Color(0xFF5A616E);
  static const Color lightTextMuted = Color(0xFF9AA1AD);
  static const Color lightPrimary = Color(0xFF4AD400);
  static const Color lightPrimaryPressed = Color(0xFF3DB400);
  static const Color lightOnPrimary = Color(0xFF0A0B0D);
  static const Color lightSecondary = Color(0xFF6B46FF);
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightWarning = Color(0xFFD97706);
  static const Color lightDanger = Color(0xFFE23B3B);

  // ===========================================================================
  // GRADIENTS
  // ===========================================================================
  static const LinearGradient gradientEnergy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC6FF3A), Color(0xFF34D399)],
  );

  static const LinearGradient gradientViolet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C5CFF), Color(0xFF4C2FD9)],
  );

  // Gamification & Badges
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  // Backward-compatible aliases for smooth migration across existing screens
  static const Color primaryRed = primary;
  static const Color primaryRedHover = primaryPressed;
  static const Color accentRed = primary;
  static const Color glowRed = glow;
  static const Color statusGreen = success;
  static const Color warningYellow = warning;
}
