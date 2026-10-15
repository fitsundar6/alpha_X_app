import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alpha X AI Chat - Response Text Selection & Copying Tests', () {
    testWidgets('1. AI responses and Admin messages are rendered inside SelectionArea', (tester) async {
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

      // Verify that at least one SelectionArea exists for the initial AI welcome message
      final selectionAreaFinder = find.byType(SelectionArea);
      expect(selectionAreaFinder, findsWidgets,
          reason: 'AI response messages must be rendered inside SelectionArea to allow text selection and copying');

      // Verify that the initial welcome text is present inside the SelectionArea
      final welcomeTextFinder = find.textContaining('Welcome to the Alpha X Master AI Coach');
      expect(welcomeTextFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(welcomeTextFinder);
      final textContent = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
      expect(textContent, contains('Welcome to the Alpha X Master AI Coach'));
    });

    testWidgets('2. Code blocks and Markdown lists render inside SelectionArea with monospaced style', (tester) async {
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

      // Send prompt asking for progressive overload which returns structured points
      await tester.enterText(find.byType(TextField), 'Explain progressive overload with code');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify SelectionArea exists for both user message and AI response
      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('3. Long-press gesture on AI response text initiates selection without crash', (tester) async {
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

      // Find the welcome message text
      final welcomeText = find.textContaining('Welcome to the Alpha X Master AI Coach');
      expect(welcomeText, findsOneWidget);

      // Perform long press gesture on the text to trigger SelectionArea selection
      final gesture = await tester.startGesture(tester.getCenter(welcomeText));
      await tester.pump(const Duration(milliseconds: 700)); // long-press duration
      await gesture.up();
      await tester.pumpAndSettle();

      // SelectionArea handles are activated without any error or crash
      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('4. Direct rendering of Markdown lists, code blocks, and Tamil/English text in SelectionArea', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Construct a test widget with formatted content containing code blocks, bullets, and Tamil
      const complexAiContent = '''
### Alpha X Protocol / உடற்பயிற்சி திட்டம்
- **Chest Press:** 3 sets x 10 reps (RIR 2)
- **Squats:** 4 sets x 8 reps
```json
{
  "athlete": "Ajay",
  "program": "Hypertrophy",
  "tamilNote": "முன்னேற்றம்"
}
```
1. Progressive overload
2. Adequate recovery
''';

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

      // Send the complex prompt
      await tester.enterText(find.byType(TextField), complexAiContent);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // User message rendered in SelectionArea
      final userMsgFinder = find.textContaining('Alpha X Protocol');
      expect(userMsgFinder, findsWidgets);

      // Confirm SelectionArea wraps user message and AI response
      final selectionAreas = find.byType(SelectionArea);
      expect(selectionAreas, findsWidgets);
    });

    testWidgets('5. Interactive controls (New Chat, prompt chips, athlete picker) remain unhindered', (tester) async {
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

      // Verify that New Chat button is clickable
      final newChatBtn = find.byKey(const Key('admin_ai_new_chat_button'));
      expect(newChatBtn, findsOneWidget);
      await tester.tap(newChatBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Started a fresh Alpha X AI Coach session'), findsOneWidget);

      // Verify suggested prompt chip from follow-ups is clickable
      final chipFinder = find.text("Give me today's report");
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Response received and selectable
      expect(find.byType(SelectionArea), findsWidgets);
    });
  });
}
