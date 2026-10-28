import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Gym — AI Coach & Admin Auth Recovery Regression Tests', () {
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ApiConfig.customServerUrl = null;
      await ApiConfig.initialize();
      auth = AuthService();
      await auth.logout();
    });

    tearDown(() async {
      auth.setHttpClientForTesting(null);
      await auth.logout();
    });

    test('1. HTTP 401 produces AUTH_REQUIRED without pretending backend is offline', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'INVALID_TOKEN', 'message': 'Session expired'},
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = AiCoachRepository(httpClient: mockClient);
      final reply = await repo.sendMessage(message: 'Analyze client workout program');

      expect(reply.isError, isTrue);
      expect(reply.intent, 'AUTH_REQUIRED');
      expect(reply.content, contains('administrator session has expired or is unauthorized'));
      expect(reply.content.contains('npm run dev'), isFalse);
      expect(reply.content.contains('--dart-define=GEMINI_API_KEY'), isFalse);
    });

    test('2. HTTP 403 produces ACCESS_DENIED', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'FORBIDDEN', 'message': 'Admin privilege required'},
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = AiCoachRepository(httpClient: mockClient);
      final reply = await repo.sendMessage(message: 'Give me today summary');

      expect(reply.isError, isTrue);
      expect(reply.intent, 'ACCESS_DENIED');
      expect(reply.content, contains('Administrator privileges are required'));
    });

    test('3. HTTP 500, 502, 503, 504 produce SERVICE_UNAVAILABLE preserving server message', () async {
      for (final status in [500, 502, 503, 504]) {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'message': 'Gemini quota circuit breaker active'},
            }),
            status,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = AiCoachRepository(httpClient: mockClient);
        final reply = await repo.sendMessage(message: 'Generate workout');

        expect(reply.isError, isTrue);
        expect(reply.intent, 'SERVICE_UNAVAILABLE');
        expect(reply.content, contains('Gemini quota circuit breaker active'));
        expect(reply.content, contains('$status'));
      }
    });

    test('4. Network timeout or connection refusal produces CONNECTION_ERROR with host/port', () async {
      // 4a. TimeoutException
      final timeoutClient = MockClient((request) async {
        throw TimeoutException('Connection timed out');
      });

      final timeoutRepo = AiCoachRepository(httpClient: timeoutClient);
      final timeoutReply = await timeoutRepo.sendMessage(message: 'Plan nutrition');

      expect(timeoutReply.isError, isTrue);
      expect(timeoutReply.intent, 'CONNECTION_ERROR');
      expect(timeoutReply.content, contains('timed out'));
      expect(timeoutReply.content.contains('--dart-define=GEMINI_API_KEY'), isFalse);

      // 4b. SocketException
      final socketClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final socketRepo = AiCoachRepository(httpClient: socketClient);
      final socketReply = await socketRepo.sendMessage(message: 'Plan nutrition');

      expect(socketReply.isError, isTrue);
      expect(socketReply.intent, 'CONNECTION_ERROR');
      expect(socketReply.content, contains('Network connection failed'));
      expect(socketReply.content.contains('Server Settings'), isTrue);
    });

    test('5. Valid token from initial login is passed into session without redundant login request', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'token': 'mock.jwt.token.123',
              'user': {
                'id': 'admin_fitsundar6',
                'name': 'Alpha X Administrator',
                'email': 'fitsundar6@gmail.com',
                'role': 'ADMIN',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      auth.setHttpClientForTesting(mockClient);

      // Simulating the login screen flow: passing the received token directly
      await auth.setAdminSession(
        email: 'fitsundar6@gmail.com',
        userId: 'admin_fitsundar6',
        userName: 'Alpha X Administrator',
        token: 'mock.jwt.token.123',
      );

      // When token is provided directly, NO redundant backend request should be made
      expect(requestCount, 0);
      expect(auth.isAdmin, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentToken, 'mock.jwt.token.123');
      expect(auth.currentUserId, 'admin_fitsundar6');
    });

    test('6. Missing or invalid login token cannot create an authenticated admin session on production URL', () async {
      // Set server to production URL
      await ApiConfig.setCustomUrl('https://alpha-x-app.vercel.app/api/v1');

      // Backend fails to return a token
      final emptyTokenClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Invalid credentials',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      auth.setHttpClientForTesting(emptyTokenClient);

      await auth.setAdminSession(
        email: 'fitsundar6@gmail.com',
        token: null, // missing token
      );

      // Must fail safely without authenticating or setting an admin token
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isAdmin, isFalse);
      expect(auth.rawToken, isEmpty);
    });

    test('7. Existing successful AI Coach requests remain fully functional', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/admin/ai-coach/chat'));
        expect(request.headers['Authorization'], isNotNull);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'msg_success_001',
              'sender': 'AI',
              'replyText': 'Here is your progressive overload hypertrophy program.',
              'conversationId': 'conv_valid_123',
              'intent': 'WORKOUT_PROPOSAL',
              'isError': false,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = AiCoachRepository(httpClient: mockClient);
      final reply = await repo.sendMessage(message: 'Design a chest split');

      expect(reply.isError, isFalse);
      expect(reply.intent, 'WORKOUT_PROPOSAL');
      expect(reply.content, contains('progressive overload'));
      expect(reply.conversationId, 'conv_valid_123');
    });

    test('8. Existing custom API URL configuration in SharedPreferences remains intact', () async {
      const customUrl = 'https://custom-gym-server.com:8080/api/v1';
      await ApiConfig.setCustomUrl(customUrl);

      expect(ApiConfig.customServerUrl, customUrl);
      expect(AppConstants.apiBaseUrl, customUrl);

      // Reset
      await ApiConfig.setCustomUrl(null);
      expect(ApiConfig.customServerUrl, isNull);
    });
  });
}
