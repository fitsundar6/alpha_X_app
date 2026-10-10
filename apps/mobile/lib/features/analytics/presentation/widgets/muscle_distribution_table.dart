import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/analytics/domain/models/workout_analytics_models.dart';

class MuscleDistributionTable extends StatelessWidget {
  final List<MuscleGroupStat> stats;

  const MuscleDistributionTable({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);

    // Sort stats by sets descending
    final sortedStats = List<MuscleGroupStat>.from(stats)
      ..sort((a, b) => b.totalSets.compareTo(a.totalSets));

    final totalSets = stats.fold<int>(0, (sum, s) => sum + s.totalSets);

    if (totalSets == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          'No muscle group data recorded in this period',
          style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 12),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: colors.isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'MUSCLE GROUP',
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SETS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'FREQ (DAYS)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'VOLUME',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: colors.border, height: 1, thickness: 1),

          // Data Rows
          ...sortedStats.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isEven = idx % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: isEven
                  ? Colors.transparent
                  : (colors.isDark
                      ? Colors.white.withOpacity(0.015)
                      : Colors.black.withOpacity(0.01)),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.totalSets > 0
                                ? colors.primary
                                : colors.textTertiary.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.muscleGroup,
                            style: GoogleFonts.poppins(
                              color: item.totalSets > 0
                                  ? colors.textPrimary
                                  : colors.textTertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${item.totalSets}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: item.totalSets > 0
                            ? colors.textPrimary
                            : colors.textTertiary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${item.frequencyDays}d',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.formattedVolume,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(
                        color: item.totalVolumeKg > 0
                            ? colors.primary
                            : colors.textTertiary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
