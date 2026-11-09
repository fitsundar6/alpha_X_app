import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5: iOS App Transport Security (ATS) Configuration Verification', () {
    late String releasePlistContent;
    late String debugPlistContent;
    late String pbxprojContent;

    setUpAll(() {
      final isAppsMobile = Directory.current.path.endsWith('mobile');
      final basePath = isAppsMobile ? '.' : 'apps/mobile';

      final releasePlistFile = File('$basePath/ios/Runner/Info.plist');
      expect(releasePlistFile.existsSync(), isTrue, reason: 'Release Info.plist must exist');
      releasePlistContent = releasePlistFile.readAsStringSync().replaceAll('\r\n', '\n');

      final debugPlistFile = File('$basePath/ios/Runner/Info-Debug.plist');
      expect(debugPlistFile.existsSync(), isTrue, reason: 'Debug Info-Debug.plist must exist');
      debugPlistContent = debugPlistFile.readAsStringSync().replaceAll('\r\n', '\n');

      final pbxprojFile = File('$basePath/ios/Runner.xcodeproj/project.pbxproj');
      expect(pbxprojFile.existsSync(), isTrue, reason: 'project.pbxproj must exist');
      pbxprojContent = pbxprojFile.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('1. Release Info.plist removes NSAllowsArbitraryLoads=true and forbids arbitrary loads', () {
      expect(releasePlistContent, isNot(contains('<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>')));
      expect(releasePlistContent, contains('<key>NSAllowsArbitraryLoads</key>\n\t\t<false/>'));
    });

    test('2. Release Info.plist enforces HTTPS with no local networking or cleartext exceptions', () {
      expect(releasePlistContent, isNot(contains('<key>NSAllowsLocalNetworking</key>')));
      expect(releasePlistContent, isNot(contains('<key>NSExceptionAllowsInsecureHTTPLoads</key>')));
      expect(releasePlistContent, isNot(contains('<key>NSIncludesSubdomains</key>')));
    });

    test('3. Debug Info-Debug.plist preserves local networking exceptions for development without arbitrary loads', () {
      expect(debugPlistContent, contains('<key>NSAllowsLocalNetworking</key>\n\t\t<true/>'));
      expect(debugPlistContent, contains('<key>NSAllowsArbitraryLoads</key>\n\t\t<false/>'));
      expect(debugPlistContent, isNot(contains('<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>')));
    });

    test('4. Xcode project binds Debug configuration to Runner/Info-Debug.plist', () {
      final debugIdx = pbxprojContent.indexOf('97C147061CF9000F007C117D /* Debug */ = {');
      expect(debugIdx, isNonNegative, reason: 'Debug XCBuildConfiguration must exist in project.pbxproj');

      final debugEndIdx = pbxprojContent.indexOf('name = Debug;', debugIdx);
      final debugBlock = pbxprojContent.substring(debugIdx, debugEndIdx);

      expect(debugBlock, contains('INFOPLIST_FILE = Runner/Info-Debug.plist;'));
    });

    test('5. Xcode project binds Release and Profile configurations strictly to Runner/Info.plist', () {
      final releaseIdx = pbxprojContent.indexOf('97C147071CF9000F007C117D /* Release */ = {');
      expect(releaseIdx, isNonNegative, reason: 'Release XCBuildConfiguration must exist in project.pbxproj');

      final releaseEndIdx = pbxprojContent.indexOf('name = Release;', releaseIdx);
      final releaseBlock = pbxprojContent.substring(releaseIdx, releaseEndIdx);
      expect(releaseBlock, contains('INFOPLIST_FILE = Runner/Info.plist;'));

      final profileIdx = pbxprojContent.indexOf('249021D4217E4FDB00AE95B9 /* Profile */ = {');
      expect(profileIdx, isNonNegative, reason: 'Profile XCBuildConfiguration must exist in project.pbxproj');

      final profileEndIdx = pbxprojContent.indexOf('name = Profile;', profileIdx);
      final profileBlock = pbxprojContent.substring(profileIdx, profileEndIdx);
      expect(profileBlock, contains('INFOPLIST_FILE = Runner/Info.plist;'));
    });

    test('6. Existing permissions, identifiers and URL schemes are strictly preserved in both plists', () {
      final requiredSnippets = [
        '<key>CFBundleDisplayName</key>\n\t<string>Alpha X Gym</string>',
        '<key>CFBundleIdentifier</key>\n\t<string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>',
        '<key>NSCameraUsageDescription</key>',
        '<key>NSPhotoLibraryUsageDescription</key>',
        '<key>NSPhotoLibraryAddUsageDescription</key>',
        '<key>UIBackgroundModes</key>',
        '<string>remote-notification</string>',
        '<key>LSApplicationQueriesSchemes</key>',
        '<string>instagram</string>',
        '<string>instagram-stories</string>',
      ];

      for (final snippet in requiredSnippets) {
        expect(releasePlistContent, contains(snippet), reason: 'Release must preserve $snippet');
        expect(debugPlistContent, contains(snippet), reason: 'Debug must preserve $snippet');
      }
    });
  });
}
