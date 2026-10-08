import 'dart:async';
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
/// Implements the cinematic "ALPHA X ENERGY REVEAL" launch sequence:
/// 1. Phase 1 (Dark Start): Pure deep black background, subtle dark red ambient glow.
/// 2. Phase 2 (Ambient Energy): Smooth, slow red ambient light movement in the background.
/// 3. Phase 3 (Energy Trace): Razor-thin crimson light beam sweeps across screen to reveal logo.
/// 4. Phase 4 (Logo Reveal): Existing Alpha X logo appears, soft-to-sharp with 96% -> 100% scale.
/// 5. Phase 5 (Red Light Sweep): Elegant specular crimson sweep across the logo.
/// 6. Phase 6 (Brand Line): Briefly reveals "STRENGTH • CONDITIONING • BOXING • TRANSFORMATION".
/// 7. Phase 7 (Transition): Smooth fade into the existing client dashboard or login screen.
///
/// Fully error-safe: Features a watchdog timer and tap-to-skip so the app startup is never blocked.
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
    this.animationDuration = const Duration(milliseconds: 1400),
    this.destinationBuilder,
  });

  @override
  State<AlphaXSplashScreen> createState() => AlphaXSplashScreenState();
}

class AlphaXSplashScreenState extends State<AlphaXSplashScreen> {
  bool _hasNavigated = false;
  Timer? _safetyWatchdogTimer;

  @override
  void initState() {
    super.initState();
    // Watchdog fallback: guarantees app moves to destination even if animations or frames stall
    _safetyWatchdogTimer = Timer(
      widget.animationDuration + const Duration(milliseconds: 350),
      navigateToDestination,
    );
  }

  @override
  void dispose() {
    _safetyWatchdogTimer?.cancel();
    super.dispose();
  }

  /// Transition immediately into the resolved destination screen
  void navigateToDestination() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _safetyWatchdogTimer?.cancel();

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
            showBrandLine: true,
          ),
        ),
      ),
    );
  }
}
