import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

class ClientWorkoutCompletionScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final int durationSeconds;
  final List<PersonalRecord> achievedPRs;

  const ClientWorkoutCompletionScreen({
    super.key,
    required this.workoutRepository,
    required this.durationSeconds,
    this.achievedPRs = const [],
  });

  @override
  State<ClientWorkoutCompletionScreen> createState() => _ClientWorkoutCompletionScreenState();
}

class _ClientWorkoutCompletionScreenState extends State<ClientWorkoutCompletionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _workoutNoteController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Trigger celebration haptic feedback
    HapticFeedback.heavyImpact();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _workoutNoteController.dispose();
    super.dispose();
  }

  void _finishAndSave() {
    HapticFeedback.mediumImpact();
    widget.workoutRepository.completeWorkout(
      notes: _workoutNoteController.text.trim().isEmpty ? null : _workoutNoteController.text.trim(),
      durationSeconds: widget.durationSeconds,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout saved & synced to backend successfully!'),
        backgroundColor: AppColors.primaryRed,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.workoutRepository.activeSession;

    int totalCompleted = 0;
    int totalSkipped = 0;
    double totalVolume = 0.0;
    double rpeSum = 0;
    int rpeCount = 0;
    double rirSum = 0;
    int rirCount = 0;

    for (final ex in session.exercises) {
      if (ex.isSkipped) {
        totalSkipped += ex.sets.length;
      } else {
        for (final s in ex.sets) {
          if (s.isCompleted) {
            totalCompleted++;
            totalVolume += s.volume;
            if (s.actualRpe != null) {
              rpeSum += s.actualRpe!;
              rpeCount++;
            }
            if (s.actualRir != null) {
              rirSum += s.actualRir!;
              rirCount++;
            }
          } else {
            totalSkipped++;
          }
        }
      }
    }

    final durationMin = (widget.durationSeconds / 60).floor();
    final durationSec = widget.durationSeconds % 60;
    final avgRpe = rpeCount > 0 ? (rpeSum / rpeCount).toStringAsFixed(1) : '—';
    final avgRir = rirCount > 0 ? (rirSum / rirCount).toStringAsFixed(1) : '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            AlphaXLogo.appBar(size: 26),
            SizedBox(width: 10),
            Text(
              'ALPHA X GYM',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Celebration Icon with smooth entrance animation
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.glowRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryRed, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.primaryRed, size: 50),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Center(
            child: Text(
              'WORKOUT COMPLETE',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 24,
              ),
            ),
          ),
          Center(
            child: Text(
              session.title,
              style: const TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Duration', '${durationMin}m ${durationSec}s', Icons.timer),
                    _statItem('Total Volume', '${totalVolume.toInt()} kg', Icons.fitness_center),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Exercises', '${session.exercises.length}', Icons.format_list_bulleted),
                    _statItem('Completed Sets', '$totalCompleted', Icons.check_circle_outline),
                    _statItem('Skipped Sets', '$totalSkipped', Icons.skip_next),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Average RPE', avgRpe, Icons.speed),
                    _statItem('Average RIR', avgRir, Icons.trending_up),
                  ],
                ),
              ],
            ),
          ),

          // Personal Records achieved section
          if (widget.achievedPRs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.glowRed,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryRed),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PERSONAL RECORDS ACHIEVED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...widget.achievedPRs.map((pr) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_right, color: AppColors.gold, size: 16),
                          Expanded(
                            child: Text(
                              '${pr.exerciseName}: ${pr.formattedValue}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pr.type.badgeLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Workout Note Input
          TextField(
            controller: _workoutNoteController,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Session Performance Note (Optional)',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              hintText: 'e.g. Great shoulder pump, felt strong on pressing...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),

          const SizedBox(height: 24),

          // Finish and Save Button with AlphaXPressable
          AlphaXPressable(
            onTap: _finishAndSave,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'FINISH & SAVE WORKOUT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryRed),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
