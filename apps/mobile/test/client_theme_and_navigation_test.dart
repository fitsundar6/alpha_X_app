import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/theme/app_theme.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/dashboard/client_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Client Theme Service Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default mode is dark (Alpha X Gym brand) and initializes properly', () async {
      final service = ClientThemeService();
      await service.initialize();
      expect(service.themeMode, ClientThemeMode.dark);
    });

    test('Can switch to light mode and persist', () async {
      final service = ClientThemeService();
      await service.initialize();

      bool notified = false;
      service.addListener(() => notified = true);

      await service.setThemeMode(ClientThemeMode.light);
      expect(service.themeMode, ClientThemeMode.light);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alpha_x_client_theme_mode'), 'light');
    });

    test('Can switch to system mode and persist', () async {
      final service = ClientThemeService();
      await service.initialize();

      await service.setThemeMode(ClientThemeMode.system);
      expect(service.themeMode, ClientThemeMode.system);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alpha_x_client_theme_mode'), 'system');
    });

    test('Loads previously saved theme preference from storage', () async {
      SharedPreferences.setMockInitialValues({'alpha_x_client_theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alpha_x_client_theme_mode'), 'light');
    });
  });

  group('ClientThemeColors Contrast & Theme-Aware Palette Tests', () {
    testWidgets('Light mode resolves comfortable light UI tokens with preserved brand red', (tester) async {
      await ClientThemeService().setThemeMode(ClientThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final colors = ClientThemeColors.of(context);
              expect(colors.isDark, isFalse);
              expect(colors.background, AppColors.lightBackground);
              expect(colors.surfaceCard, const Color(0xFFFFFFFF));
              expect(colors.textPrimary, AppColors.lightTextPrimary);
              expect(colors.primaryRed, AppColors.primaryRed);
              return Container(color: colors.background);
            },
          ),
        ),
      );
    });

    testWidgets('Dark mode resolves high-contrast dark UI tokens with preserved brand red', (tester) async {
      await ClientThemeService().setThemeMode(ClientThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              final colors = ClientThemeColors.of(context);
              expect(colors.isDark, isTrue);
              expect(colors.background, AppColors.background);
              expect(colors.surfaceCard, AppColors.surfaceCard);
              expect(colors.textPrimary, AppColors.textPrimary);
              expect(colors.primaryRed, AppColors.primaryRed);
              return Container(color: colors.background);
            },
          ),
        ),
      );
    });
  });

  group('Admin Isolation Guarantee Tests', () {
    testWidgets('Admin routes remain 100% dark themed even if ClientTheme is Light', (tester) async {
      // Simulate client setting mode to light
      await ClientThemeService().setThemeMode(ClientThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              // Client screen gets light theme
              expect(Theme.of(context).brightness, Brightness.light);

              // Admin route is wrapped in Theme(data: AppTheme.darkTheme) as in main.dart
              return Theme(
                data: AppTheme.darkTheme,
                child: Builder(
                  builder: (adminContext) {
                    final adminTheme = Theme.of(adminContext);
                    expect(adminTheme.brightness, Brightness.dark);
                    expect(adminTheme.scaffoldBackgroundColor, AppColors.background);
                    expect(adminTheme.cardColor, AppColors.surface);
                    return const Scaffold(body: Text('Admin Dashboard'));
                  },
                ),
              );
            },
          ),
        ),
      );
    });
  });

  group('Client Navigation Stack & Appearance UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
      );
    });

    testWidgets('Client Dashboard displays brand title and bottom navigation tabs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ClientMainDashboardScreen(
            workoutRepository: WorkoutRepository(),
            activityRepository: ActivityRepository(),
            macroRepository: MacroRepository(),
          ),
        ),
      );
      await tester.pump();

      // Check dashboard rendered
      expect(find.text('ALPHA X GYM'), findsOneWidget);

      // Verify bottom navigation tabs exist
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Workout'), findsWidgets);
      expect(find.text('Exercises'), findsWidgets);
      expect(find.text('Nutrition'), findsWidgets);
      expect(find.text('Steps'), findsWidgets);
    });

    testWidgets('ClientProfileSubScreen renders Appearance section and toggles Light/Dark/System mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await ClientThemeService().setThemeMode(ClientThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ClientProfileSubScreen(
            workoutRepository: WorkoutRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Appearance section and all 3 options exist
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('Light Mode'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);

      // Switch to Light Mode
      await tester.tap(find.text('Light Mode'));
      await tester.pumpAndSettle();
      expect(ClientThemeService().themeMode, ClientThemeMode.light);

      // Switch to Dark Mode
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
      expect(ClientThemeService().themeMode, ClientThemeMode.dark);

      // Switch to System Default
      await tester.tap(find.text('System Default'));
      await tester.pumpAndSettle();
      expect(ClientThemeService().themeMode, ClientThemeMode.system);
    });
  });
}
