import 'package:flutter/material.dart';

/// Alpha X Gym - Official Design Tokens
/// Cinematic, Powerful, Premium Athletic Style
/// Dark Mode (Primary Identity) & Light Mode (Premium Clean Style)
class AppColors {
  // ===========================================================================
  // DARK MODE TOKENS (Official Alpha X Design Guide)
  // ===========================================================================
  static const Color background = Color(0xFF0A0A0A);          // Deep Black #0A0A0A (Background)
  static const Color secondaryBackground = Color(0xFF151515); // Charcoal #151515
  static const Color surface = Color(0xFF151515);
  static const Color card = Color(0xFF151515);                 // Charcoal #151515 (Cards)
  static const Color surfaceCard = Color(0xFF151515);
  static const Color secondaryCard = Color(0xFF1E1E1E);        // Slate #1E1E1E (Secondary)
  static const Color surfaceElevated = Color(0xFF1E1E1E);      // Slate #1E1E1E
  static const Color surfaceGlass = Color(0xF0151515);

  // Borders
  static const Color border = Color(0xFF242424);               // Dark border
  static const Color borderSubtle = Color(0xFF1E1E1E);         // Subtle separator
  static const Color borderActive = Color(0xFFD4AF37);         // Active Gold border

  // Primary Brand Accent: Gold
  static const Color primary = Color(0xFFD4AF37);              // Gold #D4AF37 (Accent)
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color brightGold = Color(0xFFF2C94C);             // Bright Gold #F2C94C
  static const Color lightGold = Color(0xFFF5E6B3);              // Light Gold #F5E6B3 (Highlights)
  static const Color primaryPressed = Color(0xFFC49E27);
  static const Color onPrimary = Color(0xFF0A0A0A);              // Deep Black text on gold button

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);            // White #FFFFFF (Text)
  static const Color textSecondary = Color(0xFFA0A0A0);          // Gray #A0A0A0 (Secondary Text)
  static const Color textMuted = Color(0xFF707070);              // Muted #707070
  static const Color textTertiary = Color(0xFFA0A0A0);
  static const Color textDisabled = Color(0xFF555555);           // Disabled #555555

  // Functional Status
  static const Color success = Color(0xFF22C55E);                // Green #22C55E (Success)
  static const Color warning = Color(0xFFF59E0B);                // Orange #F59E0B (Warning)
  static const Color danger = Color(0xFFEF4444);                 // Red #EF4444 (Error)
  static const Color error = Color(0xFFEF4444);                  // Red #EF4444 (Error)
  static const Color info = Color(0xFF3B82F6);                   // Info #3B82F6
  static const Color secondary = Color(0xFF3B82F6);

  // Subtle Glow
  static const Color glow = Color(0x33D4AF37);                   // Subtle gold glow

  // ===========================================================================
  // LIGHT MODE TOKENS (Premium Alpha X Style)
  // ===========================================================================
  static const Color lightBackground = Color(0xFFF7F7F5);        // Primary background #F7F7F5
  static const Color lightSecondaryBackground = Color(0xFFFFFFFF);// Secondary background #FFFFFF
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);             // Card #FFFFFF
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSecondaryCard = Color(0xFFF1F1EE);     // Secondary card #F1F1EE
  static const Color lightSurfaceElevated = Color(0xFFF1F1EE);
  static const Color lightBorder = Color(0xFFE2E2DE);           // Border #E2E2DE
  static const Color lightBorderActive = Color(0xFFB89620);

  // Light Mode Gold
  static const Color lightPrimary = Color(0xFFB89620);          // Primary Gold #B89620
  static const Color lightBrightGold = Color(0xFFC9A227);       // Bright Gold #C9A227
  static const Color lightLightGold = Color(0xFF8A7218);        // Light Gold #8A7218
  static const Color lightPrimaryPressed = Color(0xFFC9A227);
  static const Color lightOnPrimary = Color(0xFF111111);        // Dark text on gold button

  // Light Mode Typography
  static const Color lightTextPrimary = Color(0xFF111111);      // Primary Text #111111
  static const Color lightTextSecondary = Color(0xFF5F5F5F);    // Secondary Text #5F5F5F
  static const Color lightTextMuted = Color(0xFF999999);        // Disabled Text #999999
  static const Color lightTextDisabled = Color(0xFF999999);

  // Light Mode Functional Status
  static const Color lightSuccess = Color(0xFF16A34A);          // Success #16A34A
  static const Color lightWarning = Color(0xFFD97706);          // Warning #D97706
  static const Color lightDanger = Color(0xFFDC2626);           // Error #DC2626
  static const Color lightError = Color(0xFFDC2626);            // Error #DC2626
  static const Color lightInfo = Color(0xFF2563EB);             // Info #2563EB
  static const Color lightSecondary = Color(0xFF2563EB);

  // Subtle Light Glow
  static const Color lightGlow = Color(0x33B89620);

  // ===========================================================================
  // GRADIENTS
  // ===========================================================================
  static const LinearGradient gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4AF37), Color(0xFFF2C94C)],
  );

  static const LinearGradient gradientEnergy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4AF37), Color(0xFFF2C94C)],
  );

  static const LinearGradient gradientViolet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  );

  // Gamification & Badges
  static const Color gold = Color(0xFFD4AF37);
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
