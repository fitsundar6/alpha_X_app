import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

export 'user_role.dart';

class AppConstants {
  // App Identity
  static const String appName = 'Alpha X Gym';
  static const String appTagline = 'Strength • Conditioning • Boxing • Transformation';
  static const String appMotto = 'Train Strong. Move Better. Become Better.';
  static const String appVersion = '1.0.0';

  // Assets
  static const String logoPath = 'assets/images/alpha_x_logo.png';
  static const String appIconPath = 'assets/images/alpha_x_app_icon.png';

  // API Config
  static const String defaultBaseUrl = 'http://10.0.2.2:5000/api/v1'; // Android Emulator default
  static const String defaultLocalhostUrl = 'http://localhost:5000/api/v1'; // Windows / iOS / Web
  static const String defaultLanUrl = 'http://192.168.1.5:5000/api/v1'; // Local Wi-Fi host machine default for physical Android phones

  /// Production Cloud Backend Base URL (for release APK on physical devices).
  /// Can be overridden at build time via:
  ///   flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.com/api/v1
  static const String configuredProductionUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Runtime custom server URL override (stored in SharedPreferences)
  static String? customServerUrl;

  /// Dynamically resolves the API base URL depending on runtime platform and configuration.
  /// 1. Prioritizes runtime customServerUrl (persisted in SharedPreferences)
  /// 2. Prioritizes compile-time --dart-define=API_BASE_URL=... if provided
  /// 3. In Web / Desktop: connects to localhost:5000
  /// 4. In Android release mode with configuredProductionUrl: connects to production
  /// 5. In Android physical device / release mode: connects to LAN IP (192.168.1.5:5000)
  /// 6. In Android emulator: connects to 10.0.2.2:5000
  static String get apiBaseUrl {
    if (customServerUrl != null && customServerUrl!.trim().isNotEmpty) {
      return customServerUrl!.trim();
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.trim().isNotEmpty) {
      return envUrl.trim();
    }
    if (configuredProductionUrl.trim().isNotEmpty) {
      return configuredProductionUrl.trim();
    }
    if (kIsWeb) return defaultLocalhostUrl;
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return defaultLocalhostUrl;
      }
      if (Platform.isAndroid) {
        if (kReleaseMode) {
          return defaultLanUrl;
        }
        return defaultBaseUrl;
      }
    } catch (_) {}
    return defaultLocalhostUrl;
  }

  // Storage Keys
  static const String serverUrlKey = 'alpha_x_custom_server_url';
  static const String tokenKey = 'alpha_x_access_token';
  static const String refreshTokenKey = 'alpha_x_refresh_token';
  static const String userRoleKey = 'alpha_x_user_role';
  static const String onboardingCompleteKey = 'alpha_x_onboarding_completed';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
