import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/network/network_exceptions.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
  });

  group('ApiConfig Runtime Override & Resolution Tests', () {
    test('AppConstants.apiBaseUrl reflects ApiConfig.baseUrl', () {
      expect(AppConstants.apiBaseUrl, equals(ApiConfig.baseUrl));
    });

    test('Custom runtime URL override overrides platform defaults', () async {
      await ApiConfig.setCustomUrl('http://192.168.1.200:5000');
      expect(ApiConfig.baseUrl, equals('http://192.168.1.200:5000/api/v1'));
      expect(AppConstants.apiBaseUrl, equals('http://192.168.1.200:5000/api/v1'));

      // Clearing custom URL restores default
      await ApiConfig.setCustomUrl(null);
      expect(ApiConfig.customServerUrl, isNull);
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
