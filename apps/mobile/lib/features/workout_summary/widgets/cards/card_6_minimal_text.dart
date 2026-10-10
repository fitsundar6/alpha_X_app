import 'package:flutter/material.dart';
import '../../models/workout_summary_models.dart';
import '../../utils/ordinal_formatter.dart';
import '../share_card_base.dart';

/// Page 6: Minimal Text-Only Card.
class Card6MinimalText extends StatelessWidget {
  final WorkoutSummary summary;

  const Card6MinimalText({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final mins = summary.duration.inMinutes;
    final formattedVolume = summary.totalVolume.toStringAsFixed(0);

    return ShareCardBase(
      summary: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Giant Editorial Typographic Statement
          Text(
            formatOrdinal(summary.workoutNumber).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFFFC400),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'WORKOUT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 0.95,
              letterSpacing: -1.0,
            ),
          ),
          const Text(
            'CRUSHED.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1.0,
            ),
          ),

          const SizedBox(height: 16),

          // High-contrast stat line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Text(
              '$formattedVolume KG MOVED  •  $mins MINS  •  ${summary.exercises.length} MOVEMENTS',
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),

          const Spacer(),

          // Minimalist Manifesto Quote
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFFFC400), width: 2.5),
              ),
            ),
            child: const Text(
              '"Discipline is choosing between what you want now and what you want most."',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
