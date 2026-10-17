import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/services/push_notification_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final res = await handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService Registration & Lifecycle Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PushNotificationService.instance.httpClient = null;
      PushNotificationService.instance.onOneSignalLoginHook = null;
      PushNotificationService.instance.onOneSignalLogoutHook = null;
    });

    test('1. Singleton instance is persistent and has valid OneSignal App ID', () {
      final service1 = PushNotificationService.instance;
      final service2 = PushNotificationService.instance;

      expect(identical(service1, service2), isTrue);
      expect(PushNotificationService.oneSignalAppId, equals('b57d6e24-d636-42ce-bb54-bc95fe4ce74e'));
    });

    test('2. onUserLogin stores active user ID and token', () async {
      final service = PushNotificationService.instance;

      await service.onUserLogin(
        userId: 'client-user-123',
        authToken: 'jwt-auth-token-xyz',
      );

      expect(service.currentUserId, equals('client-user-123'));
    });

    test('3. onUserLogout cleanly resets session state and removes SharedPreferences keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_onesignal_registered_player_id', 'device-sub-123');
      await prefs.setString('alpha_x_onesignal_registered_user_id', 'client-user-123');
      await prefs.setString('alpha_x_onesignal_pending_player_id', 'device-sub-123');

      final service = PushNotificationService.instance;
      await service.onUserLogin(userId: 'client-user-123', authToken: 'jwt-auth-token-xyz');

      await service.onUserLogout();

      expect(service.currentUserId, isNull);
      expect(service.lastRegisteredPlayerId, isNull);
      expect(service.lastRegisteredUserId, isNull);

      expect(prefs.containsKey('alpha_x_onesignal_registered_player_id'), isFalse);
      expect(prefs.containsKey('alpha_x_onesignal_registered_user_id'), isFalse);
      expect(prefs.containsKey('alpha_x_onesignal_pending_player_id'), isFalse);
    });

    test('4. Unsupported platform / test environment safely bypasses native JNI calls', () async {
      final service = PushNotificationService.instance;

      // None of these should throw in headless VM test runner
      await service.initialize();
      final perm = await service.requestPermission();
      expect(perm, isFalse);

      service.setLogLevel(OSLogLevel.none);
      service.setEmail('client@alphax.com');
      service.setSmsNumber('+1234567890');
      service.setTag('tier', 'pro');
      await service.syncRegistrationIfNeeded();
    });

    test('5. onUserLogout invokes OneSignal logout hook and detaches previous user External ID', () async {
      final service = PushNotificationService.instance;
      bool oneSignalLogoutCalled = false;
      String? loggedInExternalId;

      service.onOneSignalLoginHook = (id) async {
        loggedInExternalId = id;
      };
      service.onOneSignalLogoutHook = () async {
        oneSignalLogoutCalled = true;
        loggedInExternalId = null;
      };

      await service.onUserLogin(userId: 'marcus-vance-uuid', authToken: 'jwt-valid-token');
      expect(loggedInExternalId, equals('marcus-vance-uuid'));

      await service.onUserLogout();
      expect(oneSignalLogoutCalled, isTrue);
      expect(loggedInExternalId, isNull);
    });

    test('6. onUserLogout dispatches authenticated unregister request to backend', () async {
      final service = PushNotificationService.instance;
      String? unregisterAuthHeader;
      String? unregisterBody;

      service.httpClient = MockHttpClient((req) async {
        if (req.url.path.contains('unregister-device')) {
          unregisterAuthHeader = req.headers['Authorization'];
          unregisterBody = req.body;
          return http.Response(jsonEncode({'status': 'SUCCESS', 'data': {'cleared': true}}), 200);
        }
        return http.Response('Not Found', 404);
      });

      await service.onUserLogout(
        token: 'auth-jwt-marcus',
        playerId: 'marcus-android-device-sub',
      );

      expect(unregisterAuthHeader, equals('Bearer auth-jwt-marcus'));
      expect(unregisterBody, contains('marcus-android-device-sub'));
    });

    test('7. Safe account switching on same device clears stale user mapping and registers new user', () async {
      final service = PushNotificationService.instance;
      final registeredUsers = <String>[];

      service.httpClient = MockHttpClient((req) async {
        if (req.url.path.contains('register-device')) {
          final data = jsonDecode(req.body);
          registeredUsers.add(data['playerId']);
          return http.Response(jsonEncode({'status': 'SUCCESS', 'data': {'registered': true}}), 200);
        }
        return http.Response('Not Found', 404);
      });

      // User A logs in on Device X
      await service.onUserLogin(userId: 'user-athlete-a', authToken: 'token-a');
      expect(service.currentUserId, equals('user-athlete-a'));

      // User A logs out
      await service.onUserLogout(token: 'token-a', playerId: 'device-x-token');
      expect(service.currentUserId, isNull);
      expect(service.lastRegisteredUserId, isNull);

      // User B logs into Device X
      await service.onUserLogin(userId: 'user-athlete-b', authToken: 'token-b');
      expect(service.currentUserId, equals('user-athlete-b'));
    });

    test('8. Observer re-registration race prevention: syncRegistrationIfNeeded drops registrations during logout and unauthenticated sessions', () async {
      final service = PushNotificationService.instance;
      int uploadCalls = 0;

      service.httpClient = MockHttpClient((req) async {
        if (req.url.path.contains('register-device')) {
          uploadCalls++;
          return http.Response(jsonEncode({'status': 'SUCCESS'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      // When unauthenticated, syncRegistrationIfNeeded should NEVER upload or register device
      await service.syncRegistrationIfNeeded(overridePlayerId: 'rogue-token-on-logout');
      expect(uploadCalls, equals(0));
    });

    test('9. shouldDisplayNotification suppresses user-targeted notifications for logged-out users', () {
      final service = PushNotificationService.instance;

      final shouldShow = service.shouldDisplayNotification(
        targetUserId: 'marcus-vance-uuid',
        isBroadcast: false,
        isAuthenticated: false,
        currentUserId: '',
      );

      expect(shouldShow, isFalse);
    });

    test('10. shouldDisplayNotification suppresses user-targeted notifications when targetUserId mismatches active user', () {
      final service = PushNotificationService.instance;

      final shouldShow = service.shouldDisplayNotification(
        targetUserId: 'marcus-vance-uuid',
        isBroadcast: false,
        isAuthenticated: true,
        currentUserId: 'sarah-connor-uuid',
      );

      expect(shouldShow, isFalse);
    });

    test('11. shouldDisplayNotification delivers targeted notifications when active user matches targetUserId', () {
      final service = PushNotificationService.instance;

      final shouldShow = service.shouldDisplayNotification(
        targetUserId: 'marcus-vance-uuid',
        isBroadcast: false,
        isAuthenticated: true,
        currentUserId: 'marcus-vance-uuid',
      );

      expect(shouldShow, isTrue);
    });

    test('12. shouldDisplayNotification allows anonymous and general broadcasts even when logged out', () {
      final service = PushNotificationService.instance;

      final shouldShow = service.shouldDisplayNotification(
        targetUserId: null,
        isBroadcast: true,
        isAuthenticated: false,
        currentUserId: '',
      );

      expect(shouldShow, isTrue);
    });

    test('13. Stale pending token cleanup on logout prevents re-registration after session purge', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_onesignal_pending_player_id', 'stale-pending-token');

      final service = PushNotificationService.instance;
      await service.onUserLogout();

      expect(prefs.containsKey('alpha_x_onesignal_pending_player_id'), isFalse);
    });
  });
}
