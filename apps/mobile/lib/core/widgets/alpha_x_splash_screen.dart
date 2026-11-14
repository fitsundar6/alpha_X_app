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
/// Implements the finalized cinematic branding reveal:
/// 1. Pure black canvas with subtle ambient bottom bloom gradient.
/// 2. Centered official Alpha X Gym brand mark with smooth 4.5s ease-out emergence (scale, opacity, blur).
/// 3. Synchronized bottom-up tagline reveal: "STARTING POINT OF NEW JOURNEY".
///
/// Error-safe: Features a watchdog timer (widget.animationDuration + 400ms) and tap-to-skip
/// so app startup and session restoration are never delayed or blocked.
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
    this.animationDuration = const Duration(milliseconds: 4800),
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
    // Safety watchdog timer: guarantees navigation proceeds even if frame pipeline stalls
    _safetyWatchdogTimer = Timer(
      widget.animationDuration + const Duration(milliseconds: 400),
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

    // Ensure LoginScreen opens directly in settled state without replaying intro
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
        child: SizedBox.expand(
          child: AlphaXLogoAnimation(
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
