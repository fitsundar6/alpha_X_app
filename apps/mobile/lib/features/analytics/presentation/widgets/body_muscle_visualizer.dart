import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/analytics/domain/models/workout_analytics_models.dart';

class BodyMuscleVisualizer extends StatelessWidget {
  final List<MuscleGroupStat> stats;

  const BodyMuscleVisualizer({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);

    // Map stats by name
    final statMap = {for (final s in stats) s.muscleGroup: s};
    final maxSets = stats.fold<int>(0, (max, s) => s.totalSets > max ? s.totalSets : max);

    // 6 core regions with anatomical icons/details
    final regions = [
      {'name': 'Chest', 'icon': Icons.shield_outlined, 'desc': 'Pectorals'},
      {'name': 'Back', 'icon': Icons.accessibility_new_rounded, 'desc': 'Lats & Traps'},
      {'name': 'Shoulders', 'icon': Icons.sports_kabaddi_rounded, 'desc': 'Deltoids'},
      {'name': 'Arms', 'icon': Icons.fitness_center_rounded, 'desc': 'Biceps & Triceps'},
      {'name': 'Legs', 'icon': Icons.directions_run_rounded, 'desc': 'Quads & Glutes'},
      {'name': 'Core', 'icon': Icons.align_vertical_center_rounded, 'desc': 'Abs & Obliques'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grid of 6 anatomical muscle regions
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: regions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
          ),
          itemBuilder: (context, index) {
            final item = regions[index];
            final name = item['name'] as String;
            final icon = item['icon'] as IconData;
            final desc = item['desc'] as String;
            final stat = statMap[name];
            final sets = stat?.totalSets ?? 0;
            final volStr = stat?.formattedVolume ?? '0 kg';

            // Determine intensity tier based on relative activity
            final double ratio = maxSets > 0 ? (sets / maxSets) : 0.0;
            final Color intensityColor;
            final String intensityLabel;

            if (sets == 0) {
              intensityColor = colors.textTertiary.withOpacity(0.3);
              intensityLabel = 'INACTIVE';
            } else if (ratio < 0.35) {
              intensityColor = const Color(0xFF38BDF8); // Cyan/Light Blue
              intensityLabel = 'LIGHT';
            } else if (ratio < 0.70) {
              intensityColor = const Color(0xFFF59E0B); // Amber
              intensityLabel = 'MODERATE';
            } else {
              intensityColor = colors.primary; // Gold/Brand Accent
              intensityLabel = 'PEAK FOCUS';
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sets > 0
                      ? intensityColor.withOpacity(0.35)
                      : colors.border,
                  width: sets > 0 ? 1.2 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 16, color: intensityColor),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: intensityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          intensityLabel,
                          style: GoogleFonts.poppins(
                            color: intensityColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 8.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.poppins(
                      color: colors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$sets sets',
                        style: GoogleFonts.poppins(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        volStr,
                        style: GoogleFonts.poppins(
                          color: sets > 0 ? colors.primary : colors.textTertiary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Distinction Notice Callout Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.isDark
                ? const Color(0x1A38BDF8)
                : const Color(0x100284C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF38BDF8).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAINING VOLUME VS. MUSCLE MEASUREMENT',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF38BDF8),
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Training volume (weight × reps) measures total mechanical workload logged during training, not direct physiological muscle circumference or muscle-development measurements.',
                      style: GoogleFonts.poppins(
                        color: colors.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
