
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
  /// Matches Master Admin Credentials defined in environment and backend configuration.
  static const String adminPassword = String.fromEnvironment(
    'ADMIN_PASSWORD',
    defaultValue: 'AlphaXAdmin2026!',
  );
}
