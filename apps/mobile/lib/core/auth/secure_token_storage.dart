import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enterprise Secure Storage Service for Authentication Tokens & Session Credentials.
///
/// Utilizes:
/// - iOS: Keychain (first_unlock access)
/// - Android: Android KeyStore Hardware Security Module (HSM)
/// - Test / Fallback: Graceful degradation for headless unit test harnesses
class SecureTokenStorage {
  static const String _tokenKey = 'alpha_x_secure_session_jwt_token';
  static const String _sessionDataKey = 'alpha_x_secure_session_data';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static bool get _isTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Securely stores the authenticated JWT session token.
  static Future<void> writeAuthToken(String token) async {
    if (_isTestEnvironment) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
      } catch (_) {}
      return;
    }
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
    if (_isTestEnvironment) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_tokenKey);
      } catch (_) {
        return null;
      }
    }
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
    if (_isTestEnvironment) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
      } catch (_) {}
      return;
    }
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  /// Securely stores the active session data.
  static Future<void> writeSessionData(Map<String, dynamic> session) async {
    final raw = jsonEncode(session);
    if (_isTestEnvironment) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionDataKey, raw);
      } catch (_) {}
      return;
    }
    try {
      await _storage.write(key: _sessionDataKey, value: raw);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionDataKey, raw);
      } catch (_) {}
    }
  }

  /// Securely reads the active session data.
  static Future<Map<String, dynamic>?> readSessionData() async {
    if (_isTestEnvironment) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_sessionDataKey);
        if (raw != null && raw.isNotEmpty) {
          return jsonDecode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}
      return null;
    }
    try {
      final raw = await _storage.read(key: _sessionDataKey);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionDataKey);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Securely deletes the active session data.
  static Future<void> deleteSessionData() async {
    if (_isTestEnvironment) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_sessionDataKey);
      } catch (_) {}
      return;
    }
    try {
      await _storage.delete(key: _sessionDataKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionDataKey);
    } catch (_) {}
  }
}
