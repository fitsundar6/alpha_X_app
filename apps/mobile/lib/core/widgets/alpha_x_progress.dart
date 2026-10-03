import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Athletic Premium Linear Progress Bar with Smooth 0 -> Value Animation
class AlphaXLinearProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? progressColor;
  final Color? trackColor;
  final Duration duration;

  const AlphaXLinearProgress({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.progressColor,
    this.trackColor,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveProgressColor = progressColor ?? (isDark ? AppColors.primary : AppColors.lightPrimary);
    final effectiveTrackColor = trackColor ?? (isDark ? AppColors.surfaceElevated : AppColors.lightBorder);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: clamped),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: height,
            backgroundColor: effectiveTrackColor,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveProgressColor),
          ),
        );
      },
    );
  }
}

/// Athletic Premium Circular Progress Ring for Steps, Macros & Workouts
/// Animates 0 -> value smoothly with electric lime accent.
class AlphaXArcProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Widget? centerChild;
  final Color? progressColor;
  final Color? trackColor;
  final Duration duration;

  const AlphaXArcProgress({
    super.key,
    required this.progress,
    this.size = 140.0,
    this.strokeWidth = 9.0,
    this.centerChild,
    this.progressColor,
    this.trackColor,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveProgressColor = progressColor ?? (isDark ? AppColors.primary : AppColors.lightPrimary);
    final effectiveTrackColor = trackColor ?? (isDark ? AppColors.surfaceElevated : AppColors.lightBorder);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: clamped),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _ArcProgressPainter(
                  progress: animatedValue,
                  strokeWidth: strokeWidth,
                  progressColor: effectiveProgressColor,
                  trackColor: effectiveTrackColor,
                ),
              ),
              ?centerChild,
            ],
          );
        },
      ),
    );
  }
}

class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _ArcProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    // Active arc starting from top (-pi / 2)
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
