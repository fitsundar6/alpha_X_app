import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/main.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';

void main() {
  testWidgets('Alpha X Gym App loads directly into login flow and displays brand title', (WidgetTester tester) async {
    await tester.pumpWidget(const AlphaXGymApp());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('ALPHA X GYM'), findsOneWidget);
    expect(find.text('ENTER ALPHA X GYM'), findsNothing);
  });
}
