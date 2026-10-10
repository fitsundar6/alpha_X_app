import 'package:flutter/material.dart';
import '../../models/workout_summary_models.dart';
import '../share_card_base.dart';

/// Page 5: Streak & Consistency Calendar Card.
class Card5StreakCalendar extends StatelessWidget {
  final WorkoutSummary summary;

  const Card5StreakCalendar({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final streak = summary.streakDays ?? 14;

    return ShareCardBase(
      summary: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          // Flame Streak Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6B00).withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF6B00),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$streak DAY STREAK',
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Days of the week row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'THIS WEEK',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '3 of 4 Sessions',
                      style: TextStyle(
                        color: Color(0xFFFFC400),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDayPill('M', true),
                    _buildDayPill('T', false),
                    _buildDayPill('W', true),
                    _buildDayPill('T', false),
                    _buildDayPill('F', true, isToday: true),
                    _buildDayPill('S', false),
                    _buildDayPill('S', false),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Total Workouts Stat Banner
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC400).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.military_tech_rounded,
                        color: Color(0xFFFFC400),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${summary.workoutNumber} Lifetime Workouts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Top 5% of athletes in Alpha X Gym consistency.',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPill(String day, bool isDone, {bool isToday = false}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? const Color(0xFFFFC400)
                : const Color(0xFF222222),
            border: isToday
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Colors.black,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          day,
          style: TextStyle(
            color: isToday ? Colors.white : const Color(0xFF8E8E93),
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
