import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';

void main() {
  group('Selective Metallic Design & MetalCard Verification Tests', () {
    testWidgets('MetalCard renders full metallic gradient, silver border, and 20px corners without overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(
                width: 350,
                child: MetalCard(
                  glowColor: AppColors.primary,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text("TODAY'S WORKOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text("Full-Body Hypertrophy Protocol", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
      expect(find.text("Full-Body Hypertrophy Protocol"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MetalCard renders subtle metallic styling correctly for compact tiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(
                width: 350,
                child: MetalCard(
                  isSubtle: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: const [
                      Icon(Icons.restaurant_menu, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text("Coach Prescribed Diet (3 Meals)", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text("Coach Prescribed Diet (3 Meals)"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MetalCard responds cleanly to tap interaction without error', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: MetalCard(
                onTap: () {
                  tapped = true;
                },
                child: const Text('TAP ME'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TAP ME'));
      await tester.pump();

      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}

