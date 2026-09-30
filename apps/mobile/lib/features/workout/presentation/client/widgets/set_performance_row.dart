import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';

/// Clean reference row showing:
/// SET | PREVIOUS (Reference) | TODAY (Target or Achieved)
/// Ensuring historical performance is clearly distinguished from today's inputs.
class SetPerformanceRow extends StatelessWidget {
  final int setNumber;
  final String setTypeDisplay;
  final String? previousDisplay;
  final String targetDisplay;
  final String? actualDisplay;
  final bool isCompleted;

  const SetPerformanceRow({
    super.key,
    required this.setNumber,
    this.setTypeDisplay = 'WORKING',
    this.previousDisplay,
    required this.targetDisplay,
    this.actualDisplay,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.success.withOpacity(0.08) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted ? AppColors.success.withOpacity(0.4) : AppColors.border,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // SET COLUMN
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$setNumber',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // PREVIOUS PERFORMANCE (Reference only)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PREVIOUS',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previousDisplay != null && previousDisplay!.isNotEmpty
                      ? previousDisplay!
                      : '—',
                  style: TextStyle(
                    color: previousDisplay != null && previousDisplay!.isNotEmpty
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // TODAY (Target / Logged)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isCompleted ? 'LOGGED TODAY' : 'TODAY TARGET',
                  style: TextStyle(
                    color: isCompleted ? AppColors.success : AppColors.primaryRed,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCompleted ? (actualDisplay ?? targetDisplay) : targetDisplay,
                  style: TextStyle(
                    color: isCompleted ? Colors.white : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
