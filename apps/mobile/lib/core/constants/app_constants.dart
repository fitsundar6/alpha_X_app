import 'package:alpha_x_gym/core/config/api_config.dart';
export 'package:alpha_x_gym/core/config/api_config.dart';
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

  // API Config (Unified via ApiConfig)
  static String get defaultBaseUrl => ApiConfig.productionUrl;
  static String get defaultLocalhostUrl => ApiConfig.localhostUrl;
  static String get defaultLanUrl => ApiConfig.physicalLanUrl;
  static String get defaultProductionUrl => ApiConfig.productionUrl;

  static String get configuredProductionUrl =>
      const String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String? get customServerUrl => ApiConfig.customServerUrl;
  static set customServerUrl(String? val) => ApiConfig.customServerUrl = val;

  /// Authoritative API base URL
  static String get apiBaseUrl => ApiConfig.baseUrl;

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
