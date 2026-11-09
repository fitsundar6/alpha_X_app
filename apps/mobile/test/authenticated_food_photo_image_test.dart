import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/data/models/food_photo_model.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/presentation/widgets/authenticated_food_photo_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthenticatedFoodPhotoImage Widget & URL Resolution Tests', () {
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = AuthService();
      await auth.initialize();
      AuthenticatedFoodPhotoImage.clearCache();
    });

    tearDown(() async {
      await auth.logout();
      AuthenticatedFoodPhotoImage.clearCache();
    });

    test('TEST 1: AppConstants.resolveImageUrl prevents duplicate /api/v1', () {
      final relativeUrl = '/api/v1/food-photos/photo_123/image';
      final resolved = AppConstants.resolveImageUrl(relativeUrl);

      // Must never contain /api/v1/api/v1
      expect(resolved.contains('/api/v1/api/v1'), isFalse);
      expect(resolved.endsWith('/api/v1/food-photos/photo_123/image'), isTrue);

      // Absolute URL returns unchanged
      final absoluteUrl = 'https://custom-storage.com/meal_photos/photo_123.jpg';
      expect(AppConstants.resolveImageUrl(absoluteUrl), equals(absoluteUrl));
    });

    testWidgets('TEST 2: Empty photoUrl renders fallback restaurant placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthenticatedFoodPhotoImage(
              photoUrl: '',
              photoId: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('TEST 3: fromModel factory correctly binds model properties', (tester) async {
      final photo = FoodPhotoModel(
        id: 'photo_abc_123',
        clientId: 'AXG-8888',
        clientName: 'Sundar Athlete',
        dateString: '2026-10-01',
        mealType: 'Dinner',
        capturedAt: DateTime(2026, 10, 1, 20, 0),
        status: 'PENDING',
        photoUrl: '',
      );

      final widget = AuthenticatedFoodPhotoImage.fromModel(photo, height: 120);
      expect(widget.photoId, equals('photo_abc_123'));
      expect(widget.height, equals(120));
      expect(widget.isPendingSync, isFalse);
    });

    testWidgets('TEST 4: Shows loading indicator then error state with retry on network failure', (tester) async {
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
        clientId: 'AXG-8888',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthenticatedFoodPhotoImage(
              photoUrl: 'https://invalid-host-for-test.alphaxgym.invalid/photo.jpg',
              height: 200,
            ),
          ),
        ),
      );

      // Pumps the initial frame to show loading
      await tester.pump();

      // After async timeout/failure, error state is displayed with retry option
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(find.text('Tap to retry'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('TEST 5: Data URI image displays directly without network request', (tester) async {
      // 1x1 transparent PNG data URI
      const sampleDataUri =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthenticatedFoodPhotoImage(
              photoUrl: sampleDataUri,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsNothing);
    });
  });
}

