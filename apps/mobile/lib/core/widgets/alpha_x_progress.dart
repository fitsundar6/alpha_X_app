import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';

/// Minimal Linear Progress Bar in Red Accent
class AlphaXLinearProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? progressColor;
  final Color? trackColor;

  const AlphaXLinearProgress({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.progressColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: height,
        backgroundColor: trackColor ?? AlphaXColors.surfaceElevated,
        valueColor: AlwaysStoppedAnimation<Color>(
          progressColor ?? AlphaXColors.redAccent,
        ),
      ),
    );
  }
}

/// Minimal Arc / Circular Progress Ring for Steps & Daily Targets
class AlphaXArcProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Widget? centerChild;
  final Color? progressColor;
  final Color? trackColor;

  const AlphaXArcProgress({
    super.key,
    required this.progress,
    this.size = 140.0,
    this.strokeWidth = 9.0,
    this.centerChild,
    this.progressColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ArcProgressPainter(
              progress: clamped,
              strokeWidth: strokeWidth,
              progressColor: progressColor ?? AlphaXColors.redAccent,
              trackColor: trackColor ?? AlphaXColors.surfaceElevated,
            ),
          ),
          if (centerChild != null) ...[centerChild!],
        ],
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
