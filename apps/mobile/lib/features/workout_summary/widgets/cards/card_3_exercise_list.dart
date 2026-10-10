import 'package:flutter/material.dart';
import '../../models/workout_summary_models.dart';
import '../../utils/muscle_mapping.dart';
import '../share_card_base.dart';

/// Page 3: Exercise List Card.
class Card3ExerciseList extends StatelessWidget {
  final WorkoutSummary summary;

  const Card3ExerciseList({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCardBase(
      summary: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EXERCISE BREAKDOWN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Text(
                  '${summary.exercises.length} Movements',
                  style: const TextStyle(
                    color: Color(0xFFFFC400),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: summary.exercises.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ex = summary.exercises[index];
                final primaryMuscles = ex.primaryMuscles.isNotEmpty
                    ? ex.primaryMuscles
                        .map((m) => kMuscleRegistry[m]?.displayName ?? m)
                        .join(', ')
                    : 'Target Muscles';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF242424)),
                  ),
                  child: Row(
                    children: [
                      // Exercise number indicator
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFFFFC400),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Exercise Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              primaryMuscles,
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sets x Reps @ Weight badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF333333)),
                        ),
                        child: Text(
                          '${ex.sets}×${ex.reps} @ ${ex.weight.toStringAsFixed(0)}kg',
                          style: const TextStyle(
                            color: Color(0xFFFFC400),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
