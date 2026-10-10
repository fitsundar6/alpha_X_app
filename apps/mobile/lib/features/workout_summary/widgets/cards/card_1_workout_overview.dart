import 'package:flutter/material.dart';
import '../../models/workout_summary_models.dart';
import '../share_card_base.dart';

/// Page 1: Workout Summary Card (Duration, Volume, Exercises, PRs).
class Card1WorkoutOverview extends StatelessWidget {
  final WorkoutSummary summary;

  const Card1WorkoutOverview({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final mins = summary.duration.inMinutes;
    final secs = summary.duration.inSeconds % 60;
    final durationString = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    final volumeString = summary.totalVolume >= 1000
        ? '${(summary.totalVolume / 1000).toStringAsFixed(1)}k kg'
        : '${summary.totalVolume.toStringAsFixed(0)} kg';
    final totalSets = summary.exercises.fold<int>(0, (sum, ex) => sum + ex.sets);
    final prs = summary.prsCount ?? 3;

    return ShareCardBase(
      summary: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          // Subheader Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC400).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFC400).withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: Color(0xFFFFC400),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'COMPLETED WORKOUT',
                      style: TextStyle(
                        color: Color(0xFFFFC400),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2x2 Metric Grid
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.timer_outlined,
                          title: 'DURATION',
                          value: durationString,
                          accentColor: const Color(0xFFFFC400),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.fitness_center_rounded,
                          title: 'TOTAL VOLUME',
                          value: volumeString,
                          accentColor: const Color(0xFFFF6B00),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.format_list_bulleted_rounded,
                          title: 'EXERCISES',
                          value: '${summary.exercises.length} ($totalSets sets)',
                          accentColor: const Color(0xFF64B5F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.emoji_events_rounded,
                          title: 'PERSONAL RECORDS',
                          value: '$prs New PRs',
                          accentColor: const Color(0xFFFFD54F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Bottom Quick Quote or Effort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFFFC400),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% Target volume completed with high intensity.',
                    style: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: accentColor, size: 18),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
