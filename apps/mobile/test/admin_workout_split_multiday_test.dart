import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_proposals_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_proposal_assignment_dialog.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/widgets/admin_ai_proposal_review_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AiProposal createMockPPLx2Proposal() {
    return AiProposal(
      id: 'prop_ppl_x2_test',
      clientId: 'AXG-1029',
      clientName: 'Alex Mercer',
      type: AiProposalType.workout,
      title: '6-Day Push Pull Legs (PPL × 2) Hypertrophy Program',
      summary: '6-day high frequency split targeting all major muscle groups twice weekly.',
      reason: 'Optimal hypertrophy frequency for intermediate athlete.',
      status: AiProposalStatus.pending,
      payload: {
        'title': '6-Day Push Pull Legs (PPL × 2) Hypertrophy Program',
        'workoutType': 'Hypertrophy',
        'targetMuscleGroup': 'Full Body Split',
        'isMultiDaySplit': true,
        'totalDays': 6,
        'weeklySchedule': [
          {
            'dayId': 'day_1',
            'day': 'Monday',
            'dayName': 'Monday',
            'weekday': 'Monday',
            'sessionTitle': 'Push A (Chest / Shoulders / Triceps)',
            'splitCategory': 'Push',
            'targetMuscleGroup': 'Chest, Shoulders, Triceps',
            'estimatedDurationMinutes': 50,
            'exercises': [
              {'name': 'Barbell Bench Press', 'sets': 3, 'reps': '8-10', 'weight': 60, 'restSeconds': 90, 'notes': 'Controlled descent'},
              {'name': 'Incline Dumbbell Press', 'sets': 3, 'reps': '8-12', 'weight': 22, 'restSeconds': 90, 'notes': 'Full stretch at bottom'},
              {'name': 'Standing Overhead Press', 'sets': 3, 'reps': '8-10', 'weight': 35, 'restSeconds': 90, 'notes': 'Strict form'},
              {'name': 'Dumbbell Lateral Raise', 'sets': 3, 'reps': '12-15', 'weight': 10, 'restSeconds': 60, 'notes': 'Lead with elbows'},
              {'name': 'Tricep Rope Pushdown', 'sets': 3, 'reps': '10-12', 'weight': 25, 'restSeconds': 60, 'notes': 'Squeeze at extension'},
            ],
          },
          {
            'dayId': 'day_2',
            'day': 'Tuesday',
            'dayName': 'Tuesday',
            'weekday': 'Tuesday',
            'sessionTitle': 'Pull A (Back / Biceps / Rear Delts)',
            'splitCategory': 'Pull',
            'targetMuscleGroup': 'Back, Biceps, Rear Delts',
            'estimatedDurationMinutes': 50,
            'exercises': [
              {'name': 'Barbell Deadlift', 'sets': 3, 'reps': '6-8', 'weight': 90, 'restSeconds': 120, 'notes': 'Brace core firmly'},
              {'name': 'Lat Pulldown', 'sets': 3, 'reps': '8-12', 'weight': 55, 'restSeconds': 90, 'notes': 'Retract scapulae'},
              {'name': 'Seated Cable Row', 'sets': 3, 'reps': '8-12', 'weight': 50, 'restSeconds': 90, 'notes': 'Pull to lower chest'},
              {'name': 'Face Pulls', 'sets': 3, 'reps': '12-15', 'weight': 18, 'restSeconds': 60, 'notes': 'External rotation'},
              {'name': 'Barbell Bicep Curl', 'sets': 3, 'reps': '8-10', 'weight': 25, 'restSeconds': 60, 'notes': 'Full range of motion'},
            ],
          },
          {
            'dayId': 'day_3',
            'day': 'Wednesday',
            'dayName': 'Wednesday',
            'weekday': 'Wednesday',
            'sessionTitle': 'Legs A (Quads / Hamstrings / Calves)',
            'splitCategory': 'Legs',
            'targetMuscleGroup': 'Quads, Hamstrings, Calves',
            'estimatedDurationMinutes': 55,
            'exercises': [
              {'name': 'Barbell Back Squat', 'sets': 3, 'reps': '6-8', 'weight': 80, 'restSeconds': 120, 'notes': 'Hit parallel depth'},
              {'name': 'Romanian Deadlift', 'sets': 3, 'reps': '8-10', 'weight': 70, 'restSeconds': 90, 'notes': 'Hinge at hips'},
              {'name': 'Leg Press', 'sets': 3, 'reps': '10-12', 'weight': 140, 'restSeconds': 90, 'notes': 'Full quad engagement'},
              {'name': 'Leg Curl Machine', 'sets': 3, 'reps': '10-12', 'weight': 40, 'restSeconds': 60, 'notes': 'Control eccentric'},
              {'name': 'Standing Calf Raise', 'sets': 3, 'reps': '12-15', 'weight': 50, 'restSeconds': 45, 'notes': 'Full contraction at peak'},
            ],
          },
          {
            'dayId': 'day_4',
            'day': 'Thursday',
            'dayName': 'Thursday',
            'weekday': 'Thursday',
            'sessionTitle': 'Push B (Upper Chest / Delts / Triceps)',
            'splitCategory': 'Push',
            'targetMuscleGroup': 'Chest, Shoulders, Triceps',
            'estimatedDurationMinutes': 50,
            'exercises': [
              {'name': 'Incline Barbell Bench Press', 'sets': 3, 'reps': '8-10', 'weight': 55, 'restSeconds': 90, 'notes': 'Upper pec focus'},
              {'name': 'Flat Dumbbell Press', 'sets': 3, 'reps': '8-12', 'weight': 24, 'restSeconds': 90, 'notes': 'Deep stretch'},
              {'name': 'Cable Lateral Raise', 'sets': 3, 'reps': '12-15', 'weight': 8, 'restSeconds': 60, 'notes': 'Constant tension'},
              {'name': 'Dumbbell Overhead Extension', 'sets': 3, 'reps': '10-12', 'weight': 18, 'restSeconds': 60, 'notes': 'Long head stretch'},
            ],
          },
          {
            'dayId': 'day_5',
            'day': 'Friday',
            'dayName': 'Friday',
            'weekday': 'Friday',
            'sessionTitle': 'Pull B (Upper Back / Lats / Arms)',
            'splitCategory': 'Pull',
            'targetMuscleGroup': 'Back, Biceps, Rear Delts',
            'estimatedDurationMinutes': 50,
            'exercises': [
              {'name': 'Chest-Supported Row', 'sets': 3, 'reps': '8-10', 'weight': 45, 'restSeconds': 90, 'notes': 'Isolate mid-back'},
              {'name': 'Neutral Grip Pull-Up', 'sets': 3, 'reps': '6-8', 'weight': 0, 'restSeconds': 90, 'notes': 'Full stretch at bottom'},
              {'name': 'Dumbbell Hammer Curl', 'sets': 3, 'reps': '10-12', 'weight': 14, 'restSeconds': 60, 'notes': 'Brachialis target'},
              {'name': 'Incline Dumbbell Curl', 'sets': 3, 'reps': '10-12', 'weight': 12, 'restSeconds': 60, 'notes': 'Stretch bicep peak'},
            ],
          },
          {
            'dayId': 'day_6',
            'day': 'Saturday',
            'dayName': 'Saturday',
            'weekday': 'Saturday',
            'sessionTitle': 'Legs B (Posterior Chain / Quads / Abs)',
            'splitCategory': 'Legs',
            'targetMuscleGroup': 'Glutes, Hamstrings, Quads, Core',
            'estimatedDurationMinutes': 50,
            'exercises': [
              {'name': 'Barbell Hip Thrust', 'sets': 3, 'reps': '8-10', 'weight': 90, 'restSeconds': 90, 'notes': 'Glute lockout'},
              {'name': 'Bulgarian Split Squat', 'sets': 3, 'reps': '8-10', 'weight': 16, 'restSeconds': 90, 'notes': 'Quad & glute overload'},
              {'name': 'Lying Leg Curl', 'sets': 3, 'reps': '10-12', 'weight': 35, 'restSeconds': 60, 'notes': 'Slow tempo'},
              {'name': 'Hanging Knee Raise', 'sets': 3, 'reps': '12-15', 'weight': 0, 'restSeconds': 45, 'notes': 'Posterior pelvic tilt'},
            ],
          },
        ],
      },
    );
  }

  group('Alpha X Multi-Day Workout Split (PPL × 2) UI & Review Tests', () {
    testWidgets('1. WorkoutProposalDetailSheet displays 6 separate workout-day cards for PPL × 2', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = createMockPPLx2Proposal();
      final workoutRepo = WorkoutRepository();
      final aiRepo = AiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutProposalDetailSheet(
              proposal: proposal,
              workoutRepository: workoutRepo,
              aiCoachRepository: aiRepo,
              onProposalUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Multi-Day Split Header
      expect(find.text('WEEKLY SPLIT SCHEDULE (6 WORKOUT DAYS)'), findsOneWidget);
      expect(find.text('Each day is a distinct workout session with dedicated exercises scheduled for that weekday.'), findsOneWidget);

      // Verify separate workout days are present
      expect(find.text('Push A (Chest / Shoulders / Triceps)'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);

      // Verify Push A has individual session exercises (not 27 in one day!)
      expect(find.text('Barbell Bench Press'), findsOneWidget);
      expect(find.text('Incline Dumbbell Press'), findsOneWidget);
      expect(find.text('Standing Overhead Press'), findsOneWidget);

      expect(find.text('Dumbbell Lateral Raise'), findsOneWidget);
      expect(find.text('Tricep Rope Pushdown'), findsOneWidget);

      // Verify that exercises from Day 2 (Pull A) and Day 3 (Legs A) are NOT mixed into Day 1!
      expect(find.text('Barbell Deadlift'), findsNothing);
      expect(find.text('Barbell Back Squat'), findsNothing);
    });

    testWidgets('2. AdminAiProposalReviewDialog renders 6 distinct days in workout breakdown', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = createMockPPLx2Proposal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAiProposalReviewDialog(
              proposal: proposal,
              onAccept: () {},
              onEdit: () {},
              onReject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Weekly Split header & count
      expect(find.text('WEEKLY SPLIT SCHEDULE'), findsOneWidget);
      expect(find.text('6 Workout Days'), findsOneWidget);

      // Verify individual day cards are rendered
      expect(find.text('Push A (Chest / Shoulders / Triceps)'), findsOneWidget);
      expect(find.text('Pull A (Back / Biceps / Rear Delts)'), findsOneWidget);
      expect(find.text('Legs A (Quads / Hamstrings / Calves)'), findsOneWidget);
    });

    testWidgets('3. AdminProposalAssignmentDialog renders Weekly Split Protocol confirmation badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = createMockPPLx2Proposal();
      final workoutRepo = WorkoutRepository();
      final aiRepo = AiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminProposalAssignmentDialog(
              proposal: proposal,
              workoutRepository: workoutRepo,
              aiCoachRepository: aiRepo,
              onAssigned: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'REVIEW RECIPIENTS →' to reach Confirmation step
      await tester.tap(find.text('REVIEW RECIPIENTS →'));
      await tester.pumpAndSettle();

      // Verify Multi-Day Split Protocol confirmation badge is rendered
      expect(find.textContaining('Weekly Split Protocol: 6 separate workout days'), findsOneWidget);
      expect(find.textContaining('dedicated 5–7 exercises per session'), findsOneWidget);
    });

    testWidgets('4. AdminWorkoutProposalsScreen renders 6 Days Split pill and multi-day preview snippet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = createMockPPLx2Proposal();
      final workoutRepo = WorkoutRepository();
      final aiRepo = FakeAiCoachRepository();
      aiRepo.fakeProposals.add(proposal);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminWorkoutProposalsScreen(
            workoutRepository: workoutRepo,
            aiCoachRepository: aiRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify '6 Days Split' pill is rendered on the proposal card
      expect(find.text('6 Days Split'), findsOneWidget);

      // Verify Weekly Split preview container is rendered
      expect(find.text('WEEKLY SPLIT: 6 WORKOUT DAYS'), findsOneWidget);
      expect(find.text('Push A (Chest / Shoulders / Triceps)'), findsOneWidget);
      expect(find.text('5 exercises'), findsWidgets);
    });
  });
}

class FakeAiCoachRepository extends AiCoachRepository {
  final List<AiProposal> fakeProposals = [];

  @override
  Future<List<AiProposal>> getProposals({
    String? status,
    String? clientId,
    String? type,
    String? proposalType,
  }) async {
    return fakeProposals;
  }
}

