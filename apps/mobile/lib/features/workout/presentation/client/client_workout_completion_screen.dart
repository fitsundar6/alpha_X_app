import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

/// Simplified, premium workout completion screen for Alpha X Gym.
///
/// Replaces detailed metrics/summaries (muscles, sets, reps, volume)
/// with a single, changing motivational fitness message displayed
/// prominently in the center with a black-and-gold aesthetic.
class ClientWorkoutCompletionScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final WorkoutRecord? completedRecord;
  final int durationSeconds;
  final List<PersonalRecord> achievedPRs;
  final String? motivationalMessage;

  const ClientWorkoutCompletionScreen({
    super.key,
    required this.workoutRepository,
    this.completedRecord,
    required this.durationSeconds,
    this.achievedPRs = const [],
    this.motivationalMessage,
  });

  /// Curated list of short, powerful motivational fitness messages.
  static const List<String> motivationalMessages = [
    'Beast Mode Activated!',
    'Another Step Closer to Your Goal!',
    'You Showed Up. You Won!',
    'Discipline Beats Motivation!',
    'Stronger Than Yesterday!',
    'Champions Are Built, Not Born!',
    'One Workout. One Step Forward!',
    'Your Future Self Thanks You!',
    'Progress Over Perfection!',
    'You Earned This Victory!',
  ];

  static String? _lastMotivationalMessage;
  static const String prefLastMessageKey =
      'alpha_x_last_completion_motivational_message';

  /// Selects a motivational message randomly from [motivationalMessages],
  /// avoiding the immediately previous message whenever possible.
  static String selectNextMotivationalMessage({
    Random? random,
    String? previousMessage,
  }) {
    final prev = previousMessage ?? _lastMotivationalMessage;
    final rng = random ?? Random();

    final candidates =
        motivationalMessages.where((msg) => msg != prev).toList();
    final pool = candidates.isNotEmpty ? candidates : motivationalMessages;

    final selected = pool[rng.nextInt(pool.length)];
    _lastMotivationalMessage = selected;
    return selected;
  }

  @visibleForTesting
  static void setLastMessageForTesting(String? message) {
    _lastMotivationalMessage = message;
  }

  @visibleForTesting
  static String? get lastMotivationalMessage => _lastMotivationalMessage;

  @visibleForTesting
  static void resetLastMessageForTesting() {
    _lastMotivationalMessage = null;
  }

  @override
  State<ClientWorkoutCompletionScreen> createState() =>
      _ClientWorkoutCompletionScreenState();
}

class _ClientWorkoutCompletionScreenState
    extends State<ClientWorkoutCompletionScreen>
    with SingleTickerProviderStateMixin {
  late final String _motivationalMessage;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isNavigatingBack = false;

  @override
  void initState() {
    super.initState();
    _motivationalMessage = widget.motivationalMessage ??
        ClientWorkoutCompletionScreen.selectNextMotivationalMessage();
    _saveLastMessageToPrefs(_motivationalMessage);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();
    HapticFeedback.heavyImpact();
  }

  Future<void> _saveLastMessageToPrefs(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ClientWorkoutCompletionScreen.prefLastMessageKey,
        message,
      );
    } catch (_) {
      // Gracefully ignore in testing or restricted environments
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDone() {
    if (_isNavigatingBack) return;
    _isNavigatingBack = true;
    HapticFeedback.lightImpact();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 0.9,
            colors: [
              Color(0x18FFDE00), // Subtle ambient gold aura
              Color(0xFF0D0D0D), // Deep obsidian background
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // --- TOP BRANDING ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AlphaXLogo.appBar(size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ALPHA X GYM',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          color: const Color(0xFFFFDE00),
                        ),
                      ),
                    ],
                  ),

                  // --- CENTER MOTIVATIONAL MESSAGE ---
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Celebratory Gold Trophy / Shield Badge
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF242424),
                                  Color(0xFF141414),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFDE00),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFDE00).withOpacity(0.35),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFFFDE00),
                                size: 50,
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Clean category header
                          Text(
                            'WORKOUT COMPLETED',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.0,
                              color: const Color(0xFF9E9E9E),
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          // Single prominent motivational message
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              _motivationalMessage,
                              key: const ValueKey('completion_motivational_message'),
                              style: GoogleFonts.poppins(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.25,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- BOTTOM ACTION: RETURN TO DASHBOARD ---
                  KeyedSubtree(
                    key: const ValueKey('completion_done_button_top'),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        key: const ValueKey('completion_done_button'),
                        onPressed: _isNavigatingBack ? null : _onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFDE00),
                          foregroundColor: const Color(0xFF111111),
                          disabledBackgroundColor:
                              const Color(0xFFFFDE00).withOpacity(0.5),
                          elevation: 6,
                          shadowColor: const Color(0xFFFFDE00).withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Return to Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: const Color(0xFF111111),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
