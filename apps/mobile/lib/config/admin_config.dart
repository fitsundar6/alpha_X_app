import 'package:flutter/foundation.dart';

/// ============================================================================
/// ALPHA X GYM — MASTER ADMINISTRATOR CONFIGURATION
/// ============================================================================
///
/// In production release builds, admin credentials are authenticated authoritatively
/// against the secure backend API over HTTPS. No admin passwords are hardcoded in the
/// compiled binary.
/// ============================================================================
class AdminConfig {
  /// Master Administrator Email
  static const String adminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: 'fitsundar6@gmail.com',
  );

  /// Master Administrator Password
  /// Strictly empty in production builds to prevent secret extraction from binary.
  /// Development/debug fallback is preserved for offline dev and test suites.
  static const String adminPassword = String.fromEnvironment(
    'ADMIN_PASSWORD',
    defaultValue: kDebugMode ? 'AlphaXAdmin2026' : '',
  );
}
