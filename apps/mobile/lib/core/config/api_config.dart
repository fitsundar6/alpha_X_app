import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API & Server Configuration for Alpha X Gym.
///
/// Designed to support:
/// 1. Android physical phone (via Windows PC LAN IPv4)
/// 2. iPhone physical device (via Windows PC LAN IPv4 with iOS ATS compliance)
/// 3. Android emulator (10.0.2.2)
/// 4. Local Windows development & Flutter Web (localhost:5000 when ENV=local)
/// 5. Production live server (https://alpha-x-app.vercel.app/api/v1)
///
/// Features dynamic URL normalization, compile-time dart-define flags,
/// and runtime user-override persistence in SharedPreferences.
class ApiConfig {
  /// DEFAULT HOST IP FOR PHYSICAL MOBILE DEVICES (iPhone & Android)
  ///
  /// Set this to your Windows PC's LAN IPv4 address (found via `ipconfig`).
  /// Currently detected: 192.168.1.5
  static const String defaultHostIp = '192.168.1.5';

  /// Backend server TCP listening port
  static const int defaultPort = 5000;

  /// Default API subpath prefix
  static const String defaultApiPath = '/api/v1';

  // --- Preconfigured Environment Targets ---

  /// Physical Mobile Device default (iPhone / Android connecting to host machine)
  static const String physicalLanUrl = 'http://$defaultHostIp:$defaultPort$defaultApiPath';

  /// Android Emulator default (Android QEMU loopback virtual network)
  static const String emulatorUrl = 'http://10.0.2.2:$defaultPort$defaultApiPath';

  /// Localhost default (Windows desktop / macOS / Linux / Flutter Web)
  static const String localhostUrl = 'http://localhost:$defaultPort$defaultApiPath';

  /// Production Cloud Backend Base URL (Live Vercel deployment)
  static const String productionUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://alpha-x-app.vercel.app/api/v1',
  );

  // --- Storage & Runtime State ---

  /// SharedPreferences key for persisting runtime custom server override
  static const String storageKey = 'alpha_x_custom_server_url';

  /// In-memory cache of user-configured runtime server URL
  static String? customServerUrl;

  // --- Test & Environment Overrides ---
  @visibleForTesting
  static TargetPlatform? platformOverride;

  @visibleForTesting
  static bool? isReleaseModeOverride;

  @visibleForTesting
  static bool? isWebOverride;

  @visibleForTesting
  static String? envTargetOverride;

  /// Effective target platform taking test overrides into account
  static TargetPlatform get effectivePlatform => platformOverride ?? defaultTargetPlatform;

  /// Effective release mode flag taking test overrides into account
  static bool get effectiveIsReleaseMode => isReleaseModeOverride ?? kReleaseMode;

  /// Effective web platform flag taking test overrides into account
  static bool get effectiveIsWeb => isWebOverride ?? kIsWeb;

  /// Effective environment target string taking test overrides into account
  static String get effectiveEnvTarget => envTargetOverride ?? _envTarget;

  /// Resets test-only overrides back to standard runtime values
  @visibleForTesting
  static void resetTestOverrides() {
    platformOverride = null;
    isReleaseModeOverride = null;
    isWebOverride = null;
    envTargetOverride = null;
  }

  /// Determines whether a given URL points to an unusable or obsolete loopback address.
  ///
  /// Criteria:
  /// 1. Mobile devices (Android/iOS physical devices and emulators) can never reach a host machine
  ///    via `localhost` or `127.0.0.1` because the phone's loopback points to itself.
  /// 2. Production/release builds (`kReleaseMode == true`) must never connect to loopback addresses.
  /// 3. On Web and Desktop, if no explicit local development flag (`ENV=local|dev|localhost`) is set,
  ///    an obsolete `localhost:5000` override is pruned to prevent breaking production cloud connectivity.
  /// 4. Valid custom LAN URLs (e.g. `http://192.168.x.x:5000`) and custom remote URLs (`https://...`)
  ///    are NEVER considered loopback and are strictly preserved.
  static bool isInvalidLoopback(String url) {
    final lower = url.toLowerCase();
    final isLoopback = lower.contains('localhost') || lower.contains('127.0.0.1');
    if (!isLoopback) return false;

    // Mobile platforms cannot use loopback to reach PC host
    final isMobile = !effectiveIsWeb &&
        (effectivePlatform == TargetPlatform.android || effectivePlatform == TargetPlatform.iOS);
    if (isMobile) return true;

    // Release builds must never use localhost on any platform
    if (effectiveIsReleaseMode) return true;

    // On Web / Desktop without explicit local dev environment flag, prune stale localhost:5000
    final env = effectiveEnvTarget.trim().toLowerCase();
    final isExplicitLocalDev = env == 'local' || env == 'localhost' || env == 'dev';
    if (!isExplicitLocalDev && (lower.contains('localhost:5000') || lower.contains('127.0.0.1:5000'))) {
      return true;
    }

    return false;
  }

  /// Load persisted server URL from SharedPreferences at startup
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey) ?? prefs.getString('custom_api_url');
      if (saved != null && saved.trim().isNotEmpty) {
        final normalized = normalizeUrl(saved.trim());
        if (isInvalidLoopback(normalized)) {
          debugPrint('[API CONFIG] Pruning obsolete/unusable loopback server URL: $normalized -> resetting to production $productionUrl');
          customServerUrl = null;
          await prefs.remove(storageKey);
          await prefs.remove('custom_api_url');
        } else {
          customServerUrl = normalized;
        }
      }
    } catch (_) {}
  }

  /// Persist a custom server URL override from UI (e.g. ServerConfigDialog)
  static Future<void> setCustomUrl(String? rawUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      customServerUrl = null;
      await prefs.remove(storageKey);
    } else {
      final normalized = normalizeUrl(rawUrl);
      customServerUrl = normalized;
      await prefs.setString(storageKey, normalized);
    }
  }

  /// Cleans and standardizes any raw user input or environment variable:
  /// - Defaults to productionUrl if input is empty
  /// - Fixes typos like `/api?v1` -> `/api/v1`
  /// - Prepends `http://` if no protocol is given
  /// - Strips trailing slashes
  /// - Guarantees `/api/v1` path is appended if omitted
  static String normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return productionUrl;

    // Fix query-string typo (/api?v1 -> /api/v1)
    url = url.replaceAll('/api?v1', '/api/v1');
    url = url.replaceAll('?v1', '/v1');

    // Prepend http:// scheme if user just typed an IP:port or hostname
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    // Strip trailing slashes
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // Ensure path terminates with /api/v1
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path.trim();
      if (path.isEmpty || path == '/') {
        url = '$url/api/v1';
      } else if (path == '/api') {
        url = '$url/v1';
      } else if (!path.endsWith('/api/v1') && !path.endsWith('/v1')) {
        url = '$url/api/v1';
      }
    }

    return url;
  }

  /// Compile-time environment variable overrides:
  /// e.g. flutter run --dart-define=API_BASE_URL=https://alpha-x-app.vercel.app/api/v1
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _envServerIp = String.fromEnvironment('SERVER_IP', defaultValue: '');
  static const String _envLanIp = String.fromEnvironment('LAN_IP', defaultValue: '');
  static const String _envTarget = String.fromEnvironment('ENV', defaultValue: '');

  /// Dynamically resolves the authoritative API base URL.
  ///
  /// Resolution Hierarchy:
  /// 1. User runtime custom override (saved in SharedPreferences via Server Settings dialog)
  /// 2. Compile-time `--dart-define=API_BASE_URL=...`
  /// 3. Compile-time `--dart-define=SERVER_IP=...` or `--dart-define=LAN_IP=...`
  /// 4. Compile-time `--dart-define=ENV=production` -> [productionUrl]
  /// 5. Compile-time `--dart-define=ENV=emulator` -> [emulatorUrl]
  /// 6. Compile-time `--dart-define=ENV=local` / `dev` / `localhost` -> [localhostUrl]
  /// 7. Compile-time `--dart-define=ENV=lan` / `physical` -> [physicalLanUrl]
  /// 8. Default for ALL platforms (Mobile, Web, Desktop) -> [productionUrl] (HTTPS production cloud backend)
  static String get baseUrl {
    // 1. Runtime override (if not an unusable loopback)
    if (customServerUrl != null && customServerUrl!.trim().isNotEmpty) {
      final normalized = normalizeUrl(customServerUrl!);
      if (!isInvalidLoopback(normalized)) {
        return normalized;
      }
    }

    // 2. Explicit compile-time API URL
    if (_envApiBaseUrl.trim().isNotEmpty) {
      return normalizeUrl(_envApiBaseUrl.trim());
    }

    // 3. Explicit compile-time IP
    final ip = _envServerIp.isNotEmpty ? _envServerIp : _envLanIp;
    if (ip.trim().isNotEmpty) {
      return normalizeUrl('http://${ip.trim()}:$defaultPort/api/v1');
    }

    // 4. Environment flags
    final env = effectiveEnvTarget.trim().toLowerCase();
    if (env == 'prod' || env == 'production') {
      return productionUrl;
    }
    if (env == 'emulator') {
      return emulatorUrl;
    }
    if (env == 'local' || env == 'localhost' || env == 'dev') {
      return localhostUrl;
    }
    if (env == 'lan' || env == 'physical') {
      return physicalLanUrl;
    }

    // 5. Default across all platforms (Android, iOS, Web, Desktop) is the verified HTTPS production cloud backend
    return productionUrl;
  }
}
