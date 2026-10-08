import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import 'alpha_x_logo_animation.dart';
import '../../main.dart';
import '../../features/workout/data/repositories/workout_repository.dart';
import '../../features/activity/data/repositories/activity_repository.dart';
import '../../features/macro_planner/data/repositories/macro_repository.dart';
import '../../features/progress/data/repositories/weekly_progress_repository.dart';

/// The official Alpha X Gym startup splash screen.
///
/// Displayed on EVERY fresh app launch:
/// 1. App opens -> Cinematic Alpha X logo animation plays in a pure dark stage.
/// 2. Performs authentication check synchronously without rendering behind the animation.
/// 3. Smoothly transitions to the appropriate existing screen:
///    - Logged in client -> Client Dashboard (NavigationShell)
///    - Logged in admin -> Admin Main Dashboard (AdminMainDashboardScreen)
///    - Pending assessment -> Client Onboarding (ClientOnboardingScreen)
///    - Logged out / Expired session -> Existing Login Screen (LoginScreen, settled)
///
/// Supports instant tap-to-skip so users can jump straight into the app at any time.
class AlphaXSplashScreen extends StatefulWidget {
  final AuthService? authService;
  final WorkoutRepository? workoutRepository;
  final ActivityRepository? activityRepository;
  final MacroRepository? macroRepository;
  final WeeklyProgressRepository? weeklyProgressRepository;
  final Duration animationDuration;
  final Widget Function()? destinationBuilder;

  const AlphaXSplashScreen({
    super.key,
    this.authService,
    this.workoutRepository,
    this.activityRepository,
    this.macroRepository,
    this.weeklyProgressRepository,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.destinationBuilder,
  });

  @override
  State<AlphaXSplashScreen> createState() => AlphaXSplashScreenState();
}

class AlphaXSplashScreenState extends State<AlphaXSplashScreen> {
  bool _hasNavigated = false;

  /// Transition immediately into the resolved destination screen
  void navigateToDestination() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Ensure LoginScreen opens directly in its settled form without replaying the logo reveal
    LoginScreen.hasPlayedIntro = true;

    final destination = widget.destinationBuilder != null
        ? widget.destinationBuilder!()
        : getInitialScreen(
            authService: widget.authService,
            workoutRepository: widget.workoutRepository,
            activityRepository: widget.activityRepository,
            macroRepository: widget.macroRepository,
            weeklyProgressRepository: widget.weeklyProgressRepository,
          );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: navigateToDestination,
        child: Center(
          child: AlphaXLogoAnimation(
            size: 160.0,
            duration: widget.animationDuration,
            allowTapToSkip: false, // Handled immediately by outer GestureDetector
            onComplete: navigateToDestination,
          ),
        ),
      ),
    );
  }
}
