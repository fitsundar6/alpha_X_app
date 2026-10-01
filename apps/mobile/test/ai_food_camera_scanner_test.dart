import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/scanned_food_detection.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/services/ai_food_scanner_service.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/screens/ai_food_analysis_result_screen.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/screens/ai_food_camera_scanner_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('ScannedFoodItem Domain Model Tests', () {
    test('Proportionally scales nutrition when portion size is updated', () {
      final original = const ScannedFoodItem(
        name: 'Grilled Chicken Breast',
        category: 'Protein',
        estimatedGrams: 100.0,
        servingDisplay: '100 g',
        confidence: 0.95,
        calories: 165.0,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        fiber: 0.0,
        isEstimate: true,
        source: 'ALPHA_X_LIBRARY',
      );

      // Scale to 200g (2x)
      final scaled = original.updatePortionGrams(200.0);
      expect(scaled.estimatedGrams, 200.0);
      expect(scaled.servingDisplay, '200 g');
      expect(scaled.calories, 330.0);
      expect(scaled.protein, 62.0);
      expect(scaled.fat, 7.2);

      // Scale to 150g (1.5x)
      final scaled150 = original.updatePortionGrams(150.0);
      expect(scaled150.estimatedGrams, 150.0);
      expect(scaled150.calories, 247.5);
      expect(scaled150.protein, 46.5);
    });

    test('Converts correctly to FoodLogEntry for client food logging', () {
      final item = const ScannedFoodItem(
        name: 'Brown Rice',
        matchedFoodId: 'food_rice_brown',
        category: 'Rice & Meals',
        estimatedGrams: 180.0,
        servingDisplay: '180 g',
        calories: 216.0,
        protein: 5.0,
        carbs: 45.0,
        fat: 1.8,
        fiber: 3.2,
      );

      final logEntry = item.toFoodLogEntry(
        clientId: 'athlete_123',
        dateString: '2026-10-01',
        mealType: MealType.lunch,
      );

      expect(logEntry.clientId, 'athlete_123');
      expect(logEntry.dateString, '2026-10-01');
      expect(logEntry.mealType, MealType.lunch);
      expect(logEntry.foodName, 'Brown Rice');
      expect(logEntry.totalCalories, 216.0);
      expect(logEntry.totalProtein, 5.0);
      expect(logEntry.totalCarbs, 45.0);
      expect(logEntry.totalFat, 1.8);
      expect(logEntry.totalFiber, 3.2);
    });
  });

  group('AiMealScanResult Dynamic Aggregation & Serialization Tests', () {
    test('Calculates live totals across multiple detected foods on a plate', () {
      final meal = AiMealScanResult(
        scanId: 'scan_001',
        mealName: 'Plate: Rice + Chicken + Egg + Veggies',
        detectedAt: DateTime.now(),
        foods: const [
          ScannedFoodItem(
            name: 'White Rice',
            estimatedGrams: 150,
            servingDisplay: '150 g',
            calories: 195,
            protein: 4.0,
            carbs: 42.0,
            fat: 0.4,
            fiber: 0.6,
          ),
          ScannedFoodItem(
            name: 'Chicken Breast',
            estimatedGrams: 150,
            servingDisplay: '150 g',
            calories: 247.5,
            protein: 46.5,
            carbs: 0.0,
            fat: 5.4,
            fiber: 0.0,
          ),
          ScannedFoodItem(
            name: 'Boiled Egg',
            estimatedGrams: 50,
            servingDisplay: '1 egg',
            calories: 78,
            protein: 6.3,
            carbs: 0.6,
            fat: 5.3,
            fiber: 0.0,
          ),
          ScannedFoodItem(
            name: 'Steamed Broccoli',
            estimatedGrams: 80,
            servingDisplay: '80 g',
            calories: 28,
            protein: 2.2,
            carbs: 5.5,
            fat: 0.3,
            fiber: 2.1,
          ),
        ],
        totalCalories: 548.5,
        totalProtein: 59.0,
        totalCarbs: 48.1,
        totalFat: 11.4,
        totalFiber: 2.7,
      );

      expect(meal.liveCalories, 548.5);
      expect(meal.liveProtein, 59.0);
      expect(meal.liveCarbs, 48.1);
      expect(meal.liveFat, closeTo(11.4, 0.01));
      expect(meal.liveFiber, closeTo(2.7, 0.01));
    });

    test('Parses from JSON correctly with AI estimate and low confidence flags', () {
      final json = {
        'scanId': 'scan_test_123',
        'mealName': 'Post-Workout Lunch',
        'detectedAt': '2026-10-01T12:00:00.000Z',
        'isLowConfidence': false,
        'disclaimer': 'Visual estimate only.',
        'foods': [
          {
            'name': 'Paneer Tikka',
            'estimatedGrams': 120.0,
            'servingDisplay': '120 g',
            'confidence': 0.91,
            'calories': 320.0,
            'protein': 18.0,
            'carbs': 8.0,
            'fat': 24.0,
            'fiber': 1.5,
            'isEstimate': true,
            'source': 'ALPHA_X_LIBRARY',
          }
        ],
        'totalCalories': 320.0,
        'totalProtein': 18.0,
        'totalCarbs': 8.0,
        'totalFat': 24.0,
        'totalFiber': 1.5,
      };

      final result = AiMealScanResult.fromJson(json);
      expect(result.scanId, 'scan_test_123');
      expect(result.mealName, 'Post-Workout Lunch');
      expect(result.foods.length, 1);
      expect(result.foods.first.name, 'Paneer Tikka');
      expect(result.foods.first.isFromFoodLibrary, isTrue);
      expect(result.totalCalories, 320.0);
      expect(result.disclaimer, 'Visual estimate only.');
    });
  });

  group('AiFoodScannerService Tests', () {
    test('Offline fallback returns verified balanced meal with library foods', () {
      final service = AiFoodScannerService();
      final fallback = service.generateOfflineFallbackResult();
      expect(fallback.foods.length, 3);
      expect(fallback.foods.first.name, 'Grilled Chicken Breast');
      expect(fallback.totalCalories, closeTo(511.3, 0.5));
      expect(fallback.isLowConfidence, isTrue);
    });
  });

  group('AiFoodAnalysisResultScreen Widget & User Confirmation Tests', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
    });

    testWidgets('Displays detected foods, AI estimates, and allows confirmation to Food Log', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scanResult = AiMealScanResult(
        scanId: 'scan_widget_test',
        mealName: 'Chicken & Rice Lunch',
        detectedAt: DateTime.now(),
        foods: const [
          ScannedFoodItem(
            name: 'Grilled Chicken Breast',
            estimatedGrams: 150.0,
            servingDisplay: '150 g',
            confidence: 0.95,
            calories: 247.5,
            protein: 46.5,
            carbs: 0.0,
            fat: 5.4,
            fiber: 0.0,
            isEstimate: true,
            source: 'ALPHA_X_LIBRARY',
          ),
          ScannedFoodItem(
            name: 'Cooked White Rice',
            estimatedGrams: 200.0,
            servingDisplay: '200 g',
            confidence: 0.92,
            calories: 260.0,
            protein: 5.4,
            carbs: 56.0,
            fat: 0.6,
            fiber: 0.8,
            isEstimate: true,
            source: 'ALPHA_X_LIBRARY',
          ),
        ],
        totalCalories: 507.5,
        totalProtein: 51.9,
        totalCarbs: 56.0,
        totalFat: 6.0,
        totalFiber: 0.8,
        isLowConfidence: false,
      );

      final dateStr = repository.getTodayDateString();
      // Clear today's entries first to accurately count newly logged foods
      repository.clearEntriesForDate(dateStr);

      await tester.pumpWidget(
        MaterialApp(
          home: AiFoodAnalysisResultScreen(
            scanResult: scanResult,
            repository: repository,
            initialMealType: MealType.lunch,
            dateString: dateStr,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Screen Header and Content
      expect(find.text('DETECTED MEAL ANALYSIS'), findsOneWidget);
      expect(find.text('TOTAL MEAL NUTRITION'), findsOneWidget);
      expect(find.text('AI ESTIMATE'), findsOneWidget);
      expect(find.text('Grilled Chicken Breast'), findsOneWidget);
      expect(find.text('Cooked White Rice'), findsOneWidget);

      // 2. Verify Total Calories
      expect(find.text('508'), findsOneWidget); // 507.5 rounded to 508

      // 3. Verify Confirm & Add button exists
      final confirmButton = find.text('CONFIRM & ADD TO FOOD LOG');
      expect(confirmButton, findsOneWidget);

      // 4. Tap Confirm & Add
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // 5. Verify repository logged the 2 food entries into Lunch
      final summary = repository.getDailyMacroSummary(dateStr);
      final lunchEntries = summary.mealSummaries[MealType.lunch]!.entries;
      expect(lunchEntries.length, 2);
      expect(lunchEntries.any((e) => e.foodName == 'Grilled Chicken Breast'), isTrue);
      expect(lunchEntries.any((e) => e.foodName == 'Cooked White Rice'), isTrue);

      // 6. Verify consumed calories updated
      expect(summary.consumedCalories, closeTo(507.5, 1.0));
    });
  });

  group('Camera Screen Strict Live Camera Constraints', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
    });

    testWidgets('Live Camera UI has shutter and NO gallery/file upload buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AiFoodCameraScannerScreen(
            repository: repository,
            initialMealType: MealType.lunch,
            dateString: repository.getTodayDateString(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify guidance message
      expect(find.text('Place your full meal inside the frame'), findsOneWidget);
      expect(find.text('AI LIVE SCANNER'), findsOneWidget);
      expect(find.text('Live Camera Capture Only'), findsOneWidget);

      // STRICT CHECK: Ensure NO gallery, image picker, or upload buttons exist
      expect(find.textContaining('Gallery'), findsNothing);
      expect(find.textContaining('Upload'), findsNothing);
      expect(find.textContaining('Choose from'), findsNothing);
      expect(find.textContaining('File'), findsNothing);
      expect(find.byIcon(Icons.photo_library), findsNothing);
      expect(find.byIcon(Icons.image), findsNothing);
      expect(find.byIcon(Icons.folder), findsNothing);
    });
  });
}
