import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/auth/secure_token_storage.dart';
import 'package:alpha_x_gym/features/profile/client_edit_profile_screen.dart';
import 'package:alpha_x_gym/features/profile/admin_edit_client_profile_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  group('Alpha X Gym - Edit Client Profile Unit & Widget Tests', () {
    late AuthService auth;
    late WorkoutRepository workoutRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      auth.resetForTesting();
      workoutRepo = WorkoutRepository();
    });

    test('1. AuthService.updateLocalProfile updates state and persists session', () async {
      final initialSession = {
        'role': 'CLIENT',
        'id': 'athlete_test_01',
        'clientId': 'AXG-7777',
        'email': 'athlete@alphaxgym.com',
        'name': 'Original Name',
        'phone': '+15551112222',
        'photoUrl': '',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': 'mock_token',
        'clientProfile': {
          'weightKg': 70.0,
          'heightCm': 172.0,
          'primaryGoal': 'General Fitness',
        },
      };

      await SecureTokenStorage.writeAuthToken('mock_token');
      await SecureTokenStorage.writeSessionData(initialSession);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(initialSession));

      await auth.initialize();
      expect(auth.currentUserName, equals('Original Name'));
      expect(auth.currentUserPhone, equals('+15551112222'));
      expect(auth.clientProfile['weightKg'], equals(70.0));

      // Update profile locally
      await auth.updateLocalProfile({
        'name': 'Updated Champion Name',
        'phone': '+15559998888',
        'photoUrl': 'avatar_updated',
        'weightKg': 74.5,
        'primaryGoal': 'Muscle Gain',
        'fitnessLevel': 'ADVANCED',
      });

      // Verify immediate in-memory update
      expect(auth.currentUserName, equals('Updated Champion Name'));
      expect(auth.currentUserPhone, equals('+15559998888'));
      expect(auth.currentUserPhotoUrl, equals('avatar_updated'));
      expect(auth.clientProfile['weightKg'], equals(74.5));
      expect(auth.clientProfile['primaryGoal'], equals('Muscle Gain'));
      expect(auth.clientProfile['fitnessLevel'], equals('ADVANCED'));

      // Verify persistence to local session
      final storedSession = await auth.getActiveLocalSession();
      expect(storedSession, isNotNull);
      expect(storedSession!['name'], equals('Updated Champion Name'));
      expect(storedSession['phone'], equals('+15559998888'));
      expect(storedSession['photoUrl'], equals('avatar_updated'));
      expect((storedSession['clientProfile'] as Map)['weightKg'], equals(74.5));
    });

    testWidgets('2. ClientEditProfileScreen renders fields and pre-fills from AuthService', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessionData = {
        'role': 'CLIENT',
        'id': 'athlete_test_02',
        'clientId': 'AXG-8888',
        'email': 'client@alphaxgym.com',
        'name': 'Sarah Connor',
        'phone': '+15554443333',
        'photoUrl': '',
        'onboardingCompleted': true,
        'status': 'APPROVED',
        'token': 'mock_token',
        'clientProfile': {
          'age': 29,
          'weightKg': 62.0,
          'heightCm': 168.0,
          'gender': 'Female',
          'fitnessLevel': 'ADVANCED',
          'primaryGoal': 'Strength',
          'activityLevel': 'ACTIVE',
        },
      };

      await SecureTokenStorage.writeAuthToken('mock_token');
      await SecureTokenStorage.writeSessionData(sessionData);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alpha_x_local_active_session', jsonEncode(sessionData));
      await auth.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientEditProfileScreen(workoutRepository: workoutRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify screen title and action
      expect(find.text('EDIT MY PROFILE'), findsOneWidget);
      expect(find.text('SAVE'), findsOneWidget);
      expect(find.text('Live Avatar Preview'), findsOneWidget);

      // Verify pre-filled data
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('+15554443333'), findsOneWidget);
      expect(find.text('62.0'), findsOneWidget);
      expect(find.text('168.0'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);

      // Verify Cancel button is present
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('3. ClientEditProfileScreen validates required name length', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientEditProfileScreen(workoutRepository: workoutRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Clear the name field
      final nameField = find.widgetWithText(TextFormField, 'Full Name');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'A');
      await tester.pumpAndSettle();

      // Tap SAVE in the AppBar
      final saveBtn = find.text('SAVE');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Validator error should appear
      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('4. AdminEditClientProfileScreen renders client data & protected banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final clientMap = {
        'id': 'client_uuid_123',
        'clientId': 'AXG-0042',
        'name': 'Marcus Vance',
        'email': 'marcus@alphaxgym.com',
        'phone': '+15557778888',
        'photoUrl': '',
        'weightKg': 82.5,
        'heightCm': 180.0,
        'age': 31,
        'gender': 'Male',
        'fitnessLevel': 'INTERMEDIATE',
        'primaryGoal': 'Muscle Gain',
        'trainingExperience': '1-2 years',
        'activityLevel': 'ACTIVE',
        'hasCurrentInjury': false,
        'hasPreviousSurgery': false,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: AdminEditClientProfileScreen(
            client: clientMap,
            workoutRepository: workoutRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar and Banner
      expect(find.text('EDIT PROFILE'), findsOneWidget);
      expect(find.text('Client ID, email, role, and membership status are protected and cannot be changed here.'), findsOneWidget);
      expect(find.text('Client Avatar Preview'), findsOneWidget);

      // Verify pre-filled data
      expect(find.textContaining('Marcus Vance'), findsWidgets);
      expect(find.text('+15557778888'), findsOneWidget);
      expect(find.text('82.5'), findsOneWidget);
      expect(find.text('180.0'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);

      // Verify Save and Cancel actions
      expect(find.text('SAVE'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
