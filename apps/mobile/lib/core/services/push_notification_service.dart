import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

/// Centralized Push Notification Service for Alpha X Gym.
///
/// Features:
/// 1. Lifecycle initialization & runtime permission request (Android 13+ & iOS).
/// 2. User identification via [OneSignal.login] on authenticated login/restore.
/// 3. Device Subscription / Player ID capture and automatic backend synchronization.
/// 4. Push subscription observer with delayed token generation and retry support.
/// 5. Clean session unbinding on logout via [OneSignal.logout] and authenticated unregister.
/// 6. Transient network failure resilience with exponential backoff and pending sync.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  static PushNotificationService get instance => _instance;

  static const String oneSignalAppId = 'b57d6e24-d636-42ce-bb54-bc95fe4ce74e';
  static const String _keyRegisteredPlayerId = 'alpha_x_onesignal_registered_player_id';
  static const String _keyRegisteredUserId = 'alpha_x_onesignal_registered_user_id';
  static const String _keyPendingPlayerId = 'alpha_x_onesignal_pending_player_id';

  bool _initialized = false;
  bool _isLoggingOut = false;
  String? _currentUserId;
  String? _currentAuthToken;
  String? _lastRegisteredPlayerId;
  String? _lastRegisteredUserId;
  bool _isUploading = false;

  /// Test hooks and injectable transport
  http.Client? httpClient;
  Future<void> Function(String externalId)? onOneSignalLoginHook;
  Future<void> Function()? onOneSignalLogoutHook;

  bool get isLoggingOut => _isLoggingOut;
  String? get currentUserId => _currentUserId;
  String? get lastRegisteredPlayerId => _lastRegisteredPlayerId;
  String? get lastRegisteredUserId => _lastRegisteredUserId;

  PushNotificationService._internal();

  /// Evaluates whether an incoming push notification should be displayed.
  /// Prevents user-targeted notifications from showing when logged out or targeted to a different user,
  /// while safely allowing general/anonymous broadcasts.
  bool shouldDisplayNotification({
    String? targetUserId,
    bool isBroadcast = false,
    bool? isAuthenticated,
    String? currentUserId,
  }) {
    final authed = isAuthenticated ?? AuthService().isAuthenticated;
    final activeId = currentUserId ?? AuthService().currentUserId;

    if (targetUserId != null && targetUserId.isNotEmpty) {
      if (!authed || activeId != targetUserId) {
        return false;
      }
      return true;
    }

    if (!authed && !isBroadcast) {
      return false;
    }

    return true;
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _dialogShown = false;

  /// Whether a push subscription ID is a real server-assigned ID (not local- placeholder)
  bool _isRegistered(String? id) =>
      id != null && id.isNotEmpty && !id.startsWith('local-');

  /// Displays the required Push Subscription Verification Dialog once registered
  void _maybeShowIntegrationCompleteDialog(BuildContext context, String? subscriptionId) {
    if (_isRegistered(subscriptionId) && !_dialogShown) {
      _dialogShown = true;
      showIntegrationCompleteDialog(context);
    }
  }

  /// Sets up push subscription observer to confirm registration and present verification dialog
  void setupPushSubscriptionObserver([BuildContext? context]) {
    if (!_isSupportedPlatform) return;

    OneSignal.User.pushSubscription.addObserver((state) {
      final ctx = context ?? navigatorKey.currentContext;
      if (ctx != null) {
        _maybeShowIntegrationCompleteDialog(ctx, state.current.id);
      }
    });

    final currentId = OneSignal.User.pushSubscription.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = context ?? navigatorKey.currentContext;
      if (ctx != null) {
        _maybeShowIntegrationCompleteDialog(ctx, currentId);
      }
    });
  }

  /// Shows the official OneSignal Integration Complete Dialog
  void showIntegrationCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Your OneSignal SDK integration is complete!'),
        content: const Text(
          'You can now send Push Notifications & In-App Messages through OneSignal. Tap below to enable push notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              requestPermission();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Requests push notification permission (prompted on button tap or app launch)
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) return false;
    final granted = await OneSignal.Notifications.requestPermission(true);
    if (granted) {
      // Permission granted: trigger sync to ensure token is captured and sent
      unawaited(syncRegistrationIfNeeded());
    }
    return granted;
  }

  /// Sets logging level
  void setLogLevel(OSLogLevel level) {
    if (!_isSupportedPlatform) return;
    OneSignal.Debug.setLogLevel(level);
  }

  /// Sets user email in OneSignal
  void setEmail(String email) {
    if (!_isSupportedPlatform) return;
    OneSignal.User.addEmail(email);
  }

  /// Sets user SMS phone number in OneSignal
  void setSmsNumber(String number) {
    if (!_isSupportedPlatform) return;
    OneSignal.User.addSms(number);
  }

  /// Sets user tag in OneSignal
  void setTag(String key, String value) {
    if (!_isSupportedPlatform) return;
    OneSignal.User.addTagWithKey(key, value);
  }

  /// Initializes OneSignal and registers lifecycle listeners on app startup.
  Future<void> initialize() async {
    if (!_isSupportedPlatform || _initialized) return;

    try {
      // 1. Restore persisted device & user registration state from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        _lastRegisteredPlayerId = prefs.getString(_keyRegisteredPlayerId);
        _lastRegisteredUserId = prefs.getString(_keyRegisteredUserId);
      } catch (_) {}

      // Set verbose log level so adb logcat captures all OneSignal/FCM token handshakes
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      await OneSignal.initialize(oneSignalAppId);
      _initialized = true;
      debugPrint('[OneSignal] ✅ Initialized with App ID: $oneSignalAppId');

      // Explicitly opt in the push subscription
      await OneSignal.User.pushSubscription.optIn();

      // Request runtime notification permission (Android 13+ & iOS)
      final permissionGranted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('[OneSignal] 🔔 Notification permission status: $permissionGranted');

      // Foreground notification listener — displays notification natively and triggers UI sync
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final title = event.notification.title ?? '';
        final additionalData = event.notification.additionalData;
        final targetUserId = additionalData?['targetUserId'] as String?;
        final isBroadcast = additionalData?['isBroadcast'] == true || additionalData?['type'] == 'admin_broadcast';

        if (!shouldDisplayNotification(targetUserId: targetUserId, isBroadcast: isBroadcast)) {
          debugPrint('[OneSignal] 🛑 Suppressed notification "$title" for target: $targetUserId (Session active: ${AuthService().isAuthenticated})');
          event.preventDefault();
          return;
        }

        debugPrint('[OneSignal] 📩 Foreground notification: "$title"');
        event.notification.display();
        AppAutoRefreshService.instance.triggerImmediateSync(reason: 'OneSignal Push Received');
      });

      // Notification tap/click handler — called when user taps a notification
      OneSignal.Notifications.addClickListener((event) {
        final title = event.notification.title ?? '';
        final additionalData = event.notification.additionalData;
        final targetUserId = additionalData?['targetUserId'] as String?;
        final isBroadcast = additionalData?['isBroadcast'] == true || additionalData?['type'] == 'admin_broadcast';

        if (!shouldDisplayNotification(targetUserId: targetUserId, isBroadcast: isBroadcast)) {
          debugPrint('[OneSignal] ⚠️ Ignored tap on notification "$title" (Target mismatch or logged out)');
          return;
        }

        final type = additionalData?['type'] as String? ?? '';
        debugPrint('[OneSignal] 🔔 Notification tapped: "$title" (type: $type)');
        AppAutoRefreshService.instance.triggerImmediateSync(reason: 'OneSignal Notification Tapped');
      });

      // Observer for push subscription state (e.g. when FCM generates token after handshake or permission grant)
      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        final optedIn = state.current.optedIn;
        debugPrint('[OneSignal] 🔄 Subscription updated. ID: ${newId ?? "null"} | optedIn: $optedIn');
        if (newId != null && newId.isNotEmpty) {
          if (!_isLoggingOut && AuthService().isAuthenticated) {
            unawaited(syncRegistrationIfNeeded(overridePlayerId: newId));
          } else {
            debugPrint('[OneSignal] ⏹️ Subscription sync suppressed: logout in progress or unauthenticated session.');
          }
        }
      });

      // Immediate check if a subscription ID is already available at startup
      final initialId = OneSignal.User.pushSubscription.id;
      final initialOptedIn = OneSignal.User.pushSubscription.optedIn;
      if (initialId != null && initialId.isNotEmpty) {
        debugPrint('[OneSignal] 📲 Existing subscription ID at init: $initialId (optedIn: $initialOptedIn)');
        unawaited(syncRegistrationIfNeeded(overridePlayerId: initialId));
      } else {
        debugPrint('[OneSignal] ℹ️ Push subscription ID not yet generated by FCM at startup. Observer will handle once created.');
      }
    } catch (e) {
      debugPrint('[OneSignal] ❌ Initialization error: $e');
    }
  }

  /// Evaluates whether the device needs to register its push subscription with the backend.
  /// Handles delayed token creation, login timing, new users, and automatic recovery.
  Future<void> syncRegistrationIfNeeded({String? overridePlayerId}) async {
    if (!_isSupportedPlatform && httpClient == null) return;
    if (_isLoggingOut) {
      debugPrint('[OneSignal] ⏹️ Push registration skipped: logout in progress.');
      return;
    }

    if (!AuthService().isAuthenticated) {
      debugPrint('[OneSignal] ℹ️ Push registration skipped: unauthenticated session.');
      return;
    }

    final playerId = (overridePlayerId != null && overridePlayerId.isNotEmpty)
        ? overridePlayerId
        : (_isSupportedPlatform ? OneSignal.User.pushSubscription.id : _lastRegisteredPlayerId);

    if (playerId == null || playerId.isEmpty) return;

    final effectiveUserId = (_currentUserId != null && _currentUserId!.isNotEmpty)
        ? _currentUserId!
        : AuthService().currentUserId;

    final effectiveToken = (_currentAuthToken != null && _currentAuthToken!.isNotEmpty)
        ? _currentAuthToken!
        : AuthService().currentToken;

    // Only clients register device tokens (admins do not register device tokens)
    if (AuthService().isAdmin) return;

    if (effectiveUserId.isEmpty || effectiveToken.isEmpty) {
      return;
    }

    // Check if already registered for this exact user and device token
    if (playerId == _lastRegisteredPlayerId && effectiveUserId == _lastRegisteredUserId) {
      return; // Already up to date
    }

    await _uploadPlayerIdToServer(effectiveToken, playerId, userId: effectiveUserId);
  }

  /// Called on user login or session restore to associate device with user account.
  Future<void> onUserLogin({
    required String userId,
    required String authToken,
  }) async {
    _isLoggingOut = false;
    _currentUserId = userId;
    _currentAuthToken = authToken;

    // Handle account switching on same device: reset cached IDs for old user
    if (_lastRegisteredUserId != null && _lastRegisteredUserId != userId) {
      _lastRegisteredPlayerId = null;
      _lastRegisteredUserId = null;
    }

    if (onOneSignalLoginHook != null) {
      await onOneSignalLoginHook!(userId);
    } else if (_isSupportedPlatform) {
      try {
        if (!_initialized) {
          await initialize();
        }

        // Associate device with user ID in OneSignal (External ID)
        await OneSignal.login(userId);
        debugPrint('[OneSignal] Logged in with external userId: $userId');
      } catch (e) {
        debugPrint('[OneSignal] onUserLogin OneSignal.login error: $e');
      }
    }

    try {
      // Check current subscription ID or any stored pending registration
      String? playerId;
      if (_isSupportedPlatform) {
        try {
          playerId = OneSignal.User.pushSubscription.id;
        } catch (_) {}
      }
      if (playerId == null || playerId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          playerId = prefs.getString(_keyPendingPlayerId);
        } catch (_) {}
      }

      if (playerId != null && playerId.isNotEmpty) {
        await _uploadPlayerIdToServer(authToken, playerId, userId: userId);
      } else {
        debugPrint('[OneSignal] Subscription ID not yet ready; observer will upload once generated.');
      }
    } catch (e) {
      debugPrint('[OneSignal] onUserLogin error: $e');
    }
  }

  /// Called on logout to dissociate user from OneSignal and unregister device token on backend.
  Future<void> onUserLogout({String? token, String? playerId, String? userId}) async {
    _isLoggingOut = true;
    try {
      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : (_currentAuthToken ?? AuthService().currentToken);

      // Resolve playerId: parameter -> memory cache -> OneSignal SDK -> SharedPreferences
      String? resolvedPlayerId = (playerId != null && playerId.isNotEmpty) ? playerId : _lastRegisteredPlayerId;
      if (resolvedPlayerId == null || resolvedPlayerId.isEmpty) {
        if (_isSupportedPlatform) {
          try {
            resolvedPlayerId = OneSignal.User.pushSubscription.id;
          } catch (_) {}
        }
      }
      if (resolvedPlayerId == null || resolvedPlayerId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          resolvedPlayerId = prefs.getString(_keyRegisteredPlayerId);
        } catch (_) {}
      }

      if (effectiveToken.isNotEmpty && resolvedPlayerId != null && resolvedPlayerId.isNotEmpty) {
        try {
          debugPrint('[OneSignal] 🔄 Unregistering device ($resolvedPlayerId) from backend before session wipe...');
          final success = await _unregisterPlayerIdFromServer(effectiveToken, resolvedPlayerId);
          if (success) {
            debugPrint('[OneSignal] ✅ Backend confirmed device unregistration.');
          } else {
            debugPrint('[OneSignal] ⚠️ Backend device unregister was not acknowledged by server.');
          }
        } catch (e) {
          debugPrint('[OneSignal] ⚠️ Error during device unregister on logout: $e');
        }
      } else {
        debugPrint('[OneSignal] ℹ️ Skipped backend unregister: tokenPresent=${effectiveToken.isNotEmpty}, playerIdPresent=${resolvedPlayerId != null && resolvedPlayerId.isNotEmpty}');
      }

      // Always reset local session tracking on logout
      _currentUserId = null;
      _currentAuthToken = null;
      _lastRegisteredPlayerId = null;
      _lastRegisteredUserId = null;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyRegisteredPlayerId);
        await prefs.remove(_keyRegisteredUserId);
        await prefs.remove(_keyPendingPlayerId);
      } catch (_) {}

      // Detach External ID in OneSignal
      if (onOneSignalLogoutHook != null) {
        await onOneSignalLogoutHook!();
      } else if (_isSupportedPlatform) {
        try {
          await OneSignal.logout();
          debugPrint('[OneSignal] ✅ Detached previous user External ID and logged out from OneSignal.');
        } catch (e) {
          debugPrint('[OneSignal] onUserLogout OneSignal.logout error: $e');
        }
      }
    } finally {
      _isLoggingOut = false;
    }
  }

  /// Unregisters client's OneSignal Subscription ID from backend PostgreSQL database on logout.
  Future<bool> _unregisterPlayerIdFromServer(String authToken, String playerId) async {
    if (authToken.isEmpty || playerId.isEmpty) return false;

    Future<http.Response> postToUrl(String base) {
      final url = Uri.parse('$base/notifications/unregister-device');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      final body = jsonEncode({'playerId': playerId});
      if (httpClient != null) {
        return httpClient!.post(url, headers: headers, body: body);
      }
      return http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 5));
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
        debugPrint('✅ [OneSignal] Successfully unregistered device ($playerId) from backend.');
        return true;
      } else {
        debugPrint('⚠️ [OneSignal] Backend device unregister returned status ${res.statusCode}: ${res.body}');
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ [OneSignal] Failed to unregister device from server: $e');
      return false;
    }
  }

  /// Uploads client's OneSignal Subscription ID to backend database with retries and fail-safe persistence.
  Future<bool> _uploadPlayerIdToServer(
    String authToken,
    String playerId, {
    String? userId,
  }) async {
    if (authToken.isEmpty || playerId.isEmpty) return false;
    if (_isUploading) return false;
    _isUploading = true;

    Future<http.Response> postToUrl(String base) {
      final url = Uri.parse('$base/notifications/register-device');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };
      final body = jsonEncode({'playerId': playerId});
      if (httpClient != null) {
        return httpClient!.post(url, headers: headers, body: body);
      }
      return http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));
    }

    final targetUserId = (userId != null && userId.isNotEmpty)
        ? userId
        : (_currentUserId ?? AuthService().currentUserId);

    bool registrationSuccess = false;

    // Retry up to 3 attempts with exponential backoff on transient network failures
    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
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
          _lastRegisteredUserId = targetUserId;
          registrationSuccess = true;

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyRegisteredPlayerId, playerId);
            if (targetUserId.isNotEmpty) {
              await prefs.setString(_keyRegisteredUserId, targetUserId);
            }
            await prefs.remove(_keyPendingPlayerId);
          } catch (_) {}

          debugPrint('✅ [OneSignal] Successfully registered device ($playerId) for user ($targetUserId) to backend DB.');
          break;
        } else {
          debugPrint('⚠️ [OneSignal] Backend registration attempt $attempt returned status ${res.statusCode}: ${res.body}');
        }
      } catch (e) {
        debugPrint('⚠️ [OneSignal] Backend registration attempt $attempt network error: $e');
      }

      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    _isUploading = false;

    if (!registrationSuccess) {
      debugPrint('⚠️ [OneSignal] Failed to register device token after $maxAttempts attempts. Saving pending sync.');
      await _savePendingPlayerId(playerId);
    }

    return registrationSuccess;
  }

  Future<void> _savePendingPlayerId(String playerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPendingPlayerId, playerId);
    } catch (_) {}
  }
}
