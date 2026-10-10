import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/analytics/domain/models/workout_analytics_models.dart';

class MuscleRadarChart extends StatelessWidget {
  final List<MuscleGroupStat> stats;

  const MuscleRadarChart({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);

    // Core 6 regions
    final regions = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core'];
    final Map<String, int> setsMap = {
      for (final s in stats) s.muscleGroup: s.totalSets,
    };

    int maxSets = 0;
    for (final r in regions) {
      final val = setsMap[r] ?? 0;
      if (val > maxSets) maxSets = val;
    }

    final entries = regions.map((r) {
      final s = (setsMap[r] ?? 0).toDouble();
      return RadarEntry(value: s);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
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
                      color: colors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.radar, color: colors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MUSCLE DISTRIBUTION',
                    style: GoogleFonts.poppins(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  'SETS BY REGION',
                  style: GoogleFonts.poppins(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: maxSets == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pie_chart_outline,
                            size: 40, color: colors.textTertiary),
                        const SizedBox(height: 8),
                        Text(
                          'No workout sets logged in this period',
                          style: GoogleFonts.poppins(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : RadarChart(
                    RadarChartData(
                      dataSets: [
                        RadarDataSet(
                          fillColor: colors.primary.withOpacity(0.25),
                          borderColor: colors.primary,
                          entryRadius: 3,
                          dataEntries: entries,
                          borderWidth: 2.2,
                        ),
                      ],
                      radarBackgroundColor: Colors.transparent,
                      radarBorderData: BorderSide(
                        color: colors.border.withOpacity(0.6),
                        width: 1.2,
                      ),
                      titlePositionPercentageOffset: 0.22,
                      titleTextStyle: GoogleFonts.poppins(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      getTitle: (index, angle) {
                        if (index >= 0 && index < regions.length) {
                          final region = regions[index];
                          final count = setsMap[region] ?? 0;
                          return RadarChartTitle(
                            text: '$region\n(${count}s)',
                            angle: angle,
                          );
                        }
                        return const RadarChartTitle(text: '');
                      },
                      tickCount: 3,
                      ticksTextStyle: GoogleFonts.poppins(
                        color: colors.textTertiary,
                        fontSize: 9,
                      ),
                      tickBorderData: BorderSide(
                        color: colors.border.withOpacity(0.3),
                        width: 1,
                      ),
                      gridBorderData: BorderSide(
                        color: colors.border.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
