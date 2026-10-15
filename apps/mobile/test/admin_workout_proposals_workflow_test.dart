import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_proposals_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_proposal_assignment_dialog.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Admin AI Workout Proposals Workflow Tests', () {
    testWidgets('1. AdminWorkoutProposalsScreen renders filter chips, stats, and proposal list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final workoutRepo = WorkoutRepository();
      final aiRepo = AiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminWorkoutProposalsScreen(
            workoutRepository: workoutRepo,
            aiCoachRepository: aiRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Header and Metrics
      expect(find.text('AI WORKOUT PROPOSALS'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Admin Edited'), findsOneWidget);
      expect(find.text('Approved Plans'), findsOneWidget);
      expect(find.text('Total Generated'), findsOneWidget);

      // Verify Filter Chips
      expect(find.text('All Plans'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);

      // Verify search input
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('2. AdminProposalAssignmentDialog renders target modes: Individual, Selected, All', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = AiProposal(
        id: 'prop_test_assign_01',
        clientId: 'AXG-1029',
        clientName: 'Alex Mercer',
        type: AiProposalType.workout,
        title: 'Hypertrophy Upper Volume A',
        summary: 'Targeted chest, delts, and arms session',
        reason: 'Optimal progressive overload',
        status: AiProposalStatus.pending,
        payload: {
          'title': 'Hypertrophy Upper Volume A',
          'workoutType': 'Hypertrophy',
          'targetMuscleGroup': 'Chest & Shoulders',
          'exercises': [
            {'exerciseName': 'Dumbbell Incline Bench', 'sets': 3, 'targetReps': '8-10', 'targetWeight': 24.0},
          ],
        },
      );

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

      // Verify dialog title and modes
      expect(find.text('ASSIGN WORKOUT PLAN'), findsOneWidget);
      expect(find.text('Individual Athlete'), findsOneWidget);
      expect(find.text('Multiple Selected Athletes'), findsOneWidget);
      expect(find.text('All Eligible Athletes'), findsOneWidget);

      // Verify date picker field
      expect(find.text('Scheduled Date:'), findsOneWidget);
    });

    testWidgets('3. AdminProposalAssignmentDialog switches to Multiple Clients checklist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = AiProposal(
        id: 'prop_test_assign_02',
        clientId: 'AXG-1029',
        clientName: 'Alex Mercer',
        type: AiProposalType.workout,
        title: 'Full Body Foundations',
        summary: 'Compound primer workout',
        reason: 'Assessment results',
        status: AiProposalStatus.pending,
        payload: {
          'title': 'Full Body Foundations',
          'exercises': [
            {'exerciseName': 'Goblet Squat', 'sets': 3, 'targetReps': '10-12', 'targetWeight': 16.0},
          ],
        },
      );

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

      // Tap 'Multiple Selected Athletes' mode
      await tester.tap(find.text('Multiple Selected Athletes'));
      await tester.pumpAndSettle();

      // Mode switched - should show search bar and selected count subtitle
      expect(find.textContaining('selected from roster'), findsOneWidget);
    });

    testWidgets('4. AdminProposalAssignmentDialog switches to All Clients with confirmation badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final proposal = AiProposal(
        id: 'prop_test_assign_03',
        clientId: 'AXG-1029',
        clientName: 'Alex Mercer',
        type: AiProposalType.workout,
        title: 'Facility Mobility Routine',
        summary: 'Full body restorative work',
        reason: 'Deload week preparation',
        status: AiProposalStatus.pending,
        payload: {
          'title': 'Facility Mobility Routine',
          'exercises': [
            {'exerciseName': 'Cat Cow', 'sets': 2, 'targetReps': '10', 'targetWeight': 0.0},
          ],
        },
      );

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

      // Tap 'All Eligible Athletes' mode
      await tester.tap(find.text('All Eligible Athletes'));
      await tester.pumpAndSettle();

      // Tap 'REVIEW RECIPIENTS →'
      await tester.tap(find.text('REVIEW RECIPIENTS →'));
      await tester.pumpAndSettle();

      // Verify confirmation step validation badge
      expect(find.text('All recipients validated: Active & Approved gym athletes.'), findsOneWidget);
    });

    testWidgets('5. AdminAiCoachScreen displays active athlete identity card when client is selected', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final workoutRepo = WorkoutRepository();
      final aiRepo = AiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            workoutRepository: workoutRepo,
            aiCoachRepository: aiRepo,
            initialClientId: 'client_john_doe',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Active Athlete Context Banner is shown
      expect(find.text('ACTIVE ATHLETE CONTEXT'), findsOneWidget);
      expect(find.textContaining('Generate Personalized Workout Plan for'), findsOneWidget);
    });
  });
}
