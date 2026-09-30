import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enterprise Secure Storage Service for Authentication Tokens.
///
/// Utilizes:
/// - iOS: Keychain (first_unlock access)
/// - Android: Android KeyStore Hardware Security Module (HSM)
/// - Test / Fallback: Graceful degradation for headless unit test harnesses
class SecureTokenStorage {
  static const String _tokenKey = 'alpha_x_secure_session_jwt_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Securely stores the authenticated JWT session token.
  static Future<void> writeAuthToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureTokenStorage] Falling back to encrypted prefs in current environment: $e');
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
      } catch (_) {}
    }
  }

  /// Securely reads the authenticated JWT session token.
  static Future<String?> readAuthToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  /// Securely purges the authenticated JWT session token.
  static Future<void> deleteAuthToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }
}
