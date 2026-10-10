import 'package:flutter/material.dart';
import '../models/workout_summary_models.dart';
import 'workout_complete_modal.dart';

/// Interactive standalone demonstration screen featuring the "Finish Workout" button.
/// Allows instant testing of the modal bottom sheet, SVG anatomy rendering,
/// and social export actions.
class WorkoutSummaryDemoScreen extends StatefulWidget {
  const WorkoutSummaryDemoScreen({super.key});

  @override
  State<WorkoutSummaryDemoScreen> createState() =>
      _WorkoutSummaryDemoScreenState();
}

class _WorkoutSummaryDemoScreenState extends State<WorkoutSummaryDemoScreen> {
  bool _useCustomData = false;

  WorkoutSummary get _activeSummary {
    if (!_useCustomData) {
      // Specification mock data (Quadriceps 1 set, Glutes 1 set, Hamstrings 1 set)
      return WorkoutSummary.mock();
    } else {
      // Dynamic Upper/Full Body alternative dataset
      return WorkoutSummary(
        planName: 'Hypertrophy Upper Body',
        week: 2,
        day: 4,
        date: DateTime.now(),
        workoutNumber: 82,
        duration: const Duration(minutes: 64, seconds: 15),
        totalVolume: 11250.0,
        username: '@alex_fit',
        streakDays: 15,
        prsCount: 2,
        exercises: [
          ExerciseLog(
            name: 'Incline Dumbbell Bench Press',
            primaryMuscles: ['chest', 'shoulders'],
            secondaryMuscles: ['triceps'],
            sets: 4,
            reps: 10,
            weight: 36.0,
          ),
          ExerciseLog(
            name: 'Barbell Row',
            primaryMuscles: ['lats', 'traps'],
            secondaryMuscles: ['biceps'],
            sets: 4,
            reps: 8,
            weight: 85.0,
          ),
          ExerciseLog(
            name: 'Overhead Shoulder Press',
            primaryMuscles: ['shoulders'],
            secondaryMuscles: ['triceps'],
            sets: 3,
            reps: 10,
            weight: 55.0,
          ),
          ExerciseLog(
            name: 'Bicep Cable Curl',
            primaryMuscles: ['biceps'],
            secondaryMuscles: ['forearms'],
            sets: 3,
            reps: 12,
            weight: 27.5,
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _activeSummary;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141415),
        elevation: 0,
        title: const Text(
          'WORKOUT COMPLETE DEMO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Mock Data',
            icon: Icon(
              _useCustomData ? Icons.tune_rounded : Icons.checklist_rounded,
              color: const Color(0xFFFFC400),
            ),
            onPressed: () {
              setState(() {
                _useCustomData = !_useCustomData;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Logo & Title Badge
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC400),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC400).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/alpha_x_logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.fitness_center_rounded,
                        size: 38,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Ready to Complete Workout',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Active Session: ${summary.planName} • Week ${summary.week} · Day ${summary.day}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 32),

              // Overview card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF26262A)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Dataset Mode',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC400).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            !_useCustomData
                                ? 'Reference Spec Mock'
                                : 'Upper Body Custom',
                            style: const TextStyle(
                              color: Color(0xFFFFC400),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF28282C), height: 24),
                    _buildDataRow('Athlete Handle', summary.username),
                    const SizedBox(height: 8),
                    _buildDataRow(
                      'Workout Number',
                      '#${summary.workoutNumber} (Ordinal: 81st)',
                    ),
                    const SizedBox(height: 8),
                    _buildDataRow(
                      'Target Muscles',
                      !_useCustomData
                          ? 'Quadriceps (1), Glutes (1), Hamstrings (1)'
                          : 'Chest (4), Shoulders (7), Lats (4)',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Primary "Finish Workout" Demo Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC400),
                  foregroundColor: Colors.black,
                  elevation: 6,
                  shadowColor: const Color(0xFFFFC400).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  showWorkoutCompleteModal(context, summary: _activeSummary);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.black,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Finish Workout',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _useCustomData = !_useCustomData;
                    });
                  },
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: Color(0xFF8E8E93),
                  ),
                  label: Text(
                    !_useCustomData
                        ? 'Switch to Upper Body Dataset'
                        : 'Switch to Reference Mock Dataset',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6E6E73),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
