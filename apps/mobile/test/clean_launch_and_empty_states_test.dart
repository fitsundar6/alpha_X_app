import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_enums.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_input.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/screens/macro_planner_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Clean Launch & Empty States Tests', () {
    test('1. Fresh installation MacroRepository starts with zero mock/demo data', () {
      final cleanRepo = MacroRepository.clean();

      // No fake personal inputs or active calculation
      expect(cleanRepo.currentInput, isNull,
          reason: 'Fresh install must not pre-populate age 28 male input');
      expect(cleanRepo.activeResult, isNull,
          reason: 'Fresh install must not pre-calculate benchmark targets');
      expect(cleanRepo.hasActiveTarget, isFalse);
      expect(cleanRepo.customCalories, isNull);
      expect(cleanRepo.customProtein, isNull);

      // No fake historical entries
      expect(cleanRepo.history, isEmpty,
          reason: 'Fresh install must not have macro_hist_01 or macro_hist_02');
      expect(cleanRepo.reviews, isEmpty,
          reason: 'Fresh install must not have fake check-in reviews');

      // No fake meal logs
      final summary = cleanRepo.getDailyMacroSummary(cleanRepo.getTodayDateString());
      expect(summary.totalMealsLogged, 0);
      expect(summary.consumedCalories, 0.0);
      for (final meal in MealType.values) {
        expect(summary.mealSummaries[meal]!.entries, isEmpty,
            reason: '$meal must start empty on a fresh install');
      }
    });

    test('2. MacroRepository.withFixtures supplies development/test fixtures when explicitly requested', () {
      final fixtureRepo = MacroRepository.withFixtures();

      expect(fixtureRepo.currentInput, isNotNull);
      expect(fixtureRepo.currentInput!.age, 28);
      expect(fixtureRepo.activeResult, isNotNull);
      expect(fixtureRepo.history.length, greaterThanOrEqualTo(2));
    });

    test('3. Real user macro calculation saves genuine targets and history cleanly', () {
      final repo = MacroRepository.clean();

      const realInput = MacroInput(
        age: 32,
        sex: BiologicalSex.female,
        heightCm: 165.0,
        weightKg: 62.0,
        activityLevel: ActivityLevel.moderatelyActive,
        goal: NutritionGoal.leanBulk,
      );

      final result = repo.calculateAndSave(realInput, note: 'My real goal');

      expect(repo.hasActiveTarget, isTrue);
      expect(repo.currentInput?.age, 32);
      expect(repo.currentInput?.weightKg, 62.0);
      expect(repo.activeResult?.targetCalories, result.targetCalories);
      expect(repo.history.length, 1);
      expect(repo.history.first.note, 'My real goal');
    });

    test('4. AiDailySummary.fallback returns zeroed/unavailable values instead of fake stats', () {
      final fallback = AiDailySummary.fallback();

      expect(fallback.workoutsCompleted, 0,
          reason: 'Zero fake workout counts on fallback');
      expect(fallback.foodLogsRecorded, 0,
          reason: 'Zero fake food logs on fallback');
      expect(fallback.weeklyCheckInsPending, 0,
          reason: 'Zero fake check-ins on fallback');
      expect(fallback.clientsNeedReview, 0,
          reason: 'Zero fake review count on fallback');
      expect(fallback.totalActiveClients, 0,
          reason: 'Zero fake active client count on fallback');
    });

    test('5. AiCoachRepository offline fallback preserves zero default or genuine cached data', () async {
      final repo = AiCoachRepository();

      final summary = await repo.getDailySummary();
      expect(summary.workoutsCompleted, 0);
      expect(summary.foodLogsRecorded, 0);
      expect(summary.clientsNeedReview, 0);
    });

    testWidgets('6. MacroPlannerScreen displays beginner-friendly empty states on fresh install', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      final cleanRepo = MacroRepository.clean();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacroPlannerScreen(
              repository: cleanRepo,
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Empty targets card
      expect(find.text('No Active Targets Found'), findsOneWidget);
      expect(find.text('START MACRO PLANNER'), findsOneWidget);

      // 2. Beginner-friendly meal empty prompts
      expect(find.textContaining('No food logged yet'), findsWidgets);

      // Drag down to reveal Weekly Body Check-in
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      // 3. Weekly check-in empty weight display
      expect(find.text('WEEKLY BODY CHECK-IN'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });
  });
}
