import 'package:flutter/material.dart';
import '../../models/workout_summary_models.dart';
import '../share_card_base.dart';

/// Page 4: Personal Records Card.
class Card4PersonalRecords extends StatelessWidget {
  final WorkoutSummary summary;

  const Card4PersonalRecords({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCardBase(
      summary: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          // Trophy Glow Circle
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFC400).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFFFFC400).withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC400).withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events_rounded,
                size: 32,
                color: Color(0xFFFFC400),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'PERSONAL RECORDS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'New milestones reached today',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPrItem(
                  exercise: 'Barbell Back Squat',
                  metric: '120.0 kg',
                  delta: '+5.0 kg All-Time Best',
                ),
                const SizedBox(height: 8),
                _buildPrItem(
                  exercise: 'Leg Press',
                  metric: '180.0 kg',
                  delta: '+10.0 kg 1RM Est.',
                ),
                const SizedBox(height: 8),
                _buildPrItem(
                  exercise: 'Romanian Deadlift',
                  metric: '10 Reps @ 100 kg',
                  delta: '+2 Reps Volume Record',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrItem({
    required String exercise,
    required String metric,
    required String delta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  delta,
                  style: const TextStyle(
                    color: Color(0xFFFFC400),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFC400).withOpacity(0.3)),
            ),
            child: Text(
              metric,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
