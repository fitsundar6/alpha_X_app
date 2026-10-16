import 'package:flutter_test/flutter_test.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService Registration & Lifecycle Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
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
  });
}
