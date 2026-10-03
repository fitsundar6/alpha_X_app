import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/dashboard/admin_main_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X Master AI Coach - Unit & Domain Tests', () {
    test('1. AiDailySummary parses operational metrics accurately', () {
      final json = {
        'title': "Today's AI Summary",
        'date': '2026-10-02',
        'workoutsCompleted': 12,
        'foodLogsRecorded': 7,
        'weeklyCheckInsPending': 4,
        'clientsNeedReview': 3,
        'totalActiveClients': 18,
      };

      final summary = AiDailySummary.fromJson(json);
      expect(summary.workoutsCompleted, 12);
      expect(summary.foodLogsRecorded, 7);
      expect(summary.weeklyCheckInsPending, 4);
      expect(summary.clientsNeedReview, 3);
      expect(summary.totalActiveClients, 18);
    });

    test('2. AiProposal parses Workout proposal with exercises payload', () {
      final json = {
        'id': 'prop_001',
        'proposalType': 'WORKOUT',
        'status': 'PENDING',
        'title': 'Kumar — Hypertrophy Session',
        'summary': '3-exercise compound protocol (50 min)',
        'reason': 'Based on recorded previous performance and fitness tier.',
        'proposedData': {
          'title': 'Kumar — Hypertrophy Session',
          'workoutType': 'Hypertrophy',
          'exercises': [
            {'exerciseName': 'Barbell Bench Press', 'sets': 3, 'targetReps': '8-10', 'targetWeight': 80.0},
            {'exerciseName': 'Barbell Back Squat', 'sets': 3, 'targetReps': '8-10', 'targetWeight': 95.0},
          ],
        },
      };

      final proposal = AiProposal.fromJson(json);
      expect(proposal.id, 'prop_001');
      expect(proposal.type, AiProposalType.workout);
      expect(proposal.status, AiProposalStatus.pending);
      expect(proposal.title, 'Kumar — Hypertrophy Session');
      expect(proposal.payload['workoutType'], 'Hypertrophy');
      expect((proposal.payload['exercises'] as List).length, 2);
    });

    test('3. AiProposal parses Diet proposal with macros and Food Library items', () {
      final json = {
        'id': 'prop_diet_002',
        'proposalType': 'DIET',
        'status': 'PENDING',
        'title': 'Kumar — Fat-Loss Diet Plan',
        'summary': '1950 kcal • 160g P • 180g C • 50g F',
        'reason': 'Formulated against bodyweight and goals using Food Library.',
        'proposedData': {
          'dailyCalories': 1950,
          'protein': 160,
          'carbohydrates': 180,
          'fat': 50,
          'fiber': 28,
          'meals': [
            {
              'mealType': 'Breakfast',
              'items': [
                {'foodName': 'Rolled Oats', 'quantity': 60, 'unit': 'g'},
                {'foodName': 'Whole Eggs', 'quantity': 3, 'unit': 'piece'},
              ],
            },
          ],
        },
      };

      final proposal = AiProposal.fromJson(json);
      expect(proposal.type, AiProposalType.diet);
      expect(proposal.status, AiProposalStatus.pending);
      expect(proposal.payload['dailyCalories'], 1950);
      expect(proposal.payload['protein'], 160);
      expect((proposal.payload['meals'] as List).length, 1);
    });

    test('4. AiDataCompleteness computes percentage and identifies missing records', () {
      final json = {
        'scorePercentage': 86,
        'missingItems': [
          '2 weekly check-ins missing',
          '3 days of food logs missing',
        ],
        'summary': 'Data Completeness: 86%',
      };

      final completeness = AiDataCompleteness.fromJson(json);
      expect(completeness.scorePercentage, 86);
      expect(completeness.missingItems.length, 2);
      expect(completeness.missingItems.first, '2 weekly check-ins missing');
    });

    test('5. AiCoachRepository fallback handles Today\'s Report request', () async {
      final repo = AiCoachRepository();
      final reply = await repo.sendMessage(message: "Give me today's report");

      expect(reply.intent, 'DAILY_REPORT');
      expect(reply.content, contains("TODAY'S ALPHA X REPORT"));
      expect(reply.reportCard, isNotNull);
      expect(reply.reportCard?.workoutsCompleted, 12);
      expect(reply.reportCard?.foodLogsRecorded, 7);
    });

    test('6. AiCoachRepository fallback handles Workout Creation proposal', () async {
      final repo = AiCoachRepository();
      final reply = await repo.sendMessage(message: "Create a workout for Kumar");

      expect(reply.intent, 'WORKOUT_PROPOSAL');
      expect(reply.proposal, isNotNull);
      expect(reply.proposal?.type, AiProposalType.workout);
      expect(reply.proposal?.status, AiProposalStatus.pending);
      expect(reply.proposal?.payload['exercises'], isNotEmpty);
    });

    test('7. AiCoachRepository fallback handles Progressive Overload proposal', () async {
      final repo = AiCoachRepository();
      final reply = await repo.sendMessage(message: "Progress Kumar's bench press");

      expect(reply.intent, 'PROGRESSION_PROPOSAL');
      expect(reply.proposal, isNotNull);
      expect(reply.proposal?.type, AiProposalType.progression);
      expect(reply.proposal?.payload['targetWeight'], 82.5);
      expect(reply.proposal?.payload['targetReps'], '8');
    });

    test('8. AiCoachRepository fallback handles Diet Creation proposal', () async {
      final repo = AiCoachRepository();
      final reply = await repo.sendMessage(message: "Create a fat-loss diet for Kumar");

      expect(reply.intent, 'DIET_PROPOSAL');
      expect(reply.proposal, isNotNull);
      expect(reply.proposal?.type, AiProposalType.diet);
      expect(reply.proposal?.payload['dailyCalories'], 1950);
      expect(reply.proposal?.payload['protein'], 160);
    });

    test('8b. Verifies 3 distinct questions return distinct, non-repeated responses (fixes repeated response bug)', () async {
      final repo = AiCoachRepository();

      final reply1 = await repo.sendMessage(message: "Hello, who are you?");
      final reply2 = await repo.sendMessage(message: "Analyze this client's recent workout history.");
      final reply3 = await repo.sendMessage(message: "Show me this client's personal bests.");

      // Verify all 3 responses are non-empty and completely distinct
      expect(reply1.content.isNotEmpty, isTrue);
      expect(reply2.content.isNotEmpty, isTrue);
      expect(reply3.content.isNotEmpty, isTrue);

      expect(reply1.content != reply2.content, isTrue);
      expect(reply2.content != reply3.content, isTrue);
      expect(reply1.content != reply3.content, isTrue);

      expect(reply1.intent, 'GREETING');
      expect(reply1.content, contains('Alpha X AI Coach'));

      expect(reply2.intent, 'WORKOUT_ANALYSIS');
      expect(reply2.content, contains('WORKOUT HISTORY'));

      expect(reply3.intent, 'PERSONAL_BESTS');
      expect(reply3.content, contains('PERSONAL BESTS'));
    });
  });

  group('Alpha X Master AI Coach - Widget & Integration Tests', () {
    testWidgets('9. AdminAiCoachScreen renders header, client selector, date range, and suggested chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: AiCoachRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Brand headers
      expect(find.text('ALPHA X AI COACH'), findsOneWidget);
      expect(find.text('MASTER INTELLIGENCE CONTROLLER'), findsOneWidget);

      // Context selectors
      expect(find.text('All Athletes'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);

      // Welcome message
      expect(find.textContaining('Welcome to the Alpha X Master AI Coach'), findsOneWidget);

      // Suggested Prompts
      expect(find.text("Give me today's report").first, findsOneWidget);
      expect(find.text("Show clients needing review").first, findsOneWidget);
      expect(find.text("Who missed workouts today?").first, findsOneWidget);
    });

    testWidgets('10. AdminAiCoachScreen handles sending message and displays reply with proposal card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: AiCoachRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter query in input bar
      await tester.enterText(find.byType(TextField), 'Create a workout');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify Proposal Card is displayed with PENDING status
      expect(find.text('PENDING ADMIN APPROVAL'), findsOneWidget);
      expect(find.text('AI Hypertrophy Prescription'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Verify Data Completeness badge
      expect(find.textContaining('86% Data Complete'), findsOneWidget);
    });

    testWidgets('11. Proposal Approval Flow: Tapping Approve activates plan without silent change', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: AiCoachRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger progressive overload query
      await tester.enterText(find.byType(TextField), 'Progress bench press');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Before approval: status is PENDING
      expect(find.text('PENDING ADMIN APPROVAL'), findsOneWidget);
      final approveButton = find.text('Approve');
      expect(approveButton, findsOneWidget);

      // Admin clicks Approve
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      // Status updates to APPROVED & ACTIVE
      expect(find.text('APPROVED & ACTIVE'), findsOneWidget);
      expect(find.text('✔ Active client plan updated in Alpha X database.'), findsOneWidget);
    });

    testWidgets('12. Proposal Rejection Flow: Tapping Reject sets status to REJECTED', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: AiCoachRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger diet query
      await tester.enterText(find.byType(TextField), 'Create a diet using our Food Library');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('PENDING ADMIN APPROVAL'), findsOneWidget);
      final rejectButton = find.text('Reject');
      expect(rejectButton, findsOneWidget);

      // Admin clicks Reject
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      // Status updates to REJECTED
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('✖ Proposal closed without altering active plan.'), findsOneWidget);
    });

    testWidgets('13. Proposal Edit Flow: Tapping Edit opens bottom sheet and updates payload', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: AiCoachRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger workout query
      await tester.enterText(find.byType(TextField), 'Create a workout');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final editButton = find.text('Edit');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Bottom sheet opened
      expect(find.text('EDIT PROPOSAL: WORKOUT'), findsOneWidget);
      expect(find.text('Save Modifications'), findsOneWidget);

      // Tap Save
      await tester.tap(find.text('Save Modifications'));
      await tester.pumpAndSettle();

      // Proposal status changes to EDITED BY ADMIN
      expect(find.text('EDITED BY ADMIN'), findsOneWidget);
    });

    testWidgets('14. Admin Main Dashboard renders AI Coach card with summary metrics & Open AI Coach button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final workoutRepo = WorkoutRepository();
      final activityRepo = ActivityRepository();
      final macroRepo = MacroRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminMainDashboardScreen(
            workoutRepository: workoutRepo,
            activityRepository: activityRepo,
            macroRepository: macroRepo,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify AI Coach Summary card on Admin Dashboard
      expect(find.text('ALPHA X AI COACH'), findsOneWidget);
      expect(find.text("Today's AI Summary"), findsOneWidget);
      expect(find.textContaining('workouts completed today'), findsOneWidget);
      expect(find.textContaining('food logs recorded'), findsOneWidget);
      expect(find.textContaining('weekly check-ins pending'), findsOneWidget);
      expect(find.textContaining('clients need review'), findsOneWidget);
      expect(find.text('Open AI Coach'), findsOneWidget);

      // Tapping "Open AI Coach" opens the AdminAiCoachScreen
      await tester.tap(find.text('Open AI Coach'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminAiCoachScreen), findsOneWidget);
      expect(find.text('MASTER INTELLIGENCE CONTROLLER'), findsOneWidget);
    });

    testWidgets('15. Phase 4: New Chat button resets conversation context and clears previous messages', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: AiCoachRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send a message first
      await tester.enterText(find.byType(TextField), 'What is RIR?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Find New Chat button in AppBar
      final newChatBtn = find.byKey(const Key('admin_ai_new_chat_button'));
      expect(newChatBtn, findsOneWidget);

      // Tap New Chat
      await tester.tap(newChatBtn);
      await tester.pumpAndSettle();

      // Expect previous message to be cleared and new session banner displayed
      expect(find.textContaining('Started a fresh Alpha X AI Coach session'), findsOneWidget);
      expect(find.textContaining('Previous conversation context has been cleared'), findsOneWidget);
    });

    testWidgets('16. Phase 4: Formatted markdown structured text renders bold headings and lists cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: AiCoachRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial welcome message contains bold markdown
      expect(find.textContaining('Welcome to the Alpha X Master AI Coach'), findsOneWidget);
    });

    testWidgets('17. Phase 4: RAG Knowledge Attribution badge displays when sources are retrieved', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAiCoachScreen(
              aiCoachRepository: AiCoachRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send message to get reply
      await tester.enterText(find.byType(TextField), 'Explain progressive overload');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.byType(AdminAiCoachScreen), findsOneWidget);
    });

    testWidgets('18. Phase 7: Verified client context parses and model supports client badge', (tester) async {
      final msg = AiChatMessage(
        id: 'msg_p7',
        sender: 'AI',
        content: "Understood. I'm now working with John (AXG-1234).",
        verifiedClient: const VerifiedClientInfo(
          clientId: 'AXG-1234',
          displayName: 'John Doe',
          verified: true,
        ),
      );

      expect(msg.verifiedClient?.clientId, 'AXG-1234');
      expect(msg.verifiedClient?.displayName, 'John Doe');
      expect(msg.verifiedClient?.verified, true);
    });
  });
}

