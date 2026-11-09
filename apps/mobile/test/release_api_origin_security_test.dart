import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/secure_token_storage.dart';
import 'package:alpha_x_gym/core/widgets/server_config_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiConfig.resetTestOverrides();
    ApiConfig.customServerUrl = null;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiConfig.resetTestOverrides();
    ApiConfig.customServerUrl = null;
  });

  group('Release API Origin Security - Origin Enforcement & HTTPS Validation', () {
    test('Release mode accepts approved default production HTTPS URL', () {
      ApiConfig.isReleaseModeOverride = true;
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));
      expect(ApiConfig.baseUrl.startsWith('https://'), isTrue);
      expect(ApiConfig.isApprovedProductionOrigin(ApiConfig.baseUrl), isTrue);
    });

    test('Release mode accepts approved custom production hosts (alphaxgym.com)', () {
      ApiConfig.isReleaseModeOverride = true;
      expect(ApiConfig.isApprovedProductionOrigin('https://api.alphaxgym.com/api/v1'), isTrue);
      expect(ApiConfig.isApprovedProductionOrigin('https://alphaxgym.com/api/v1'), isTrue);
      expect(ApiConfig.isApprovedProductionOrigin('https://app.alphaxgym.com/api/v1'), isTrue);
    });

    test('Release mode strictly rejects plain HTTP URLs (Enforce HTTPS)', () {
      ApiConfig.isReleaseModeOverride = true;
      expect(ApiConfig.isApprovedProductionOrigin('http://alpha-x-app.vercel.app/api/v1'), isFalse);
      expect(ApiConfig.isApprovedProductionOrigin('http://api.alphaxgym.com/api/v1'), isFalse);
      expect(ApiConfig.isApprovedProductionOrigin('http://192.168.1.5:5000/api/v1'), isFalse);
      expect(ApiConfig.isApprovedProductionOrigin('http://localhost:5000/api/v1'), isFalse);
    });

    test('Release mode strictly rejects arbitrary / unapproved foreign domains', () {
      ApiConfig.isReleaseModeOverride = true;
      expect(ApiConfig.isApprovedProductionOrigin('https://evil-attacker.com/api/v1'), isFalse);
      expect(ApiConfig.isApprovedProductionOrigin('https://phishing-site.org/api/v1'), isFalse);
      expect(ApiConfig.isApprovedProductionOrigin('https://another-app.vercel.app/api/v1'), isFalse);
      expect(ApiConfig.isApprovedProductionOrigin('https://fake-alpha-x.vercel.app/api/v1'), isFalse);
    });

    test('Release mode baseUrl ignores arbitrary customServerUrl and enforces production', () {
      ApiConfig.isReleaseModeOverride = true;
      // An attacker attempts to set an unapproved origin
      ApiConfig.customServerUrl = 'https://attacker-origin.com/api/v1';

      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));
      expect(ApiConfig.baseUrl, isNot(contains('attacker-origin.com')));
    });

    test('Release mode baseUrl ignores plain HTTP customServerUrl and enforces production', () {
      ApiConfig.isReleaseModeOverride = true;
      ApiConfig.customServerUrl = 'http://alpha-x-app.vercel.app/api/v1';

      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));
      expect(ApiConfig.baseUrl.startsWith('https://'), isTrue);
    });
  });

  group('Release Mode Controls - ServerConfigDialog & Runtime Modification Guards', () {
    test('Release mode blocks setCustomUrl from changing or persisting API origin', () async {
      ApiConfig.isReleaseModeOverride = true;
      SharedPreferences.setMockInitialValues({});

      await ApiConfig.setCustomUrl('http://192.168.1.5:5000');

      expect(ApiConfig.customServerUrl, isNull);
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ApiConfig.storageKey), isFalse);
    });

    test('initialize() in release mode prunes any unapproved stored custom server URL', () async {
      ApiConfig.isReleaseModeOverride = true;
      SharedPreferences.setMockInitialValues({
        ApiConfig.storageKey: 'http://malicious-local-network:5000/api/v1',
      });

      await ApiConfig.initialize();

      expect(ApiConfig.customServerUrl, isNull);
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ApiConfig.storageKey), isFalse);
    });

    testWidgets('ServerConfigDialog.show is blocked in release mode', (tester) async {
      ApiConfig.isReleaseModeOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ServerConfigDialog.show(context),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // In release mode, the dialog must NOT be presented
      expect(find.byType(ServerConfigDialog), findsNothing);
      expect(find.text('Server Settings'), findsNothing);
    });
  });

  group('Debug Mode - Authorized Debug Configuration & Token Clearing', () {
    test('Debug mode permits authorized LAN / Emulator / Localhost configuration', () async {
      ApiConfig.isReleaseModeOverride = false;
      SharedPreferences.setMockInitialValues({});

      await ApiConfig.setCustomUrl('http://192.168.1.5:5000');
      expect(ApiConfig.customServerUrl, equals('http://192.168.1.5:5000/api/v1'));
      expect(ApiConfig.baseUrl, equals('http://192.168.1.5:5000/api/v1'));
      expect(AppConstants.apiBaseUrl, equals('http://192.168.1.5:5000/api/v1'));
    });

    test('AuthService.updateServerUrl safely clears existing tokens when origin changes in debug flow', () async {
      ApiConfig.isReleaseModeOverride = false;
      SharedPreferences.setMockInitialValues({});

      final authService = AuthService();
      authService.resetForTesting();

      // Simulate an active authenticated session
      const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_active_jwt_token.signature';
      await SecureTokenStorage.writeAuthToken(testToken);
      await SecureTokenStorage.writeSessionData({
        'role': 'CLIENT',
        'userId': 'client-001',
        'email': 'athlete@alphax.test',
      });

      // Verify token exists before origin change
      expect(await SecureTokenStorage.readAuthToken(), equals(testToken));

      // Initial origin: production
      expect(ApiConfig.baseUrlOrigin, equals('https://alpha-x-app.vercel.app'));

      // Change API origin to local development LAN
      await authService.updateServerUrl('http://192.168.1.5:5000');

      // Origin changed -> Tokens must be safely purged
      expect(ApiConfig.baseUrlOrigin, equals('http://192.168.1.5:5000'));
      expect(await SecureTokenStorage.readAuthToken(), isNull);
      expect(await SecureTokenStorage.readSessionData(), isNull);
      expect(authService.rawToken, isEmpty);
      expect(authService.isAuthenticated, isFalse);
    });

    test('AuthService.updateServerUrl preserves tokens when origin does NOT change', () async {
      ApiConfig.isReleaseModeOverride = false;
      SharedPreferences.setMockInitialValues({});

      final authService = AuthService();
      authService.resetForTesting();

      // Set initial URL
      await ApiConfig.setCustomUrl('http://192.168.1.5:5000/api/v1');

      const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.persisted_token.signature';
      await SecureTokenStorage.writeAuthToken(testToken);

      // Re-apply same origin (e.g. with trailing slash or query fix)
      await authService.updateServerUrl('http://192.168.1.5:5000/api/v1/');

      // Origin did not change -> Token is preserved
      expect(await SecureTokenStorage.readAuthToken(), equals(testToken));
    });
  });
}

