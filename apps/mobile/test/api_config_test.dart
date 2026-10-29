import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/network/network_exceptions.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.customServerUrl = null;
    ApiConfig.resetTestOverrides();
  });

  tearDown(() {
    ApiConfig.resetTestOverrides();
    ApiConfig.customServerUrl = null;
  });

  group('ApiConfig URL Normalization Tests', () {
    test('Normalizes missing scheme and appends /api/v1', () {
      expect(
        ApiConfig.normalizeUrl('192.168.1.5:5000'),
        equals('http://192.168.1.5:5000/api/v1'),
      );
    });

    test('Normalizes URL with port but without subpath', () {
      expect(
        ApiConfig.normalizeUrl('http://192.168.1.5:5000'),
        equals('http://192.168.1.5:5000/api/v1'),
      );
    });

    test('Normalizes /api to /api/v1', () {
      expect(
        ApiConfig.normalizeUrl('http://192.168.1.5:5000/api'),
        equals('http://192.168.1.5:5000/api/v1'),
      );
      expect(
        ApiConfig.normalizeUrl('http://192.168.1.5:5000/api/'),
        equals('http://192.168.1.5:5000/api/v1'),
      );
    });

    test('Corrects accidental ?v1 typo to /v1', () {
      expect(
        ApiConfig.normalizeUrl('http://10.0.2.2:5000/api?v1'),
        equals('http://10.0.2.2:5000/api/v1'),
      );
      expect(
        ApiConfig.normalizeUrl('http://192.168.1.5:5000/api?v1'),
        equals('http://192.168.1.5:5000/api/v1'),
      );
    });

    test('Preserves already correct /api/v1 and https scheme', () {
      expect(
        ApiConfig.normalizeUrl('http://192.168.1.5:5000/api/v1'),
        equals('http://192.168.1.5:5000/api/v1'),
      );
      expect(
        ApiConfig.normalizeUrl('https://api.alphaxgym.com'),
        equals('https://api.alphaxgym.com/api/v1'),
      );
    });

    test('Defaults to productionUrl on empty or whitespace input', () {
      expect(ApiConfig.normalizeUrl(''), equals(ApiConfig.productionUrl));
      expect(ApiConfig.normalizeUrl('   '), equals(ApiConfig.productionUrl));
    });
  });

  group('ApiConfig Production Default & Platform Resolution Tests', () {
    test('Default baseUrl on all platforms is verified HTTPS productionUrl', () {
      // Mobile Android
      ApiConfig.isWebOverride = false;
      ApiConfig.platformOverride = TargetPlatform.android;
      ApiConfig.isReleaseModeOverride = false;
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));

      // Mobile iOS
      ApiConfig.platformOverride = TargetPlatform.iOS;
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));

      // Web
      ApiConfig.isWebOverride = true;
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));

      // Windows Desktop
      ApiConfig.isWebOverride = false;
      ApiConfig.platformOverride = TargetPlatform.windows;
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));

      // Release Mode
      ApiConfig.isReleaseModeOverride = true;
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));
    });

    test('AppConstants.apiBaseUrl reflects ApiConfig.baseUrl', () {
      expect(AppConstants.apiBaseUrl, equals(ApiConfig.baseUrl));
    });

    test('Explicit ENV=local routes to localhostUrl', () {
      ApiConfig.envTargetOverride = 'local';
      expect(ApiConfig.baseUrl, equals(ApiConfig.localhostUrl));

      ApiConfig.envTargetOverride = 'dev';
      expect(ApiConfig.baseUrl, equals(ApiConfig.localhostUrl));

      ApiConfig.envTargetOverride = 'localhost';
      expect(ApiConfig.baseUrl, equals(ApiConfig.localhostUrl));
    });

    test('Explicit ENV=emulator routes to emulatorUrl', () {
      ApiConfig.envTargetOverride = 'emulator';
      expect(ApiConfig.baseUrl, equals(ApiConfig.emulatorUrl));
    });

    test('Explicit ENV=lan routes to physicalLanUrl', () {
      ApiConfig.envTargetOverride = 'lan';
      expect(ApiConfig.baseUrl, equals(ApiConfig.physicalLanUrl));

      ApiConfig.envTargetOverride = 'physical';
      expect(ApiConfig.baseUrl, equals(ApiConfig.physicalLanUrl));
    });

    test('Explicit ENV=production routes to productionUrl', () {
      ApiConfig.envTargetOverride = 'production';
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));
    });
  });

  group('ApiConfig Loopback Pruning & Persistence Tests', () {
    test('isInvalidLoopback detects unusable loopbacks on mobile', () {
      ApiConfig.isWebOverride = false;
      ApiConfig.platformOverride = TargetPlatform.android;

      expect(ApiConfig.isInvalidLoopback('http://localhost:5000/api/v1'), isTrue);
      expect(ApiConfig.isInvalidLoopback('http://127.0.0.1:5000/api/v1'), isTrue);
      expect(ApiConfig.isInvalidLoopback('http://192.168.1.5:5000/api/v1'), isFalse);
      expect(ApiConfig.isInvalidLoopback(ApiConfig.productionUrl), isFalse);
    });

    test('isInvalidLoopback detects loopbacks in release mode on any platform', () {
      ApiConfig.isReleaseModeOverride = true;

      expect(ApiConfig.isInvalidLoopback('http://localhost:5000/api/v1'), isTrue);
      expect(ApiConfig.isInvalidLoopback('http://127.0.0.1:5000/api/v1'), isTrue);
    });

    test('initialize() prunes stale localhost:5000 in SharedPreferences on mobile', () async {
      ApiConfig.isWebOverride = false;
      ApiConfig.platformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        ApiConfig.storageKey: 'http://localhost:5000/api/v1',
      });

      await ApiConfig.initialize();

      expect(ApiConfig.customServerUrl, isNull);
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ApiConfig.storageKey), isFalse);
    });

    test('initialize() preserves valid custom LAN IP override', () async {
      ApiConfig.isWebOverride = false;
      ApiConfig.platformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        ApiConfig.storageKey: 'http://192.168.1.200:5000',
      });

      await ApiConfig.initialize();

      expect(ApiConfig.customServerUrl, equals('http://192.168.1.200:5000/api/v1'));
      expect(ApiConfig.baseUrl, equals('http://192.168.1.200:5000/api/v1'));
    });

    test('initialize() preserves valid custom HTTPS remote server override', () async {
      SharedPreferences.setMockInitialValues({
        ApiConfig.storageKey: 'https://staging.alphaxgym.com/api/v1',
      });

      await ApiConfig.initialize();

      expect(ApiConfig.customServerUrl, equals('https://staging.alphaxgym.com/api/v1'));
      expect(ApiConfig.baseUrl, equals('https://staging.alphaxgym.com/api/v1'));
    });

    test('setCustomUrl persists valid override and clears cleanly', () async {
      await ApiConfig.setCustomUrl('http://192.168.1.200:5000');
      expect(ApiConfig.baseUrl, equals('http://192.168.1.200:5000/api/v1'));
      expect(AppConstants.apiBaseUrl, equals('http://192.168.1.200:5000/api/v1'));

      // Clearing custom URL restores default
      await ApiConfig.setCustomUrl(null);
      expect(ApiConfig.customServerUrl, isNull);
      expect(ApiConfig.baseUrl, equals(ApiConfig.productionUrl));
    });
  });

  group('NetworkExceptions Diagnostics Tests', () {
    test('Diagnoses SocketException connection refused', () {
      final exc = SocketException('OS Error: Connection refused, errno = 111', osError: const OSError('Connection refused', 111));
      final details = NetworkExceptions.handle(exc, requestUrl: 'http://192.168.1.5:5000/api/v1');

      expect(details.isConnectionError, isTrue);
      expect(details.userMessage, contains('Connection refused'));
      expect(details.technicalDetails, contains('0.0.0.0:5000'));
    });

    test('Diagnoses TimeoutException', () {
      final exc = TimeoutException('Request timed out', const Duration(seconds: 12));
      final details = NetworkExceptions.handle(exc, requestUrl: 'http://192.168.1.5:5000/api/v1');

      expect(details.isConnectionError, isTrue);
      expect(details.userMessage, contains('Connection timed out'));
    });

    test('Diagnoses 404 endpoint not found', () {
      final exc = Exception('HTTP 404 Not Found');
      final details = NetworkExceptions.handle(exc, requestUrl: 'http://192.168.1.5:5000/api/v1');

      expect(details.statusCode, equals(404));
      expect(details.userMessage, contains('not found'));
    });
  });
}
