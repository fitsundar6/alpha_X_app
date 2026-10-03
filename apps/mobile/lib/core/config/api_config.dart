import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API & Server Configuration for Alpha X Gym.
///
/// Designed to support:
/// 1. Android physical phone (via Windows PC LAN IPv4)
/// 2. iPhone physical device (via Windows PC LAN IPv4 with iOS ATS compliance)
/// 3. Android emulator (10.0.2.2)
/// 4. Local Windows development & Flutter Web (localhost:5000)
/// 5. Production live server (https://api.alphaxgym.com/api/v1)
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

  /// Load persisted server URL from SharedPreferences at startup
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        final normalized = normalizeUrl(saved.trim());
        // Prune stale local development IPs only in release mode
        final isLocalAddress = normalized.contains('10.0.2.2') ||
            normalized.contains('127.0.0.1') ||
            normalized.contains('localhost') ||
            normalized.contains('192.168.');
        if (isLocalAddress && kReleaseMode) {
          debugPrint('[API CONFIG] Pruning stale local server URL in release: $normalized -> using production $productionUrl');
          customServerUrl = null;
          await prefs.remove(storageKey);
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
  /// 6. Desktop (Windows, macOS, Linux) or Web development -> [localhostUrl]
  /// 7. Mobile platforms (iOS and Android) -> [productionUrl] (HTTPS production cloud backend)
  static String get baseUrl {
    // 1. Runtime override
    if (customServerUrl != null && customServerUrl!.trim().isNotEmpty) {
      return normalizeUrl(customServerUrl!);
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
    final env = _envTarget.trim().toLowerCase();
    if (env == 'prod' || env == 'production') {
      return productionUrl;
    }
    if (env == 'emulator') {
      return emulatorUrl;
    }
    if (env == 'local' || env == 'localhost' || env == 'dev') {
      return localhostUrl;
    }

    // 5. Desktop (Windows, macOS, Linux) or Web development -> localhostUrl
    if (kDebugMode || !kReleaseMode) {
      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux) {
        return localhostUrl;
      }
    }

    // 6. Unified Production Target for release builds
    return productionUrl;
  }
}
