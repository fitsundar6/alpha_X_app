import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';

class CoachReviewCard extends StatelessWidget {
  final WeeklyCheckIn checkIn;
  final bool isAdmin;
  final VoidCallback? onEditReview;

  const CoachReviewCard({
    super.key,
    required this.checkIn,
    this.isAdmin = false,
    this.onEditReview,
  });

  @override
  Widget build(BuildContext context) {
    final hasReview = checkIn.hasCoachReview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(
          color: hasReview
              ? AlphaXColors.redAccent.withValues(alpha: 0.4)
              : AlphaXColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AlphaXColors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.rate_review_rounded,
                      color: AlphaXColors.redAccent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'WEEKLY COACH REVIEW',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (isAdmin)
                TextButton.icon(
                  onPressed: onEditReview,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AlphaXColors.redAccent,
                  ),
                  icon: Icon(hasReview ? Icons.edit_rounded : Icons.add_rounded, size: 14),
                  label: Text(
                    hasReview ? 'Edit Review' : 'Add Review',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                )
              else if (hasReview && checkIn.followUpRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AlphaXColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AlphaXColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Follow-up Required',
                    style: TextStyle(color: AlphaXColors.warning, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasReview)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                isAdmin
                    ? 'No coach review submitted yet for Week ${checkIn.weekNumber}. Tap "Add Review" above.'
                    : 'Your coach will review this check-in and post feedback here.',
                style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            if (checkIn.reviewedByName != null && checkIn.reviewedByName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AlphaXColors.gold, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Reviewed by ${checkIn.reviewedByName}',
                      style: const TextStyle(color: AlphaXColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    if (checkIn.reviewedAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${checkIn.reviewedAt!.toIso8601String().substring(0, 10)}',
                        style: const TextStyle(color: AlphaXColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            if (checkIn.whatWentWell != null && checkIn.whatWentWell!.isNotEmpty)
              _buildReviewSection('What Went Well', checkIn.whatWentWell!, Icons.thumb_up_rounded, AlphaXColors.success),
            if (checkIn.needsImprovement != null && checkIn.needsImprovement!.isNotEmpty)
              _buildReviewSection('Needs Improvement', checkIn.needsImprovement!, Icons.trending_up_rounded, AlphaXColors.warning),
            if (checkIn.nextWeekFocus != null && checkIn.nextWeekFocus!.isNotEmpty)
              _buildReviewSection('Focus for Next Week', checkIn.nextWeekFocus!, Icons.track_changes_rounded, AlphaXColors.redAccent),
            if (checkIn.workoutNotes != null && checkIn.workoutNotes!.isNotEmpty)
              _buildReviewSection('Workout Notes', checkIn.workoutNotes!, Icons.fitness_center_rounded, AlphaXColors.textSecondary),
            if (checkIn.nutritionNotes != null && checkIn.nutritionNotes!.isNotEmpty)
              _buildReviewSection('Nutrition Notes', checkIn.nutritionNotes!, Icons.restaurant_rounded, AlphaXColors.textSecondary),
            if (checkIn.recoveryNotes != null && checkIn.recoveryNotes!.isNotEmpty)
              _buildReviewSection('Recovery Notes', checkIn.recoveryNotes!, Icons.bedtime_rounded, AlphaXColors.textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, String content, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AlphaXColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AlphaXColors.border),
            ),
            child: Text(
              content,
              style: const TextStyle(
                color: AlphaXColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
