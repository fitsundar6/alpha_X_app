import 'package:flutter/material.dart';

/// Alpha X Gym - Official Design Tokens
/// Cinematic, Powerful, Premium Athletic Style
/// Dark Mode (Primary Identity) & Light Mode (Premium Clean Style)
class AppColors {
  // ===========================================================================
  // DARK MODE TOKENS (Clean Premium Minimalist Black & White Theme)
  // ===========================================================================
  static const Color background = Color(0xFF000000);          // Pure Black #000000 (Primary Background)
  static const Color secondaryBackground = Color(0xFF171717); // Dark Charcoal #171717 (Secondary Background)
  static const Color surface = Color(0xFF171717);             // Dark Charcoal #171717
  static const Color card = Color(0xFF171717);                // Dark Charcoal #171717 (Cards)
  static const Color surfaceCard = Color(0xFF171717);         // Dark Charcoal #171717
  static const Color secondaryCard = Color(0xFF202020);        // Dark Charcoal #202020 (Modals & Secondary Buttons)
  static const Color surfaceElevated = Color(0xFF202020);      // Dark Charcoal #202020
  static const Color surfaceGlass = Color(0xF0171717);

  // Borders & Dividers
  static const Color border = Color(0xFF444444);               // Subtle Grey #444444 (Borders & Dividers)
  static const Color borderSubtle = Color(0xFF333333);         // Subtle separator
  static const Color borderActive = Color(0xFFFFFFFF);         // Active White border

  // Primary Brand Accent: Crisp White (Monochrome Athletic Style)
  static const Color primary = Color(0xFFFFFFFF);              // White #FFFFFF (Primary buttons & accents)
  static const Color primaryGold = Color(0xFFFFFFFF);
  static const Color brightGold = Color(0xFFFFFFFF);
  static const Color lightGold = Color(0xFFE5E5E5);
  static const Color primaryPressed = Color(0xFFE5E5E5);
  static const Color onPrimary = Color(0xFF000000);            // Pure Black #000000 text on white button

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);          // White #FFFFFF (Primary text)
  static const Color textSecondary = Color(0xFFA0A0A0);        // Soft Grey #A0A0A0 (Secondary text)
  static const Color textMuted = Color(0xFF707070);            // Muted #707070
  static const Color textTertiary = Color(0xFFA0A0A0);         // Soft Grey #A0A0A0
  static const Color textDisabled = Color(0xFF888888);         // Disabled Muted Grey #888888
  static const Color disabledBackground = Color(0xFF2A2A2A);   // Disabled Dark Grey #2A2A2A
  static const Color disabledText = Color(0xFF888888);         // Disabled Muted Grey #888888

  // Functional Status (Preserved for status communications)
  static const Color success = Color(0xFF22C55E);              // Green #22C55E (Success)
  static const Color warning = Color(0xFFF59E0B);              // Orange #F59E0B (Warning)
  static const Color danger = Color(0xFFEF4444);               // Red #EF4444 (Error)
  static const Color error = Color(0xFFEF4444);                // Red #EF4444 (Error)
  static const Color info = Color(0xFF3B82F6);                 // Info #3B82F6
  static const Color secondary = Color(0xFF3B82F6);

  // Subtle Glow
  static const Color glow = Color(0x22FFFFFF);                 // Subtle white glow

  // ===========================================================================
  // LIGHT MODE TOKENS (Premium Clean Style)
  // ===========================================================================
  static const Color lightBackground = Color(0xFFFFFFFF);        // Primary background #FFFFFF
  static const Color lightSecondaryBackground = Color(0xFFF7F7F7);// Secondary background #F7F7F7
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);             // Card #FFFFFF
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSecondaryCard = Color(0xFFF0F0F0);     // Secondary card #F0F0F0
  static const Color lightSurfaceElevated = Color(0xFFF0F0F0);
  static const Color lightBorder = Color(0xFFE5E5E5);           // Border #E5E5E5
  static const Color lightBorderActive = Color(0xFF000000);

  // Light Mode Monochrome Accent
  static const Color lightPrimary = Color(0xFF000000);          // Primary Black #000000
  static const Color lightBrightGold = Color(0xFF222222);
  static const Color lightLightGold = Color(0xFF444444);
  static const Color lightPrimaryPressed = Color(0xFF333333);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);        // Pure White text on black button

  // Light Mode Typography
  static const Color lightTextPrimary = Color(0xFF000000);      // Primary Text #000000
  static const Color lightTextSecondary = Color(0xFF666666);    // Secondary Text #666666
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
  static const Color lightGlow = Color(0x1A000000);

  // ===========================================================================
  // GRADIENTS
  // ===========================================================================
  static const LinearGradient gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFCCCCCC)],
  );

  static const LinearGradient gradientEnergy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFCCCCCC)],
  );

  static const LinearGradient gradientViolet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF333333), Color(0xFF171717)],
  );

  // Gamification & Badges
  static const Color gold = Color(0xFFFFFFFF);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  // Backward-compatible aliases for smooth migration across existing screens
  static const Color primaryRed = primary;
  static const Color onPrimaryRed = onPrimary;
  static const Color primaryRedHover = primaryPressed;
  static const Color accentRed = primary;
  static const Color glowRed = glow;
  static const Color statusGreen = success;
  static const Color warningYellow = warning;
}
