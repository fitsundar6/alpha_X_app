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
    defaultValue: '',
  );

  /// Master Administrator Password
  /// In release builds, this defaults to an empty string so no administrator
  /// credentials are baked into the compiled client binary.
  static const String adminPassword = String.fromEnvironment(
    'ADMIN_PASSWORD',
    defaultValue: '',
  );
}
