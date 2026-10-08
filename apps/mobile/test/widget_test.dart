import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/main.dart';
import 'package:alpha_x_gym/core/auth/login_screen.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_splash_screen.dart';

void main() {
  testWidgets('Alpha X Gym App loads splash animation and settles into login flow', (WidgetTester tester) async {
    await tester.pumpWidget(const AlphaXGymApp());

    // Initially mounts the startup splash screen
    expect(find.byType(AlphaXSplashScreen), findsOneWidget);
    expect(find.text('ENTER ALPHA X GYM'), findsNothing);

    // After animation completes, settles into LoginScreen
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('ALPHA X GYM'), findsOneWidget);
  });
}
