import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/analytics/domain/models/workout_analytics_models.dart';

class Exercise1RMChart extends StatelessWidget {
  final ExerciseAnalyticsData data;

  const Exercise1RMChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);

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
          // Header with Exercise Name and 1RM Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED 1RM PROGRESSION',
                      style: GoogleFonts.poppins(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.exerciseName,
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  data.formattedProgress,
                  style: GoogleFonts.poppins(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Key Metrics Row: Best Weight, Peak 1RM
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'BEST RECORDED',
                  value: data.formattedBestWeight,
                  subtitle: 'Top weight lifted',
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'PEAK 1RM (EST.)',
                  value: data.formattedPeak1RM,
                  subtitle: 'Brzycki estimate',
                  colors: colors,
                  isHighlight: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Line Chart or Fallback State
          if (!data.hasData)
            _buildEmptyState(colors)
          else if (data.trendPoints.length == 1)
            _buildSingleSessionState(colors, data.trendPoints.first)
          else
            _buildChart(colors, data.trendPoints),

          const SizedBox(height: 12),

          // Required Disclaimer Label
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 13, color: colors.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Brzycki formula estimate: 1RM = Weight × 36 / (37 − Reps). Theoretical estimate, not an actual tested maximum.',
                  style: GoogleFonts.poppins(
                    color: colors.textTertiary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required ClientThemeColors colors,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? colors.primary.withOpacity(0.4) : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: isHighlight ? colors.primary : colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: colors.textTertiary,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ClientThemeColors colors) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_rounded, size: 36, color: colors.textTertiary),
          const SizedBox(height: 8),
          Text(
            'No completed sets for this exercise in ${data.period.label}',
            style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete a session to track your 1RM progression',
            style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSessionState(
    ClientThemeColors colors,
    Exercise1RMTrendPoint point,
  ) {
    final dateStr = DateFormat('MMM d, yyyy').format(point.date);
    return Container(
      height: 150,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Initial Baseline Recorded',
            style: GoogleFonts.poppins(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${point.estimated1RM.toStringAsFixed(1)} kg',
            style: GoogleFonts.poppins(
              color: colors.primary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${point.weight % 1 == 0 ? point.weight.toInt() : point.weight} kg × ${point.reps} reps on $dateStr',
            style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            'Log another session to view your 1RM trend graph',
            style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
    ClientThemeColors colors,
    List<Exercise1RMTrendPoint> points,
  ) {
    final spots = <FlSpot>[];
    double min1RM = double.infinity;
    double max1RM = -double.infinity;

    for (int i = 0; i < points.length; i++) {
      final val = points[i].estimated1RM;
      spots.add(FlSpot(i.toDouble(), val));
      min1RM = min(min1RM, val);
      max1RM = max(max1RM, val);
    }

    final double minY = max(0.0, (min1RM - 5.0).floorToDouble());
    final double maxY = (max1RM + 5.0).ceilToDouble();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.border.withOpacity(0.35),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}kg',
                    style: GoogleFonts.poppins(
                      color: colors.textTertiary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < points.length) {
                    final dt = points[idx].date;
                    return Text(
                      DateFormat('M/d').format(dt),
                      style: GoogleFonts.poppins(
                        color: colors.textTertiary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: colors.primary,
              barWidth: 2.8,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: colors.surfaceCard,
                  strokeWidth: 2.2,
                  strokeColor: colors.primary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.primary.withOpacity(0.28),
                    colors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.spotIndex;
                  final pt = points[idx];
                  final date = DateFormat('MMM d').format(pt.date);
                  return LineTooltipItem(
                    '$date: ${pt.estimated1RM.toStringAsFixed(1)} kg\n(${pt.weight.toInt()}kg × ${pt.reps}r)',
                    GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
