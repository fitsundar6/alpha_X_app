import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/main.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';

void main() {
  testWidgets('Alpha X Gym App loads splash and displays brand title', (WidgetTester tester) async {
    await tester.pumpWidget(const AlphaXGymApp());

    expect(find.text('ALPHA X GYM'), findsOneWidget);
    expect(find.text(AppConstants.appTagline), findsOneWidget);
  });
}
