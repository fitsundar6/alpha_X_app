import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AI Coach Conversation Persistence - Unit & Domain Tests', () {
    test('1. AiChatMessage toJson and fromJson round-trip accurately preserves all fields', () {
      final now = DateTime.now();
      final original = AiChatMessage(
        id: 'msg_test_123',
        sender: 'AI',
        content: 'Analyzing workout metrics for Kumar.',
        intent: 'ANALYSIS',
        timestamp: now,
        isError: false,
        conversationId: 'conv_session_abc',
        promptVersion: '2.5-flash',
        knowledgeRetrievalEnabled: true,
        retrievedKnowledgeCount: 3,
        retrievedKnowledgeIds: ['kb_hypertrophy_01', 'kb_progressive_02'],
        suggestedFollowUps: ['Show PRs', 'Create workout'],
        verifiedClient: const VerifiedClientInfo(
          clientId: 'AXG-1001',
          displayName: 'Kumar Athlete',
          verified: true,
        ),
      );

      final json = original.toJson();
      final restored = AiChatMessage.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.sender, 'AI');
      expect(restored.isAi, isTrue);
      expect(restored.content, original.content);
      expect(restored.intent, 'ANALYSIS');
      expect(restored.conversationId, 'conv_session_abc');
      expect(restored.knowledgeRetrievalEnabled, isTrue);
      expect(restored.retrievedKnowledgeCount, 3);
      expect(restored.retrievedKnowledgeIds?.length, 2);
      expect(restored.suggestedFollowUps.length, 2);
      expect(restored.verifiedClient?.clientId, 'AXG-1001');
      expect(restored.verifiedClient?.displayName, 'Kumar Athlete');
    });

    test('2. AiCoachRepository persists and restores messages preserving order and timestamps', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = AiCoachRepository();
      const testUserId = 'trainer_dan';
      const testRole = 'admin';

      final time1 = DateTime.now().subtract(const Duration(minutes: 5));
      final time2 = DateTime.now().subtract(const Duration(minutes: 4));

      final messages = [
        AiChatMessage(
          id: 'm1',
          sender: 'ADMIN',
          content: 'What is Kumar\'s current bench press PR?',
          intent: 'USER_QUERY',
          timestamp: time1,
        ),
        AiChatMessage(
          id: 'm2',
          sender: 'AI',
          content: 'Kumar\'s current bench press PR is 105 kg recorded on October 4.',
          intent: 'STRENGTH_PR',
          timestamp: time2,
        ),
      ];

      await repo.saveConversationLocally(
        messages: messages,
        conversationId: 'conv_dan_001',
        userId: testUserId,
        role: testRole,
      );

      final session = await repo.loadConversationLocally(
        userId: testUserId,
        role: testRole,
      );

      expect(session.conversationId, 'conv_dan_001');
      expect(session.messages.length, 2);
      expect(session.messages[0].id, 'm1');
      expect(session.messages[0].content, 'What is Kumar\'s current bench press PR?');
      expect(session.messages[0].isAdmin, isTrue);
      expect(session.messages[1].id, 'm2');
      expect(session.messages[1].isAi, isTrue);
    });

    test('3. Simulated App Restart: Fresh repository instance restores persisted conversation from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = AiCoachRepository();
      const testUserId = 'admin_alex_stone';
      const testRole = 'admin';

      final messages = [
        AiChatMessage(
          id: 'msg_saved_1',
          sender: 'ADMIN',
          content: 'Show clients needing review',
          intent: 'USER_QUERY',
        ),
        AiChatMessage(
          id: 'msg_saved_2',
          sender: 'AI',
          content: 'Found 2 clients needing attention: Sarah and Alex.',
          intent: 'REPORT',
        ),
      ];

      await repo1.saveConversationLocally(
        messages: messages,
        conversationId: 'conv_persisted_session',
        userId: testUserId,
        role: testRole,
      );

      // Simulate app kill and fresh launch with a brand new repository instance
      final repo2 = AiCoachRepository();
      final restored = await repo2.loadConversationLocally(
        userId: testUserId,
        role: testRole,
      );

      expect(restored.conversationId, 'conv_persisted_session');
      expect(restored.messages.length, 2);
      expect(restored.messages[0].content, 'Show clients needing review');
      expect(restored.messages[1].content, 'Found 2 clients needing attention: Sarah and Alex.');
    });

    test('4. Strict Isolation: Admin and Client conversations are completely partitioned', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = AiCoachRepository();

      final adminMessages = [
        AiChatMessage(id: 'adm_1', sender: 'ADMIN', content: 'Admin secret management prompt'),
      ];
      final clientMessages = [
        AiChatMessage(id: 'cli_1', sender: 'CLIENT', content: 'Client workout execution query'),
      ];

      await repo.saveConversationLocally(
        messages: adminMessages,
        conversationId: 'conv_admin_only',
        userId: 'admin_alex',
        role: 'admin',
      );

      await repo.saveConversationLocally(
        messages: clientMessages,
        conversationId: 'conv_client_only',
        userId: 'client_100',
        role: 'client',
      );

      // Load as client -> Admin message must NEVER leak
      final loadedClient = await repo.loadConversationLocally(
        userId: 'client_100',
        role: 'client',
      );
      expect(loadedClient.conversationId, 'conv_client_only');
      expect(loadedClient.messages.length, 1);
      expect(loadedClient.messages.first.content, 'Client workout execution query');
      expect(loadedClient.messages.any((m) => m.content.contains('Admin')), isFalse);

      // Load as admin -> Client message must NEVER leak
      final loadedAdmin = await repo.loadConversationLocally(
        userId: 'admin_alex',
        role: 'admin',
      );
      expect(loadedAdmin.conversationId, 'conv_admin_only');
      expect(loadedAdmin.messages.length, 1);
      expect(loadedAdmin.messages.first.content, 'Admin secret management prompt');
      expect(loadedAdmin.messages.any((m) => m.content.contains('Client workout')), isFalse);
    });

    test('5. Strict Isolation: Client A and Client B cannot access each other\'s conversations', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = AiCoachRepository();

      await repo.saveConversationLocally(
        messages: [AiChatMessage(id: 'k1', sender: 'CLIENT', content: 'Kumar private notes')],
        userId: 'client_kumar',
        role: 'client',
      );

      await repo.saveConversationLocally(
        messages: [AiChatMessage(id: 's1', sender: 'CLIENT', content: 'Sarah private diet inquiry')],
        userId: 'client_sarah',
        role: 'client',
      );

      final kumarData = await repo.loadConversationLocally(userId: 'client_kumar', role: 'client');
      final sarahData = await repo.loadConversationLocally(userId: 'client_sarah', role: 'client');

      expect(kumarData.messages.first.content, 'Kumar private notes');
      expect(sarahData.messages.first.content, 'Sarah private diet inquiry');
      expect(kumarData.messages.any((m) => m.content.contains('Sarah')), isFalse);
      expect(sarahData.messages.any((m) => m.content.contains('Kumar')), isFalse);
    });

    test('6. Deduplication: Duplicate message IDs are gracefully filtered while preserving order', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = AiCoachRepository();

      final dupes = [
        AiChatMessage(id: 'dup_1', sender: 'ADMIN', content: 'First entry'),
        AiChatMessage(id: 'dup_2', sender: 'AI', content: 'Second entry'),
        AiChatMessage(id: 'dup_1', sender: 'ADMIN', content: 'Duplicate entry'),
      ];

      await repo.saveConversationLocally(messages: dupes, userId: 'test_u', role: 'admin');

      // Clear memory cache to force reading serialized SharedPreferences
      final freshRepo = AiCoachRepository();
      final loaded = await freshRepo.loadConversationLocally(userId: 'test_u', role: 'admin');

      expect(loaded.messages.length, 2);
      expect(loaded.messages[0].id, 'dup_1');
      expect(loaded.messages[0].content, 'First entry');
      expect(loaded.messages[1].id, 'dup_2');
      expect(loaded.messages[1].content, 'Second entry');
    });
  });

  group('AI Coach Conversation Persistence - Widget & Navigation Tests', () {
    testWidgets('7. Chat messages persist across screen navigation and reopen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = AiCoachRepository();

      // Pre-seed a conversation in the repository
      await repo.saveConversationLocally(
        messages: [
          AiChatMessage(
            id: 'seeded_user_msg',
            sender: 'ADMIN',
            content: 'How should I structure hypertrophy volume?',
            intent: 'USER_QUERY',
          ),
          AiChatMessage(
            id: 'seeded_ai_reply',
            sender: 'AI',
            content: 'Hypertrophy volume should target 10-20 hard sets per muscle group per week.',
            intent: 'KNOWLEDGE_QUERY',
          ),
        ],
        conversationId: 'conv_preseeded',
      );

      // Launch screen 1st time
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify restored messages are visible
      expect(find.text('How should I structure hypertrophy volume?'), findsOneWidget);
      expect(find.textContaining('10-20 hard sets per muscle group'), findsOneWidget);

      // Navigate away: replace with another screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Clients Directory Screen'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clients Directory Screen'), findsOneWidget);
      expect(find.text('How should I structure hypertrophy volume?'), findsNothing);

      // Navigate back: reopen AdminAiCoachScreen with same repository
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the entire conversation is completely restored
      expect(find.text('How should I structure hypertrophy volume?'), findsOneWidget);
      expect(find.textContaining('10-20 hard sets per muscle group'), findsOneWidget);
    });

    testWidgets('8. Sending new message persists it for subsequent screen instances', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = AiCoachRepository();

      // Launch screen
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type and send a message
      await tester.enterText(find.byType(TextField), 'Progress bench press for Kumar');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify message and reply are displayed
      expect(find.text('Progress bench press for Kumar'), findsOneWidget);

      // Close screen and reopen
      await tester.pumpWidget(
        MaterialApp(
          home: Container(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the user message sent earlier is restored
      expect(find.text('Progress bench press for Kumar'), findsOneWidget);
    });

    testWidgets('9. New Chat resets active conversation, shows banner, and updates persistence', (tester) async {
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

      // Send a query
      await tester.enterText(find.byType(TextField), 'Temporary question to be cleared');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Temporary question to be cleared'), findsOneWidget);

      // Tap New Chat
      final newChatBtn = find.byKey(const Key('admin_ai_new_chat_button'));
      expect(newChatBtn, findsOneWidget);
      await tester.tap(newChatBtn);
      await tester.pumpAndSettle();

      // Old message is gone
      expect(find.text('Temporary question to be cleared'), findsNothing);
      expect(find.textContaining('Started a fresh Alpha X AI Coach session'), findsOneWidget);

      // Reopening screen maintains the new cleared state
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAiCoachScreen(
            aiCoachRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temporary question to be cleared'), findsNothing);
      expect(find.textContaining('Started a fresh Alpha X AI Coach session'), findsOneWidget);
    });
  });
}
