import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_proposals_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AiCoachRepository.clearInMemoryProposals();
  });

  tearDown(() {
    AiCoachRepository.clearInMemoryProposals();
  });

  group('Admin Workout Proposal Immediate Reflection Tests', () {
    test('1. AiCoachRepository.registerProposal stores proposal and reflects immediately in getProposals', () async {
      final repo = AiCoachRepository();
      expect(repo.inMemoryProposals, isEmpty);

      final proposal = AiProposal(
        id: 'prop_test_001',
        clientId: 'AXG-1001',
        type: AiProposalType.workout,
        title: 'Hypertrophy Upper Body Protocol',
        summary: '4 exercises · 50 min',
        reason: 'Targeting chest and shoulder volume',
        payload: {
          'title': 'Hypertrophy Upper Body Protocol',
          'workoutType': 'Hypertrophy',
          'exercises': [
            {'exerciseName': 'Barbell Bench Press', 'sets': 3, 'targetReps': '8-10', 'targetWeight': 80.0},
          ],
        },
      );

      var listenerNotified = false;
      repo.addListener(() {
        listenerNotified = true;
      });

      repo.registerProposal(proposal);

      expect(listenerNotified, isTrue);
      expect(repo.inMemoryProposals.length, 1);
      expect(repo.inMemoryProposals.first.id, 'prop_test_001');

      final proposals = await repo.getProposals();
      expect(proposals.length, 1);
      expect(proposals.first.title, 'Hypertrophy Upper Body Protocol');
      expect(proposals.first.status, AiProposalStatus.pending);
    });

    test('2. generatePlanProposal automatically registers proposal in memory and updates getProposals', () async {
      final repo = AiCoachRepository();

      final generated = await repo.generatePlanProposal(
        clientIdentifier: 'AXG-2002',
        clientName: 'Rahul Verma',
        planType: 'WORKOUT',
        workoutConfig: {
          'splitType': 'Push Pull Legs',
          'daysPerWeek': 4,
          'targetGoal': 'Hypertrophy',
        },
      );

      expect(generated, isNotNull);
      expect(repo.inMemoryProposals.any((p) => p.id == generated!.id), isTrue);

      final proposals = await repo.getProposals();
      expect(proposals.any((p) => p.id == generated!.id), isTrue);
    });

    test('3. editProposal updates in-memory proposal and notifies listeners immediately', () async {
      final repo = AiCoachRepository();

      final proposal = AiProposal(
        id: 'prop_editable_123',
        clientId: 'AXG-3003',
        type: AiProposalType.workout,
        title: 'Original AI Plan',
        summary: 'Original Summary',
        reason: 'Coach requested edits',
        payload: {'title': 'Original AI Plan', 'exercises': []},
      );
      repo.registerProposal(proposal);

      var notificationCount = 0;
      repo.addListener(() {
        notificationCount++;
      });

      final success = await repo.editProposal('prop_editable_123', {
        'title': 'Coach Customized Plan',
        'summary': 'Customized by Admin',
        'exercises': [
          {'exerciseName': 'Incline Dumbbell Press', 'sets': 4, 'targetReps': '10', 'targetWeight': 30.0},
        ],
      });

      expect(success, isTrue);
      expect(notificationCount, greaterThan(0));

      final proposals = await repo.getProposals();
      final updated = proposals.firstWhere((p) => p.id == 'prop_editable_123');
      expect(updated.title, 'Coach Customized Plan');
      expect(updated.summary, 'Customized by Admin');
      expect(updated.status, AiProposalStatus.edited);
    });

    testWidgets('4. AdminWorkoutProposalsScreen dynamically reflects newly generated proposals via repo listener', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = AiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminWorkoutProposalsScreen(
              aiCoachRepository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially empty state
      expect(find.text('No workout proposals found'), findsOneWidget);

      // Now register a new proposal dynamically (as happens when AI creates one in chat or plan generator)
      final liveProposal = AiProposal(
        id: 'prop_dynamic_live_01',
        clientId: 'AXG-9999',
        type: AiProposalType.workout,
        title: 'Real-Time Dynamic Split',
        summary: '5 exercises · Hypertrophy',
        reason: 'Immediate synchronization test',
        payload: {
          'title': 'Real-Time Dynamic Split',
          'workoutType': 'Hypertrophy',
          'exercises': [
            {'exerciseName': 'Leg Extension', 'sets': 3, 'targetReps': '12', 'targetWeight': 45.0},
          ],
        },
      );

      repo.registerProposal(liveProposal);
      await tester.pumpAndSettle();

      // Proposal immediately appears on screen without navigating away or manual reload
      expect(find.text('Real-Time Dynamic Split'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsWidgets);
    });

    testWidgets('5. AdminAiCoachScreen registers proposal on AI reply and allows immediate review/edit', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = AiCoachRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send workout request
      await tester.enterText(find.byType(TextField), 'Create a workout');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // AI reply rendered with Proposal Card
      expect(find.text('PENDING ADMIN APPROVAL'), findsOneWidget);
      expect(find.text('AI Hypertrophy Prescription'), findsOneWidget);

      // Verify that this proposal is also immediately staged in repository
      final staged = await repo.getProposals();
      expect(staged.any((p) => p.title.contains('AI Hypertrophy Prescription')), isTrue);
    });

    test('6. Failed server approve/reject leaves local proposal pending', () async {
      final repo = AiCoachRepository(
        httpClient: MockClient((request) async => http.Response('{"success":false}', 500)),
      );
      addTearDown(repo.dispose);

      final proposal = AiProposal(
        id: 'prop_server_fail_01',
        clientId: 'AXG-5001',
        type: AiProposalType.workout,
        title: 'Must Stay Pending',
        summary: 'Server will reject this mutation',
        reason: 'Rollback coverage',
        payload: {'title': 'Must Stay Pending'},
      );
      repo.registerProposal(proposal);

      final approved = await repo.approveProposal('prop_server_fail_01');
      expect(approved, isFalse);
      expect(repo.inMemoryProposals.first.status, AiProposalStatus.pending);

      final rejected = await repo.rejectProposal('prop_server_fail_01');
      expect(rejected, isFalse);
      expect(repo.inMemoryProposals.first.status, AiProposalStatus.pending);
    });

    test('7. registerProposal notifies a different repository instance immediately', () async {
      final sourceRepo = AiCoachRepository();
      final listeningRepo = AiCoachRepository();
      addTearDown(sourceRepo.dispose);
      addTearDown(listeningRepo.dispose);

      var notified = false;
      listeningRepo.addListener(() {
        notified = true;
      });

      sourceRepo.registerProposal(
        AiProposal(
          id: 'prop_shared_bus_01',
          clientId: 'AXG-7007',
          type: AiProposalType.workout,
          title: 'Shared Bus Plan',
          summary: 'Visible across repository instances',
          reason: 'Cross-instance notification',
          payload: {'title': 'Shared Bus Plan'},
        ),
      );

      expect(notified, isTrue);
      expect(listeningRepo.inMemoryProposals.any((p) => p.id == 'prop_shared_bus_01'), isTrue);
    });

    testWidgets('8. Informational chat does not fabricate a workout proposal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = AiCoachRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Explain hypertrophy training with sets and reps',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('PENDING ADMIN APPROVAL'), findsNothing);
      expect(repo.inMemoryProposals, isEmpty);
    });
  });
}
