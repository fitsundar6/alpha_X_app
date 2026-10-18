import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/models/app_version_info.dart';
import 'package:alpha_x_gym/core/widgets/app_update_dialog.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

/// Result summary of an application update check.
class AppUpdateCheckResult {
  final bool hasUpdate;
  final bool isForced;
  final String currentVersion;
  final AppVersionInfo? info;
  final String? errorMessage;

  const AppUpdateCheckResult({
    required this.hasUpdate,
    required this.isForced,
    required this.currentVersion,
    this.info,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
}

/// Centralized In-App Version & Update Management Service.
/// Handles remote version polling, semantic comparison, update prompt presentation,
/// and external store launcher actions for both Clients and Admins.
class AppVersionService {
  static final AppVersionService _instance = AppVersionService._internal();
  static AppVersionService get instance => _instance;

  static const String _keyDismissedVersion = 'alpha_x_dismissed_update_version';
  static const Duration _networkTimeout = Duration(seconds: 6);

  http.Client? _customHttpClient;
  SharedPreferences? _customPrefs;
  String? _inMemoryDismissedVersion;

  /// Visible for testing constructor
  AppVersionService({http.Client? httpClient, SharedPreferences? prefs}) {
    _customHttpClient = httpClient;
    _customPrefs = prefs;
  }

  AppVersionService._internal();

  /// Authoritative locally installed application version string
  String get currentVersion => AppConstants.appVersion;

  /// Fetches latest version metadata from backend API.
  /// Designed with fail-safe fallbacks: returns null without crashing or throwing
  /// so offline workouts, caching, and local training never get disrupted.
  Future<AppVersionInfo?> fetchVersionInfo({http.Client? client}) async {
    final httpClient = client ?? _customHttpClient ?? http.Client();

    try {
      // Normalize base URL
      var base = ApiConfig.baseUrl;
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }

      final uri = Uri.parse('$base/app/version');
      final response = await httpClient
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(_networkTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final payload = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded)
            : decoded;

        if (payload is Map<String, dynamic>) {
          return AppVersionInfo.fromJson(payload);
        }
      } else {
        debugPrint(
            '[APP VERSION] Remote server responded with HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[APP VERSION] Failed to fetch version info: $e');
    }

    return null;
  }

  /// Evaluates whether an update is available or mandatory for the currently running app.
  Future<AppUpdateCheckResult> checkForUpdate({
    String? currentVersionOverride,
    http.Client? client,
  }) async {
    final runningVersion = currentVersionOverride ?? currentVersion;

    try {
      final info = await fetchVersionInfo(client: client);
      if (info == null) {
        return AppUpdateCheckResult(
          hasUpdate: false,
          isForced: false,
          currentVersion: runningVersion,
          errorMessage: 'Unable to reach version server',
        );
      }

      final hasUpdate = info.isUpdateAvailable(runningVersion);
      final isForced = info.isForceUpdateRequired(runningVersion);

      return AppUpdateCheckResult(
        hasUpdate: hasUpdate,
        isForced: isForced,
        currentVersion: runningVersion,
        info: info,
      );
    } catch (err) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        isForced: false,
        currentVersion: runningVersion,
        errorMessage: err.toString(),
      );
    }
  }

  /// Checks if a non-mandatory version update has already been dismissed by the user.
  Future<bool> isVersionDismissed(String version) async {
    if (_inMemoryDismissedVersion == version) return true;

    try {
      final prefs = _customPrefs ?? await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyDismissedVersion);
      return saved == version;
    } catch (_) {
      return false;
    }
  }

  /// Marks a specific optional update version as dismissed so it doesn't repeatedly popup.
  Future<void> dismissUpdate(String version) async {
    _inMemoryDismissedVersion = version;
    try {
      final prefs = _customPrefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_keyDismissedVersion, version);
    } catch (_) {}
  }

  /// Clears dismissed version state (e.g. for testing or manual user check)
  Future<void> clearDismissedVersion() async {
    _inMemoryDismissedVersion = null;
    try {
      final prefs = _customPrefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_keyDismissedVersion);
    } catch (_) {}
  }

  /// Launches platform-specific store or download URL via system browser/store
  Future<bool> launchUpdate(String url) async {
    if (url.trim().isEmpty) return false;

    try {
      final uri = Uri.tryParse(url.trim());
      if (uri != null) {
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('[APP VERSION] Failed to launch update URL: $e');
    }

    return false;
  }

  /// Automatically displays update dialog if required or available.
  /// When [forcePrompt] is true, ignores previous dismissal (useful for manual "Check for Updates" button).
  Future<bool> promptUpdateIfNeeded(
    BuildContext context, {
    bool forcePrompt = false,
    String? currentVersionOverride,
    http.Client? client,
    VoidCallback? onDismiss,
  }) async {
    final result = await checkForUpdate(
      currentVersionOverride: currentVersionOverride,
      client: client,
    );

    if (!result.hasUpdate || result.info == null || !context.mounted) {
      return false;
    }

    final info = result.info!;
    final runningVersion = result.currentVersion;

    // If update is optional and was already dismissed, do not disturb user unless explicitly forced
    if (!result.isForced && !forcePrompt) {
      final dismissed = await isVersionDismissed(info.latestVersion);
      if (dismissed) return false;
    }

    if (!context.mounted) return false;

    await AppUpdateDialog.show(
      context,
      info: info,
      currentVersion: runningVersion,
      isForced: result.isForced,
      onDismiss: onDismiss,
    );

    return true;
  }

  /// Admin operation: publishes updated release configuration to the backend server.
  Future<bool> publishVersionUpdate({
    required String latestVersion,
    required String minimumRequiredVersion,
    required bool forceUpdate,
    required String releaseNotes,
    String? downloadUrl,
    String? playStoreUrl,
    String? appStoreUrl,
    http.Client? client,
  }) async {
    final httpClient = client ?? _customHttpClient ?? http.Client();
    final token = await AuthService().getValidToken();

    try {
      var base = ApiConfig.baseUrl;
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }

      final uri = Uri.parse('$base/app/version');
      final payload = {
        'latestVersion': latestVersion,
        'minimumRequiredVersion': minimumRequiredVersion,
        'forceUpdate': forceUpdate,
        'releaseNotes': releaseNotes,
        if (downloadUrl != null && downloadUrl.isNotEmpty) 'downloadUrl': downloadUrl,
        if (playStoreUrl != null && playStoreUrl.isNotEmpty) 'playStoreUrl': playStoreUrl,
        if (appStoreUrl != null && appStoreUrl.isNotEmpty) 'appStoreUrl': appStoreUrl,
      };

      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(_networkTimeout);

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[APP VERSION] Failed to publish version update: $e');
      return false;
    }
  }
}
