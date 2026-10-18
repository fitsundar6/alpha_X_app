import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/models/app_version_info.dart';
import 'package:alpha_x_gym/core/services/app_version_service.dart';
import 'package:alpha_x_gym/core/widgets/app_update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersionInfo - Semantic Version Comparison', () {
    test('compareVersions accurately compares identical versions', () {
      expect(AppVersionInfo.compareVersions('1.0.0', '1.0.0'), equals(0));
      expect(AppVersionInfo.compareVersions('v1.0.0', '1.0.0'), equals(0));
      expect(AppVersionInfo.compareVersions('1.0.0+1', '1.0.0+5'), equals(0));
    });

    test('compareVersions accurately identifies newer versions', () {
      expect(AppVersionInfo.compareVersions('1.0.0', '1.0.1'), equals(-1));
      expect(AppVersionInfo.compareVersions('1.0.0', '1.1.0'), equals(-1));
      expect(AppVersionInfo.compareVersions('1.9.9', '2.0.0'), equals(-1));
      expect(AppVersionInfo.compareVersions('1.0', '1.0.1'), equals(-1));
    });

    test('compareVersions accurately identifies older versions', () {
      expect(AppVersionInfo.compareVersions('1.0.1', '1.0.0'), equals(1));
      expect(AppVersionInfo.compareVersions('2.0.0', '1.9.9'), equals(1));
      expect(AppVersionInfo.compareVersions('1.2.0', '1.1.5'), equals(1));
    });

    test('isUpdateAvailable and isForceUpdateRequired work correctly', () {
      const info = AppVersionInfo(
        latestVersion: '1.2.0',
        minimumRequiredVersion: '1.1.0',
        forceUpdate: false,
        releaseNotes: 'Stability improvements',
      );

      // Running 1.0.0: below minimum required (1.1.0) -> update available AND force update
      expect(info.isUpdateAvailable('1.0.0'), isTrue);
      expect(info.isForceUpdateRequired('1.0.0'), isTrue);

      // Running 1.1.0: equals minimum required, but below latest (1.2.0) -> update available, NOT forced
      expect(info.isUpdateAvailable('1.1.0'), isTrue);
      expect(info.isForceUpdateRequired('1.1.0'), isFalse);

      // Running 1.2.0: latest -> no update
      expect(info.isUpdateAvailable('1.2.0'), isFalse);
      expect(info.isForceUpdateRequired('1.2.0'), isFalse);

      // If forceUpdate flag is true, forced regardless
      const forcedInfo = AppVersionInfo(
        latestVersion: '1.2.0',
        minimumRequiredVersion: '1.0.0',
        forceUpdate: true,
      );
      expect(forcedInfo.isForceUpdateRequired('1.1.5'), isTrue);
    });

    test('resolveDownloadUrl resolves platform store links', () {
      const info = AppVersionInfo(
        latestVersion: '1.2.0',
        minimumRequiredVersion: '1.0.0',
        downloadUrl: 'https://alphaxgym.com/download',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.alphaxgym.app',
        appStoreUrl: 'https://apps.apple.com/app/id6400000000',
      );

      expect(
        info.resolveDownloadUrl(platform: TargetPlatform.android, isWeb: false),
        equals('https://play.google.com/store/apps/details?id=com.alphaxgym.app'),
      );
      expect(
        info.resolveDownloadUrl(platform: TargetPlatform.iOS, isWeb: false),
        equals('https://apps.apple.com/app/id6400000000'),
      );
      expect(
        info.resolveDownloadUrl(platform: TargetPlatform.windows, isWeb: false),
        equals('https://alphaxgym.com/download'),
      );
      expect(
        info.resolveDownloadUrl(isWeb: true),
        equals('https://alphaxgym.com/download'),
      );
    });
  });

  group('AppVersionService - In-App Update Logic', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('checkForUpdate detects available updates from mock API', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/app/version')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'latestVersion': '1.0.5',
                'minimumRequiredVersion': '1.0.0',
                'forceUpdate': false,
                'releaseNotes': 'New workout features',
                'downloadUrl': 'https://alphaxgym.com/download',
                'playStoreUrl': 'https://play.google.com/store',
                'appStoreUrl': 'https://apps.apple.com',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = AppVersionService(httpClient: mockClient);
      final result = await service.checkForUpdate(currentVersionOverride: '1.0.0');

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.isForced, isFalse);
      expect(result.info?.latestVersion, equals('1.0.5'));
    });

    test('checkForUpdate detects forced update when below minimum version', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'latestVersion': '2.0.0',
              'minimumRequiredVersion': '1.5.0',
              'forceUpdate': false,
              'releaseNotes': 'Major overhaul',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppVersionService(httpClient: mockClient);
      final result = await service.checkForUpdate(currentVersionOverride: '1.0.0');

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.isForced, isTrue);
    });

    test('dismissUpdate persists dismissed version', () async {
      final service = AppVersionService();
      expect(await service.isVersionDismissed('1.0.5'), isFalse);

      await service.dismissUpdate('1.0.5');
      expect(await service.isVersionDismissed('1.0.5'), isTrue);
      expect(await service.isVersionDismissed('1.0.6'), isFalse);

      await service.clearDismissedVersion();
      expect(await service.isVersionDismissed('1.0.5'), isFalse);
    });

    test('publishVersionUpdate sends admin update payload', () async {
      String? recordedBody;
      final mockClient = MockClient((request) async {
        recordedBody = request.body;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'latestVersion': '1.1.0',
              'minimumRequiredVersion': '1.0.0',
              'forceUpdate': false,
            },
          }),
          200,
        );
      });

      final service = AppVersionService(httpClient: mockClient);
      final success = await service.publishVersionUpdate(
        latestVersion: '1.1.0',
        minimumRequiredVersion: '1.0.0',
        forceUpdate: false,
        releaseNotes: 'Great release',
      );

      expect(success, isTrue);
      expect(recordedBody, contains('"latestVersion":"1.1.0"'));
    });
  });

  group('AppUpdateDialog - UI & Interaction', () {
    testWidgets('renders Optional Update dialog with LATER and UPDATE NOW buttons', (tester) async {
      const info = AppVersionInfo(
        latestVersion: '1.0.1',
        minimumRequiredVersion: '1.0.0',
        forceUpdate: false,
        releaseNotes: 'Fast meal tracking and bug fixes',
        downloadUrl: 'https://alphaxgym.com/download',
      );

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(
              info: info,
              currentVersion: '1.0.0',
              isForced: false,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('UPDATE AVAILABLE'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.text('v1.0.1'), findsOneWidget);
      expect(find.text('Fast meal tracking and bug fixes'), findsOneWidget);
      expect(find.text('UPDATE NOW'), findsOneWidget);
      expect(find.text('LATER'), findsOneWidget);

      await tester.ensureVisible(find.text('LATER'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('LATER'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('renders Mandatory/Forced Update dialog with NO LATER button', (tester) async {
      const info = AppVersionInfo(
        latestVersion: '2.0.0',
        minimumRequiredVersion: '2.0.0',
        forceUpdate: true,
        releaseNotes: 'Critical security update',
        downloadUrl: 'https://alphaxgym.com/download',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(
              info: info,
              currentVersion: '1.0.0',
              isForced: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('UPDATE REQUIRED'), findsOneWidget);
      expect(find.text('UPDATE NOW'), findsOneWidget);
      expect(find.text('LATER'), findsNothing);

      // Verify PopScope with canPop: false is present
      final popScopeFinder = find.byWidgetPredicate(
        (w) => w is PopScope && w.canPop == false,
      );
      expect(popScopeFinder, findsOneWidget);
    });

    testWidgets('renders AppUpdateBanner properly', (tester) async {
      const info = AppVersionInfo(
        latestVersion: '1.0.2',
        minimumRequiredVersion: '1.0.0',
      );

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateBanner(
              info: info,
              currentVersion: '1.0.0',
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('NEW VERSION AVAILABLE'), findsOneWidget);
      expect(find.text('v1.0.2'), findsOneWidget);
      expect(find.text('UPDATE'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });
}
