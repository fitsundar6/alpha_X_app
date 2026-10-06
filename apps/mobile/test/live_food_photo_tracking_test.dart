import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/data/models/food_photo_model.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/data/services/food_photo_tracking_service.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/presentation/screens/live_food_camera_screen.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/presentation/screens/my_food_photos_screen.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/presentation/screens/admin_food_photos_monitoring_screen.dart';
import 'package:alpha_x_gym/features/dashboard/admin_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Food Photo Tracking & Admin Verification Tests', () {
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      await auth.initialize();
    });

    tearDown(() async {
      await auth.logout();
    });

    test('TEST 1: FoodPhotoModel serialization, deserialization, and status logic', () {
      final now = DateTime(2026, 10, 1, 13, 15);
      final photo = FoodPhotoModel(
        id: 'photo_test_123',
        clientId: 'AXG-8888',
        clientName: 'Sundar Athlete',
        dateString: '2026-10-01',
        mealType: 'Lunch',
        capturedAt: now,
        status: 'PENDING',
        clientNote: 'Chicken rice + veggies',
        adminNote: 'Great balanced meal',
        photoUrl: '/api/v1/food-photos/photo_test_123/image',
      );

      expect(photo.isPending, isTrue);
      expect(photo.isVerified, isFalse);
      expect(photo.isNeedsAttention, isFalse);
      expect(photo.formattedTime, '1:15 PM');
      expect(photo.formattedDate, '01 Oct 2026');

      final json = photo.toJson();
      final revived = FoodPhotoModel.fromJson(json);

      expect(revived.id, photo.id);
      expect(revived.clientId, photo.clientId);
      expect(revived.clientName, photo.clientName);
      expect(revived.mealType, 'Lunch');
      expect(revived.clientNote, 'Chicken rice + veggies');
      expect(revived.status, 'PENDING');

      final verifiedPhoto = photo.copyWith(status: 'VERIFIED');
      expect(verifiedPhoto.isVerified, isTrue);

      final attentionPhoto = photo.copyWith(status: 'NEEDS_ATTENTION');
      expect(attentionPhoto.isNeedsAttention, isTrue);
    });

    test('TEST 2: FoodPhotoTrackingService offline queue storage when server offline', () async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
        clientId: 'AXG-8888',
        userName: 'Sundar Athlete',
      );

      final service = FoodPhotoTrackingService();
      final capturedTime = DateTime(2026, 10, 1, 12, 30);

      // Simulates recording photo in offline environment
      final result = await service.recordLiveFoodPhoto(
        imageBase64: 'sample_base64_data',
        mealType: 'Breakfast',
        capturedAt: capturedTime,
        clientNote: 'Oatmeal and berries',
      );

      expect(result.mealType, 'Breakfast');
      expect(result.clientId, 'AXG-8888');
      expect(result.clientNote, 'Oatmeal and berries');
      expect(result.isPendingSync, isTrue, reason: 'Should be queued for offline sync');

      // Verify photo is available in client photo list
      final photos = await service.getClientFoodPhotos();
      expect(photos.isNotEmpty, isTrue);
      expect(photos.any((p) => p.mealType == 'Breakfast'), isTrue);
    });

    testWidgets('TEST 3: LiveFoodCameraScreen renders live camera UI, viewfinder, and capture button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiveFoodCameraScreen(initialMealType: 'Lunch'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LIVE FOOD PHOTO'), findsOneWidget);
      expect(find.byType(LiveFoodCameraScreen), findsOneWidget);
    });

    testWidgets('TEST 4: MyFoodPhotosScreen renders daily tracking summary, meal pills, and list', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'sundar@alphaxgym.com',
        clientId: 'AXG-8888',
        userName: 'Sundar Athlete',
      );

      // Pre-populate SharedPreferences with cached photos
      final prefs = await SharedPreferences.getInstance();
      final samplePhoto = FoodPhotoModel(
        id: 'cached_photo_1',
        clientId: 'AXG-8888',
        clientName: 'Sundar Athlete',
        dateString: '2026-10-01',
        mealType: 'Lunch',
        capturedAt: DateTime(2026, 10, 1, 13, 10),
        status: 'VERIFIED',
        clientNote: 'Chicken and brown rice',
        adminNote: 'Followed diet properly',
        photoUrl: '',
      );
      await prefs.setStringList('alpha_x_cached_my_food_photos', [jsonEncode(samplePhoto.toJson())]);

      await tester.pumpWidget(
        const MaterialApp(
          home: MyFoodPhotosScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MY FOOD PHOTOS'), findsOneWidget);
      expect(find.text("TODAY'S FOOD HABITS"), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsWidgets);
      expect(find.text('Snack'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('TAKE FOOD PHOTO'), findsOneWidget);
    });

    testWidgets('TEST 5: AdminFoodPhotosMonitoringScreen renders filters, summary cards, and verify options', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'fitsundar6@gmail.com',
        userId: 'admin_alex_stone',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminFoodPhotosMonitoringScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT FOOD PHOTOS'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('ATTENTION'), findsOneWidget);
      expect(find.text('Search client by name or ID...'), findsOneWidget);
    });

    testWidgets('TEST 6: AdminMainDashboardScreen navigates to tab 9 (Client Food Photos) without RangeError', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'fitsundar6@gmail.com',
        userId: 'admin_alex_stone',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Admin drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Find and ensure visible "Client Food Photos" in drawer
      final drawerFoodPhotosItem = find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Client Food Photos'),
      );
      await tester.ensureVisible(drawerFoodPhotosItem);
      await tester.pumpAndSettle();
      expect(drawerFoodPhotosItem, findsOneWidget);
      await tester.tap(drawerFoodPhotosItem);
      await tester.pumpAndSettle();

      // Verify no RangeError occurred, AppBar displays tab title, and photo monitoring screen is rendered
      expect(find.text('📸 CLIENT FOOD PHOTOS'), findsOneWidget);
      expect(find.byType(AdminFoodPhotosMonitoringScreen), findsOneWidget);
    });
  });
}
