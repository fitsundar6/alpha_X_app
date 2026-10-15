import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';

/// Centralized Push Notification Service for Alpha X Gym.
///
/// Features:
/// 1. Lifecycle initialization & runtime permission request (Android 13+ & iOS).
/// 2. User identification via [OneSignal.login] on authenticated login/restore.
/// 3. Device Subscription / Player ID capture and automatic backend synchronization.
/// 4. Push subscription observer to catch delayed token generation from FCM.
/// 5. Clean session unbinding on logout via [OneSignal.logout].
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  static PushNotificationService get instance => _instance;

  static const String oneSignalAppId = '56c1791b-aa5e-4042-8fba-e370433b8055';

  bool _initialized = false;
  String? _currentUserId;
  String? _currentAuthToken;
  String? _lastRegisteredPlayerId;

  String? get currentUserId => _currentUserId;
  String? get lastRegisteredPlayerId => _lastRegisteredPlayerId;

  PushNotificationService._internal();

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Initializes OneSignal and registers lifecycle listeners on app startup.
  Future<void> initialize() async {
    if (!_isSupportedPlatform || _initialized) return;

    try {
      OneSignal.initialize(oneSignalAppId);
      _initialized = true;

      // Request runtime notification permission (shows system dialog on iOS & Android 13+)
      unawaited(OneSignal.Notifications.requestPermission(true));

      // Foreground notification listener — triggers immediate UI sync for real-time coach alerts
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('[OneSignal] Foreground notification received: ${event.notification.title}');
        AppAutoRefreshService.instance.triggerImmediateSync(reason: 'OneSignal Push Received');
      });

      // Observer for push subscription state (e.g. when FCM generates token after handshake)
      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        debugPrint('[OneSignal] Push subscription state updated. ID: $newId (optedIn: ${state.current.optedIn})');
        if (newId != null && newId.isNotEmpty && newId != _lastRegisteredPlayerId) {
          if (_currentAuthToken != null && _currentAuthToken!.isNotEmpty) {
            unawaited(_uploadPlayerIdToServer(_currentAuthToken!, newId));
          }
        }
      });

      // Immediate check if a subscription ID is already available
      final initialId = OneSignal.User.pushSubscription.id;
      if (initialId != null && initialId.isNotEmpty) {
        debugPrint('[OneSignal] Initial push subscription ID: $initialId');
      }
    } catch (e) {
      debugPrint('[OneSignal] Initialization error: $e');
    }
  }

  /// Called on user login or session restore to associate device with user account.
  Future<void> onUserLogin({
    required String userId,
    required String authToken,
  }) async {
    _currentUserId = userId;
    _currentAuthToken = authToken;

    if (!_isSupportedPlatform) return;

    try {
      if (!_initialized) {
        await initialize();
      }

      // Associate device with user ID in OneSignal (External ID)
      await OneSignal.login(userId);
      debugPrint('[OneSignal] Logged in with external userId: $userId');

      // Obtain current push subscription ID (token) and upload to backend
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) {
        await _uploadPlayerIdToServer(authToken, playerId);
      } else {
        debugPrint('[OneSignal] Subscription ID not yet ready; observer will upload once generated.');
      }
    } catch (e) {
      debugPrint('[OneSignal] onUserLogin error: $e');
    }
  }

  /// Called on logout to dissociate user from OneSignal.
  Future<void> onUserLogout() async {
    _currentUserId = null;
    _currentAuthToken = null;
    _lastRegisteredPlayerId = null;

    if (!_isSupportedPlatform) return;

    try {
      await OneSignal.logout();
      debugPrint('[OneSignal] Logged out from device.');
    } catch (e) {
      debugPrint('[OneSignal] onUserLogout error: $e');
    }
  }

  /// Uploads client's OneSignal Subscription ID to backend PostgreSQL database.
  Future<bool> _uploadPlayerIdToServer(String authToken, String playerId) async {
    if (authToken.isEmpty || playerId.isEmpty) return false;

    Future<http.Response> postToUrl(String base) {
      final url = Uri.parse('$base/notifications/register-device');
      return http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'playerId': playerId}),
      ).timeout(const Duration(seconds: 10));
    }

    try {
      final primaryBase = AppConstants.apiBaseUrl;
      http.Response res;
      try {
        res = await postToUrl(primaryBase);
      } catch (primaryErr) {
        if (!primaryBase.contains(ApiConfig.defaultHostIp) && !primaryBase.contains('localhost')) {
          res = await postToUrl(ApiConfig.physicalLanUrl);
        } else {
          rethrow;
        }
      }

      if (res.statusCode == 404 &&
          !primaryBase.contains(ApiConfig.defaultHostIp) &&
          !primaryBase.contains('localhost')) {
        try {
          final lanRes = await postToUrl(ApiConfig.physicalLanUrl);
          if (lanRes.statusCode == 200) res = lanRes;
        } catch (_) {}
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _lastRegisteredPlayerId = playerId;
        debugPrint('✅ [OneSignal] Successfully registered device playerId ($playerId) to backend DB.');
        return true;
      } else {
        debugPrint('⚠️ [OneSignal] Backend device registration returned status ${res.statusCode}: ${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ [OneSignal] Failed to upload playerId to server: $e');
      return false;
    }
  }
}
