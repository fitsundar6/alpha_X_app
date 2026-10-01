import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/confirmed_meal_photo.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/scanned_food_detection.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/dashboard/widgets/admin_meal_photo_viewer_dialog.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('ConfirmedMealPhoto & FoodLogEntry Domain Tests', () {
    test('ConfirmedMealPhoto serializes to and from JSON accurately', () {
      final json = {
        'id': 'photo_test_123',
        'clientId': 'athlete_test_abc',
        'mealId': 'meal_lunch_456',
        'dateString': '2026-10-01',
        'mealType': 'LUNCH',
        'storagePath': 'uploads/meal_photos/athlete_test_abc/2026/10/photo_test_123.jpg',
        'photoUrl': '/api/v1/food-photos/photo_test_123/image',
        'weightSource': 'AI_ESTIMATE',
        'totalCalories': 540.0,
        'totalProtein': 45.0,
        'totalCarbs': 60.0,
        'totalFat': 12.0,
        'totalFiber': 5.0,
        'confirmedAt': '2026-10-01T12:30:00.000Z',
        'items': [
          {
            'name': 'Brown Rice',
            'grams': 180,
            'calories': 216,
            'protein': 5,
            'carbs': 45,
            'fat': 1.8,
            'fiber': 3.2,
            'weightSource': 'AI_ESTIMATE',
          },
          {
            'name': 'Grilled Chicken Breast',
            'grams': 150,
            'calories': 247.5,
            'protein': 46.5,
            'carbs': 0,
            'fat': 5.4,
            'fiber': 0,
            'weightSource': 'AI_ESTIMATE',
          }
        ]
      };

      final photo = ConfirmedMealPhoto.fromJson(json);

      expect(photo.id, 'photo_test_123');
      expect(photo.mealId, 'meal_lunch_456');
      expect(photo.mealType, 'LUNCH');
      expect(photo.totalCalories, 540.0);
      expect(photo.totalProtein, 45.0);
      expect(photo.totalCarbs, 60.0);
      expect(photo.totalFat, 12.0);
      expect(photo.totalFiber, 5.0);
      expect(photo.weightSource, 'AI_ESTIMATE');
      expect(photo.items.length, 2);
      expect(photo.items[0]['name'], 'Brown Rice');

      final serialized = photo.toJson();
      expect(serialized['id'], 'photo_test_123');
      expect(serialized['totalCalories'], 540.0);
      expect(serialized['mealType'], 'LUNCH');
    });

    test('FoodLogEntry supports photo link metadata and backwards compatibility', () {
      // 1. Manually logged entry without photo
      final manualEntry = FoodLogEntry(
        id: 'log_manual_1',
        clientId: 'athlete_1',
        dateString: '2026-10-01',
        mealType: MealType.breakfast,
        foodId: 'food_oats_1',
        foodName: 'Oats & Milk',
        quantity: 1,
        servingUnit: 'bowl',
        servingSize: 1,
        baseCalories: 300,
        baseProtein: 12,
        baseCarbs: 45,
        baseFat: 6,
        baseFiber: 4,
        loggedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(manualEntry.photoAvailable, isFalse);
      expect(manualEntry.mealPhotoId, isNull);
      expect(manualEntry.weightSource, 'CLIENT_ENTERED');
      expect(manualEntry.mealId, isNull);

      // Verify serialization roundtrip for manual entry
      final manualJson = manualEntry.toJson();
      final reconstitutedManual = FoodLogEntry.fromJson(manualJson);
      expect(reconstitutedManual.photoAvailable, isFalse);
      expect(reconstitutedManual.mealPhotoId, isNull);

      // 2. Camera-confirmed logged entry with photo
      final cameraConfirmedEntry = manualEntry.copyWith(
        photoAvailable: true,
        mealPhotoId: 'photo_abc_999',
        weightSource: 'AI_ESTIMATE',
        mealId: 'meal_grp_100',
      );

      expect(cameraConfirmedEntry.photoAvailable, isTrue);
      expect(cameraConfirmedEntry.mealPhotoId, 'photo_abc_999');
      expect(cameraConfirmedEntry.weightSource, 'AI_ESTIMATE');
      expect(cameraConfirmedEntry.mealId, 'meal_grp_100');

      final photoJson = cameraConfirmedEntry.toJson();
      expect(photoJson['photoAvailable'], isTrue);
      expect(photoJson['mealPhotoId'], 'photo_abc_999');
      expect(photoJson['weightSource'], 'AI_ESTIMATE');
      expect(photoJson['mealId'], 'meal_grp_100');
    });

    test('Portion editing updates weight source to CLIENT_ENTERED', () {
      const originalAiItem = ScannedFoodItem(
        name: 'Paneer Tikka',
        estimatedGrams: 100.0,
        servingDisplay: '100 g',
        calories: 260.0,
        protein: 18.0,
        carbs: 6.0,
        fat: 18.0,
        fiber: 1.0,
        weightSource: 'AI_ESTIMATE',
      );

      expect(originalAiItem.weightSource, 'AI_ESTIMATE');

      // User changes portion to 150g -> tag as CLIENT_ENTERED
      final userEditedItem = originalAiItem.updatePortionGrams(150.0, newWeightSource: 'CLIENT_ENTERED');
      expect(userEditedItem.estimatedGrams, 150.0);
      expect(userEditedItem.weightSource, 'CLIENT_ENTERED');
      expect(userEditedItem.calories, 390.0);
      expect(userEditedItem.protein, 27.0);

      // Convert to food log entry and verify weightSource preserved
      final log = userEditedItem.toFoodLogEntry(
        clientId: 'client_777',
        dateString: '2026-10-01',
        mealType: MealType.dinner,
        mealPhotoId: 'photo_paneer_1',
        photoAvailable: true,
      );

      expect(log.weightSource, 'CLIENT_ENTERED');
      expect(log.photoAvailable, isTrue);
      expect(log.mealPhotoId, 'photo_paneer_1');
    });
  });

  group('Admin Meal Photo Viewer Dialog Tests', () {
    testWidgets('Displays meal photo metadata, macros, weight source and interactive zoom viewer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mealPhotoData = {
        'id': 'photo_full_test_1',
        'clientId': 'client_alpha_1',
        'mealType': 'Breakfast',
        'confirmedAt': '2026-10-01T08:15:00.000Z',
        'weightSource': 'AI_ESTIMATE',
        'totalCalories': 520.0,
        'totalProtein': 28.0,
        'totalCarbs': 65.0,
        'totalFat': 18.0,
        'totalFiber': 6.0,
        'items': [
          {'name': 'Rice', 'grams': 150, 'calories': 195, 'protein': 4, 'carbs': 42, 'fat': 0.4, 'fiber': 0.6},
          {'name': 'Eggs', 'grams': 100, 'calories': 155, 'protein': 13, 'carbs': 1.1, 'fat': 11, 'fiber': 0},
          {'name': 'Vegetables', 'grams': 120, 'calories': 45, 'protein': 2.5, 'carbs': 9, 'fat': 0.5, 'fiber': 3},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMealPhotoViewerDialog(
              mealPhoto: mealPhotoData,
              clientName: 'Rahul Sharma',
              clientId: 'client_alpha_1',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Header and Client
      expect(find.text('BREAKFAST PHOTO • RAHUL SHARMA'), findsOneWidget);
      expect(find.textContaining('client_alpha_1'), findsOneWidget);

      // 2. Verify Weight Source Badge
      expect(find.text('📷 AI ESTIMATED PORTION'), findsOneWidget);
      expect(find.text('Pinch or double tap to zoom'), findsOneWidget);

      // 3. Verify Macro Totals
      expect(find.text('520 kcal'), findsOneWidget);
      expect(find.text('28.0g'), findsOneWidget);
      expect(find.text('65.0g'), findsOneWidget);
      expect(find.text('18.0g'), findsOneWidget);
      expect(find.text('6.0g'), findsOneWidget);

      // 4. Verify Food Items Breakdown
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('Vegetables'), findsOneWidget);

      // 5. Verify Actions
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('Smart scale badge displays when weightSource is SMART_SCALE_BLE', (tester) async {
      final mealPhotoData = {
        'id': 'photo_smart_scale_1',
        'clientId': 'client_scale_1',
        'mealType': 'Dinner',
        'confirmedAt': '2026-10-01T20:00:00.000Z',
        'weightSource': 'SMART_SCALE_BLE',
        'totalCalories': 610.0,
        'totalProtein': 40.0,
        'totalCarbs': 70.0,
        'totalFat': 15.0,
        'totalFiber': 8.0,
        'items': [
          {'name': 'Chicken Breast', 'grams': 180, 'calories': 297, 'protein': 55.8, 'carbs': 0, 'fat': 6.5, 'fiber': 0}
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMealPhotoViewerDialog(
              mealPhoto: mealPhotoData,
              clientName: 'Vikram Singh',
              clientId: 'client_scale_1',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('⚖️ SMART SCALE MEASURED'), findsOneWidget);
    });
  });
}
