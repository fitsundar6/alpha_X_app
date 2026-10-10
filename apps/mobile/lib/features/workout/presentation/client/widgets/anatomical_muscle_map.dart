import 'package:flutter/material.dart';

/// Production-ready anatomical vector illustration showing front and back body
/// silhouettes with highlighted muscle groups matching the Alpha X Gym reference model.
class AnatomicalMuscleMapWidget extends StatelessWidget {
  final Set<String> trainedMuscles;
  final Color highlightColor;
  final Color secondaryHighlightColor;
  final Color silhouetteColor;
  final Color outlineColor;
  final double? height;

  const AnatomicalMuscleMapWidget({
    super.key,
    required this.trainedMuscles,
    this.highlightColor = const Color(0xFFFF9500), // Vibrant amber-orange matching reference
    this.secondaryHighlightColor = const Color(0xFFFFA000), // Amber
    this.silhouetteColor = const Color(0xFF2C2E32), // Dark charcoal base matching reference
    this.outlineColor = const Color(0xFF141517), // Deep anatomical striation & separation lines
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final targetHeight = height ??
            (constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 220.0);

        return CustomPaint(
          size: Size(width, targetHeight),
          painter: _AnatomicalBodyPainter(
            trainedMuscles: trainedMuscles.map((m) => m.toLowerCase().trim()).toSet(),
            highlightColor: highlightColor,
            secondaryHighlightColor: secondaryHighlightColor,
            silhouetteColor: silhouetteColor,
            outlineColor: outlineColor,
          ),
        );
      },
    );
  }
}

class _AnatomicalBodyPainter extends CustomPainter {
  final Set<String> trainedMuscles;
  final Color highlightColor;
  final Color secondaryHighlightColor;
  final Color silhouetteColor;
  final Color outlineColor;

  _AnatomicalBodyPainter({
    required this.trainedMuscles,
    required this.highlightColor,
    required this.secondaryHighlightColor,
    required this.silhouetteColor,
    required this.outlineColor,
  });

  bool _isTrained(List<String> keywords) {
    if (trainedMuscles.contains('full body')) return true;
    for (final kw in keywords) {
      final lowerKw = kw.toLowerCase();
      for (final tm in trainedMuscles) {
        if (tm == lowerKw || tm.contains(lowerKw) || lowerKw.contains(tm)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double frontCenterX = size.width * 0.28;
    final double backCenterX = size.width * 0.72;
    final double figureH = size.height * 0.94;
    final double figureW = figureH * 0.44;
    final double strokeScale = (figureH / 220.0).clamp(0.8, 1.4);

    // Paints
    final basePaint = Paint()
      ..color = silhouetteColor
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 * strokeScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fineLinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * strokeScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // -------------------------------------------------------------
    // 1. DRAW FRONT BODY VIEW
    // -------------------------------------------------------------
    _paintFrontView(
      canvas: canvas,
      cx: frontCenterX,
      cy: size.height * 0.5,
      figureW: figureW,
      figureH: figureH,
      basePaint: basePaint,
      highlightPaint: highlightPaint,
      linePaint: linePaint,
      fineLinePaint: fineLinePaint,
    );

    // -------------------------------------------------------------
    // 2. DRAW BACK BODY VIEW
    // -------------------------------------------------------------
    _paintBackView(
      canvas: canvas,
      cx: backCenterX,
      cy: size.height * 0.5,
      figureW: figureW,
      figureH: figureH,
      basePaint: basePaint,
      highlightPaint: highlightPaint,
      linePaint: linePaint,
      fineLinePaint: fineLinePaint,
    );
  }

  // ===========================================================================
  // FRONT VIEW IMPLEMENTATION
  // ===========================================================================
  void _paintFrontView({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double figureW,
    required double figureH,
    required Paint basePaint,
    required Paint highlightPaint,
    required Paint linePaint,
    required Paint fineLinePaint,
  }) {
    Offset p(double nx, double ny) =>
        Offset(cx + nx * figureW, cy - figureH * 0.5 + ny * figureH);

    // --- 1. Base Silhouette Fill ---
    final bodyPath = Path();

    // Start at neck top left
    bodyPath.moveTo(p(-0.065, 0.115).dx, p(-0.065, 0.115).dy);
    // Left trapezius slope to shoulder
    bodyPath.lineTo(p(-0.07, 0.14).dx, p(-0.07, 0.14).dy);
    bodyPath.quadraticBezierTo(p(-0.16, 0.155).dx, p(-0.16, 0.155).dy, p(-0.28, 0.17).dx, p(-0.28, 0.17).dy);
    // Left deltoid cap
    bodyPath.quadraticBezierTo(p(-0.38, 0.20).dx, p(-0.38, 0.20).dy, p(-0.37, 0.265).dx, p(-0.37, 0.265).dy);
    // Left upper arm
    bodyPath.quadraticBezierTo(p(-0.43, 0.32).dx, p(-0.43, 0.32).dy, p(-0.46, 0.375).dx, p(-0.46, 0.375).dy);
    // Left forearm
    bodyPath.quadraticBezierTo(p(-0.55, 0.44).dx, p(-0.55, 0.44).dy, p(-0.60, 0.535).dx, p(-0.60, 0.535).dy);
    // Left hand & thumb
    bodyPath.quadraticBezierTo(p(-0.64, 0.55).dx, p(-0.64, 0.55).dy, p(-0.69, 0.57).dx, p(-0.69, 0.57).dy);
    bodyPath.lineTo(p(-0.68, 0.585).dx, p(-0.68, 0.585).dy);
    bodyPath.lineTo(p(-0.63, 0.585).dx, p(-0.63, 0.585).dy);
    // Fingers
    bodyPath.lineTo(p(-0.64, 0.64).dx, p(-0.64, 0.64).dy);
    bodyPath.lineTo(p(-0.58, 0.62).dx, p(-0.58, 0.62).dy);
    bodyPath.lineTo(p(-0.54, 0.57).dx, p(-0.54, 0.57).dy);
    // Inner forearm
    bodyPath.quadraticBezierTo(p(-0.45, 0.47).dx, p(-0.45, 0.47).dy, p(-0.36, 0.38).dx, p(-0.36, 0.38).dy);
    // Inner upper arm to axilla
    bodyPath.quadraticBezierTo(p(-0.30, 0.32).dx, p(-0.30, 0.32).dy, p(-0.24, 0.265).dx, p(-0.24, 0.265).dy);
    // Torso down to waist
    bodyPath.quadraticBezierTo(p(-0.21, 0.32).dx, p(-0.21, 0.32).dy, p(-0.18, 0.385).dx, p(-0.18, 0.385).dy);
    // Waist to hip
    bodyPath.quadraticBezierTo(p(-0.20, 0.44).dx, p(-0.20, 0.44).dy, p(-0.22, 0.505).dx, p(-0.22, 0.505).dy);
    // Left thigh outer sweep (vastus lateralis)
    bodyPath.quadraticBezierTo(p(-0.23, 0.58).dx, p(-0.23, 0.58).dy, p(-0.155, 0.69).dx, p(-0.155, 0.69).dy);
    // Left knee outer
    bodyPath.lineTo(p(-0.15, 0.735).dx, p(-0.15, 0.735).dy);
    // Left calf outer sweep (gastrocnemius)
    bodyPath.quadraticBezierTo(p(-0.17, 0.79).dx, p(-0.17, 0.79).dy, p(-0.115, 0.93).dx, p(-0.115, 0.93).dy);
    // Left ankle & foot
    bodyPath.quadraticBezierTo(p(-0.13, 0.96).dx, p(-0.13, 0.96).dy, p(-0.11, 0.98).dx, p(-0.11, 0.98).dy);
    bodyPath.lineTo(p(-0.05, 0.98).dx, p(-0.05, 0.98).dy);
    bodyPath.lineTo(p(-0.065, 0.93).dx, p(-0.065, 0.93).dy);
    // Left calf inner
    bodyPath.quadraticBezierTo(p(-0.03, 0.81).dx, p(-0.03, 0.81).dy, p(-0.045, 0.735).dx, p(-0.045, 0.735).dy);
    bodyPath.lineTo(p(-0.045, 0.69).dx, p(-0.045, 0.69).dy);
    // Left thigh inner (vastus medialis)
    bodyPath.quadraticBezierTo(p(-0.03, 0.64).dx, p(-0.03, 0.64).dy, p(-0.015, 0.515).dx, p(-0.015, 0.515).dy);
    // Cleft at groin
    bodyPath.lineTo(p(0.0, 0.51).dx, p(0.0, 0.51).dy);

    // --- Right Leg (Mirrored) ---
    bodyPath.lineTo(p(0.015, 0.515).dx, p(0.015, 0.515).dy);
    bodyPath.quadraticBezierTo(p(0.03, 0.64).dx, p(0.03, 0.64).dy, p(0.045, 0.69).dx, p(0.045, 0.69).dy);
    bodyPath.lineTo(p(0.045, 0.735).dx, p(0.045, 0.735).dy);
    bodyPath.quadraticBezierTo(p(0.03, 0.81).dx, p(0.03, 0.81).dy, p(0.065, 0.93).dx, p(0.065, 0.93).dy);
    bodyPath.lineTo(p(0.05, 0.98).dx, p(0.05, 0.98).dy);
    bodyPath.lineTo(p(0.11, 0.98).dx, p(0.11, 0.98).dy);
    bodyPath.quadraticBezierTo(p(0.13, 0.96).dx, p(0.13, 0.96).dy, p(0.115, 0.93).dx, p(0.115, 0.93).dy);
    bodyPath.quadraticBezierTo(p(0.17, 0.79).dx, p(0.17, 0.79).dy, p(0.15, 0.735).dx, p(0.15, 0.735).dy);
    bodyPath.lineTo(p(0.155, 0.69).dx, p(0.155, 0.69).dy);
    bodyPath.quadraticBezierTo(p(0.23, 0.58).dx, p(0.23, 0.58).dy, p(0.22, 0.505).dx, p(0.22, 0.505).dy);

    // --- Right Torso & Arm (Mirrored) ---
    bodyPath.quadraticBezierTo(p(0.20, 0.44).dx, p(0.20, 0.44).dy, p(0.18, 0.385).dx, p(0.18, 0.385).dy);
    bodyPath.quadraticBezierTo(p(0.21, 0.32).dx, p(0.21, 0.32).dy, p(0.24, 0.265).dx, p(0.24, 0.265).dy);
    bodyPath.quadraticBezierTo(p(0.30, 0.32).dx, p(0.30, 0.32).dy, p(0.36, 0.38).dx, p(0.36, 0.38).dy);
    bodyPath.quadraticBezierTo(p(0.45, 0.47).dx, p(0.45, 0.47).dy, p(0.54, 0.57).dx, p(0.54, 0.57).dy);
    bodyPath.lineTo(p(0.58, 0.62).dx, p(0.58, 0.62).dy);
    bodyPath.lineTo(p(0.64, 0.64).dx, p(0.64, 0.64).dy);
    bodyPath.lineTo(p(0.63, 0.585).dx, p(0.63, 0.585).dy);
    bodyPath.lineTo(p(0.68, 0.585).dx, p(0.68, 0.585).dy);
    bodyPath.quadraticBezierTo(p(0.69, 0.57).dx, p(0.69, 0.57).dy, p(0.64, 0.55).dx, p(0.64, 0.55).dy);
    bodyPath.quadraticBezierTo(p(0.60, 0.535).dx, p(0.60, 0.535).dy, p(0.55, 0.44).dx, p(0.55, 0.44).dy);
    bodyPath.quadraticBezierTo(p(0.46, 0.375).dx, p(0.46, 0.375).dy, p(0.43, 0.32).dx, p(0.43, 0.32).dy);
    bodyPath.quadraticBezierTo(p(0.37, 0.265).dx, p(0.37, 0.265).dy, p(0.38, 0.20).dx, p(0.38, 0.20).dy);
    bodyPath.quadraticBezierTo(p(0.28, 0.17).dx, p(0.28, 0.17).dy, p(0.16, 0.155).dx, p(0.16, 0.155).dy);
    bodyPath.lineTo(p(0.07, 0.14).dx, p(0.07, 0.14).dy);
    bodyPath.lineTo(p(0.065, 0.115).dx, p(0.065, 0.115).dy);
    bodyPath.close();

    // Head oval
    final headRect = Rect.fromCenter(
      center: p(0.0, 0.065),
      width: figureW * 0.22,
      height: figureH * 0.105,
    );

    // Draw base body silhouette
    canvas.drawOval(headRect, basePaint);
    canvas.drawPath(bodyPath, basePaint);

    // --- 2. Front Muscle Highlights ---

    // A. CHEST (Pectoralis Major)
    if (_isTrained(['chest', 'pectoral', 'pecs'])) {
      for (final sign in [-1.0, 1.0]) {
        final pec = Path();
        pec.moveTo(p(sign * 0.015, 0.175).dx, p(sign * 0.015, 0.175).dy);
        pec.lineTo(p(sign * 0.17, 0.175).dx, p(sign * 0.17, 0.175).dy);
        pec.quadraticBezierTo(p(sign * 0.23, 0.20).dx, p(sign * 0.23, 0.20).dy, p(sign * 0.23, 0.26).dx, p(sign * 0.23, 0.26).dy);
        pec.quadraticBezierTo(p(sign * 0.13, 0.29).dx, p(sign * 0.13, 0.29).dy, p(sign * 0.015, 0.285).dx, p(sign * 0.015, 0.285).dy);
        pec.close();
        canvas.drawPath(pec, highlightPaint);
      }
    }

    // B. SHOULDERS (Front Deltoids)
    if (_isTrained(['shoulder', 'shoulders', 'delt', 'delts', 'deltoid', 'front delt'])) {
      for (final sign in [-1.0, 1.0]) {
        final delt = Path();
        delt.moveTo(p(sign * 0.24, 0.17).dx, p(sign * 0.24, 0.17).dy);
        delt.quadraticBezierTo(p(sign * 0.37, 0.19).dx, p(sign * 0.37, 0.19).dy, p(sign * 0.37, 0.23).dx, p(sign * 0.37, 0.23).dy);
        delt.quadraticBezierTo(p(sign * 0.35, 0.27).dx, p(sign * 0.35, 0.27).dy, p(sign * 0.27, 0.275).dx, p(sign * 0.27, 0.275).dy);
        delt.quadraticBezierTo(p(sign * 0.23, 0.23).dx, p(sign * 0.23, 0.23).dy, p(sign * 0.24, 0.17).dx, p(sign * 0.24, 0.17).dy);
        delt.close();
        canvas.drawPath(delt, highlightPaint);
      }
    }

    // C. BICEPS
    if (_isTrained(['bicep', 'biceps', 'arms'])) {
      for (final sign in [-1.0, 1.0]) {
        final bicep = Path();
        bicep.moveTo(p(sign * 0.26, 0.275).dx, p(sign * 0.26, 0.275).dy);
        bicep.lineTo(p(sign * 0.36, 0.275).dx, p(sign * 0.36, 0.275).dy);
        bicep.quadraticBezierTo(p(sign * 0.43, 0.33).dx, p(sign * 0.43, 0.33).dy, p(sign * 0.42, 0.375).dx, p(sign * 0.42, 0.375).dy);
        bicep.lineTo(p(sign * 0.34, 0.375).dx, p(sign * 0.34, 0.375).dy);
        bicep.quadraticBezierTo(p(sign * 0.29, 0.33).dx, p(sign * 0.29, 0.33).dy, p(sign * 0.26, 0.275).dx, p(sign * 0.26, 0.275).dy);
        bicep.close();
        canvas.drawPath(bicep, highlightPaint);
      }
    }

    // D. FOREARMS (Front)
    if (_isTrained(['forearm', 'forearms', 'grip'])) {
      for (final sign in [-1.0, 1.0]) {
        final forearm = Path();
        forearm.moveTo(p(sign * 0.34, 0.38).dx, p(sign * 0.34, 0.38).dy);
        forearm.lineTo(p(sign * 0.43, 0.38).dx, p(sign * 0.43, 0.38).dy);
        forearm.quadraticBezierTo(p(sign * 0.52, 0.44).dx, p(sign * 0.52, 0.44).dy, p(sign * 0.57, 0.53).dx, p(sign * 0.57, 0.53).dy);
        forearm.lineTo(p(sign * 0.51, 0.53).dx, p(sign * 0.51, 0.53).dy);
        forearm.quadraticBezierTo(p(sign * 0.42, 0.45).dx, p(sign * 0.42, 0.45).dy, p(sign * 0.34, 0.38).dx, p(sign * 0.34, 0.38).dy);
        forearm.close();
        canvas.drawPath(forearm, highlightPaint);
      }
    }

    // E. ABS & CORE (6-pack rectus abdominis & obliques)
    if (_isTrained(['abs', 'abdominals', 'core', 'obliques'])) {
      // 3 paired tiers of ab packs
      final tiers = [
        [0.295, 0.330],
        [0.338, 0.375],
        [0.383, 0.435],
      ];
      for (final tier in tiers) {
        for (final sign in [-1.0, 1.0]) {
          final x1 = sign < 0 ? -0.078 : 0.012;
          final x2 = sign < 0 ? -0.012 : 0.078;
          final rrect = RRect.fromRectAndRadius(
            Rect.fromLTRB(p(x1, tier[0]).dx, p(x1, tier[0]).dy, p(x2, tier[1]).dx, p(x2, tier[1]).dy),
            const Radius.circular(2.5),
          );
          canvas.drawRRect(rrect, highlightPaint);
        }
      }
      // Oblique flanks
      for (final sign in [-1.0, 1.0]) {
        final ob = Path();
        ob.moveTo(p(sign * 0.10, 0.32).dx, p(sign * 0.10, 0.32).dy);
        ob.lineTo(p(sign * 0.18, 0.34).dx, p(sign * 0.18, 0.34).dy);
        ob.quadraticBezierTo(p(sign * 0.17, 0.40).dx, p(sign * 0.17, 0.40).dy, p(sign * 0.18, 0.44).dx, p(sign * 0.18, 0.44).dy);
        ob.lineTo(p(sign * 0.10, 0.44).dx, p(sign * 0.10, 0.44).dy);
        ob.close();
        canvas.drawPath(ob, highlightPaint);
      }
    }

    // F. QUADS (Quadriceps Femoris — Matching Reference 3-Part Shapes!)
    if (_isTrained(['quad', 'quads', 'quadriceps', 'thigh', 'thighs', 'legs'])) {
      for (final sign in [-1.0, 1.0]) {
        // 1. Rectus Femoris (Center Teardrop)
        final rectus = Path();
        rectus.moveTo(p(sign * 0.11, 0.515).dx, p(sign * 0.11, 0.515).dy);
        rectus.quadraticBezierTo(p(sign * 0.145, 0.57).dx, p(sign * 0.145, 0.57).dy, p(sign * 0.125, 0.65).dx, p(sign * 0.125, 0.65).dy);
        rectus.lineTo(p(sign * 0.09, 0.675).dx, p(sign * 0.09, 0.675).dy);
        rectus.lineTo(p(sign * 0.07, 0.65).dx, p(sign * 0.07, 0.65).dy);
        rectus.quadraticBezierTo(p(sign * 0.075, 0.57).dx, p(sign * 0.075, 0.57).dy, p(sign * 0.11, 0.515).dx, p(sign * 0.11, 0.515).dy);
        rectus.close();
        canvas.drawPath(rectus, highlightPaint);

        // 2. Vastus Lateralis (Outer Sweep)
        final vastusLat = Path();
        vastusLat.moveTo(p(sign * 0.13, 0.515).dx, p(sign * 0.13, 0.515).dy);
        vastusLat.quadraticBezierTo(p(sign * 0.22, 0.56).dx, p(sign * 0.22, 0.56).dy, p(sign * 0.155, 0.685).dx, p(sign * 0.155, 0.685).dy);
        vastusLat.lineTo(p(sign * 0.135, 0.685).dx, p(sign * 0.135, 0.685).dy);
        vastusLat.quadraticBezierTo(p(sign * 0.155, 0.60).dx, p(sign * 0.155, 0.60).dy, p(sign * 0.13, 0.515).dx, p(sign * 0.13, 0.515).dy);
        vastusLat.close();
        canvas.drawPath(vastusLat, highlightPaint);

        // 3. Vastus Medialis (Inner Teardrop above Knee)
        final vastusMed = Path();
        vastusMed.moveTo(p(sign * 0.07, 0.59).dx, p(sign * 0.07, 0.59).dy);
        vastusMed.quadraticBezierTo(p(sign * 0.03, 0.64).dx, p(sign * 0.03, 0.64).dy, p(sign * 0.05, 0.685).dx, p(sign * 0.05, 0.685).dy);
        vastusMed.lineTo(p(sign * 0.075, 0.68).dx, p(sign * 0.075, 0.68).dy);
        vastusMed.quadraticBezierTo(p(sign * 0.065, 0.63).dx, p(sign * 0.065, 0.63).dy, p(sign * 0.07, 0.59).dx, p(sign * 0.07, 0.59).dy);
        vastusMed.close();
        canvas.drawPath(vastusMed, highlightPaint);
      }
    }

    // G. CALVES / SHINS (Front)
    if (_isTrained(['calf', 'calves', 'tibialis'])) {
      for (final sign in [-1.0, 1.0]) {
        final shin = Path();
        shin.moveTo(p(sign * 0.10, 0.745).dx, p(sign * 0.10, 0.745).dy);
        shin.quadraticBezierTo(p(sign * 0.16, 0.80).dx, p(sign * 0.16, 0.80).dy, p(sign * 0.115, 0.90).dx, p(sign * 0.115, 0.90).dy);
        shin.lineTo(p(sign * 0.08, 0.90).dx, p(sign * 0.08, 0.90).dy);
        shin.quadraticBezierTo(p(sign * 0.04, 0.80).dx, p(sign * 0.04, 0.80).dy, p(sign * 0.085, 0.745).dx, p(sign * 0.085, 0.745).dy);
        shin.close();
        canvas.drawPath(shin, highlightPaint);
      }
    }

    // --- 3. Front Anatomical Contours & Striations (Dark Crisp Lines) ---
    // Outer perimeter line
    canvas.drawOval(headRect, linePaint);
    canvas.drawPath(bodyPath, linePaint);

    // Neck sternocleidomastoid lines
    canvas.drawLine(p(-0.04, 0.115), p(-0.015, 0.165), fineLinePaint);
    canvas.drawLine(p(0.04, 0.115), p(0.015, 0.165), fineLinePaint);

    // Clavicles (collarbones)
    canvas.drawLine(p(-0.17, 0.175), p(-0.015, 0.168), linePaint);
    canvas.drawLine(p(0.17, 0.175), p(0.015, 0.168), linePaint);

    // Sternum & Pectoral division
    canvas.drawLine(p(0.0, 0.168), p(0.0, 0.285), linePaint);
    // Lower pec boundaries
    canvas.drawLine(p(-0.015, 0.285), p(-0.23, 0.26), linePaint);
    canvas.drawLine(p(0.015, 0.285), p(0.23, 0.26), linePaint);
    // Deltopectoral groove
    canvas.drawLine(p(-0.17, 0.175), p(-0.23, 0.26), linePaint);
    canvas.drawLine(p(0.17, 0.175), p(0.23, 0.26), linePaint);

    // Epigastric ribcage arch
    final ribArch = Path();
    ribArch.moveTo(p(-0.10, 0.33).dx, p(-0.10, 0.33).dy);
    ribArch.quadraticBezierTo(p(0.0, 0.29).dx, p(0.0, 0.29).dy, p(0.10, 0.33).dx, p(0.10, 0.33).dy);
    canvas.drawPath(ribArch, linePaint);

    // Linea alba (ab center vertical line)
    canvas.drawLine(p(0.0, 0.29), p(0.0, 0.44), linePaint);

    // Horizontal ab division creases
    canvas.drawLine(p(-0.08, 0.334), p(0.08, 0.334), linePaint);
    canvas.drawLine(p(-0.08, 0.379), p(0.08, 0.379), linePaint);

    // Serratus anterior tick marks
    for (int i = 0; i < 3; i++) {
      final yOffset = 0.31 + i * 0.025;
      canvas.drawLine(p(-0.17, yOffset), p(-0.13, yOffset + 0.015), fineLinePaint);
      canvas.drawLine(p(0.17, yOffset), p(0.13, yOffset + 0.015), fineLinePaint);
    }

    // Inguinal ligament V-crease
    canvas.drawLine(p(-0.16, 0.47), p(0.0, 0.51), linePaint);
    canvas.drawLine(p(0.16, 0.47), p(0.0, 0.51), linePaint);

    // Arm creases (Bicep/Tricep & Elbow)
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(p(sign * 0.27, 0.275), p(sign * 0.36, 0.275), fineLinePaint);
      canvas.drawLine(p(sign * 0.34, 0.375), p(sign * 0.43, 0.375), fineLinePaint);
      // Forearm muscle contour
      canvas.drawLine(p(sign * 0.39, 0.38), p(sign * 0.53, 0.52), fineLinePaint);
    }

    // Quad Separation Grooves (Matching the reference dark lines!)
    for (final sign in [-1.0, 1.0]) {
      // Groove separating Vastus Lateralis from Rectus Femoris
      final latGroove = Path();
      latGroove.moveTo(p(sign * 0.13, 0.515).dx, p(sign * 0.13, 0.515).dy);
      latGroove.quadraticBezierTo(
        p(sign * 0.155, 0.60).dx,
        p(sign * 0.155, 0.60).dy,
        p(sign * 0.135, 0.685).dx,
        p(sign * 0.135, 0.685).dy,
      );
      canvas.drawPath(latGroove, linePaint);

      // Groove separating Vastus Medialis from Rectus Femoris
      final medGroove = Path();
      medGroove.moveTo(p(sign * 0.07, 0.59).dx, p(sign * 0.07, 0.59).dy);
      medGroove.quadraticBezierTo(
        p(sign * 0.065, 0.63).dx,
        p(sign * 0.065, 0.63).dy,
        p(sign * 0.075, 0.68).dx,
        p(sign * 0.075, 0.68).dy,
      );
      canvas.drawPath(medGroove, linePaint);

      // Suprapatellar arch above knee
      final kneeArch = Path();
      kneeArch.moveTo(p(sign * 0.14, 0.688).dx, p(sign * 0.14, 0.688).dy);
      kneeArch.quadraticBezierTo(
        p(sign * 0.09, 0.675).dx,
        p(sign * 0.09, 0.675).dy,
        p(sign * 0.05, 0.688).dx,
        p(sign * 0.05, 0.688).dy,
      );
      canvas.drawPath(kneeArch, linePaint);

      // Patella (kneecap)
      canvas.drawOval(
        Rect.fromCenter(center: p(sign * 0.09, 0.715), width: figureW * 0.05, height: figureH * 0.03),
        fineLinePaint,
      );
      // Patellar tendon
      canvas.drawLine(p(sign * 0.09, 0.73), p(sign * 0.09, 0.75), linePaint);

      // Shin bone line (anterior border of tibia)
      canvas.drawLine(p(sign * 0.09, 0.75), p(sign * 0.085, 0.91), fineLinePaint);
      // Calf outer groove
      canvas.drawLine(p(sign * 0.11, 0.77), p(sign * 0.10, 0.88), fineLinePaint);
    }
  }

  // ===========================================================================
  // BACK VIEW IMPLEMENTATION
  // ===========================================================================
  void _paintBackView({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double figureW,
    required double figureH,
    required Paint basePaint,
    required Paint highlightPaint,
    required Paint linePaint,
    required Paint fineLinePaint,
  }) {
    Offset p(double nx, double ny) =>
        Offset(cx + nx * figureW, cy - figureH * 0.5 + ny * figureH);

    // --- 1. Base Silhouette Fill ---
    final bodyPath = Path();

    // Start at neck top left
    bodyPath.moveTo(p(-0.065, 0.115).dx, p(-0.065, 0.115).dy);
    bodyPath.lineTo(p(-0.07, 0.14).dx, p(-0.07, 0.14).dy);
    bodyPath.quadraticBezierTo(p(-0.16, 0.155).dx, p(-0.16, 0.155).dy, p(-0.28, 0.17).dx, p(-0.28, 0.17).dy);
    // Rear deltoid & arms
    bodyPath.quadraticBezierTo(p(-0.38, 0.20).dx, p(-0.38, 0.20).dy, p(-0.37, 0.265).dx, p(-0.37, 0.265).dy);
    bodyPath.quadraticBezierTo(p(-0.43, 0.32).dx, p(-0.43, 0.32).dy, p(-0.46, 0.375).dx, p(-0.46, 0.375).dy);
    bodyPath.quadraticBezierTo(p(-0.55, 0.44).dx, p(-0.55, 0.44).dy, p(-0.60, 0.535).dx, p(-0.60, 0.535).dy);
    bodyPath.quadraticBezierTo(p(-0.64, 0.55).dx, p(-0.64, 0.55).dy, p(-0.69, 0.57).dx, p(-0.69, 0.57).dy);
    bodyPath.lineTo(p(-0.68, 0.585).dx, p(-0.68, 0.585).dy);
    bodyPath.lineTo(p(-0.63, 0.585).dx, p(-0.63, 0.585).dy);
    bodyPath.lineTo(p(-0.64, 0.64).dx, p(-0.64, 0.64).dy);
    bodyPath.lineTo(p(-0.58, 0.62).dx, p(-0.58, 0.62).dy);
    bodyPath.lineTo(p(-0.54, 0.57).dx, p(-0.54, 0.57).dy);
    bodyPath.quadraticBezierTo(p(-0.45, 0.47).dx, p(-0.45, 0.47).dy, p(-0.36, 0.38).dx, p(-0.36, 0.38).dy);
    bodyPath.quadraticBezierTo(p(-0.30, 0.32).dx, p(-0.30, 0.32).dy, p(-0.24, 0.265).dx, p(-0.24, 0.265).dy);

    // Lats V-taper to waist
    bodyPath.quadraticBezierTo(p(-0.21, 0.32).dx, p(-0.21, 0.32).dy, p(-0.18, 0.385).dx, p(-0.18, 0.385).dy);
    // Waist to outer glute flare
    bodyPath.quadraticBezierTo(p(-0.20, 0.44).dx, p(-0.20, 0.44).dy, p(-0.22, 0.505).dx, p(-0.22, 0.505).dy);
    // Gluteal fold outer
    bodyPath.quadraticBezierTo(p(-0.225, 0.56).dx, p(-0.225, 0.56).dy, p(-0.205, 0.59).dx, p(-0.205, 0.59).dy);
    // Left hamstring outer
    bodyPath.quadraticBezierTo(p(-0.20, 0.64).dx, p(-0.20, 0.64).dy, p(-0.155, 0.69).dx, p(-0.155, 0.69).dy);
    // Back of knee (popliteal fossa)
    bodyPath.lineTo(p(-0.15, 0.735).dx, p(-0.15, 0.735).dy);
    // Left calf rear
    bodyPath.quadraticBezierTo(p(-0.17, 0.79).dx, p(-0.17, 0.79).dy, p(-0.115, 0.93).dx, p(-0.115, 0.93).dy);
    // Heel & foot
    bodyPath.quadraticBezierTo(p(-0.13, 0.96).dx, p(-0.13, 0.96).dy, p(-0.11, 0.98).dx, p(-0.11, 0.98).dy);
    bodyPath.lineTo(p(-0.05, 0.98).dx, p(-0.05, 0.98).dy);
    bodyPath.lineTo(p(-0.065, 0.93).dx, p(-0.065, 0.93).dy);
    bodyPath.quadraticBezierTo(p(-0.03, 0.81).dx, p(-0.03, 0.81).dy, p(-0.045, 0.735).dx, p(-0.045, 0.735).dy);
    bodyPath.lineTo(p(-0.045, 0.69).dx, p(-0.045, 0.69).dy);
    // Left hamstring inner
    bodyPath.quadraticBezierTo(p(-0.03, 0.64).dx, p(-0.03, 0.64).dy, p(-0.015, 0.595).dx, p(-0.015, 0.595).dy);
    // Gluteal cleft
    bodyPath.lineTo(p(0.0, 0.59).dx, p(0.0, 0.59).dy);

    // --- Right Leg (Mirrored) ---
    bodyPath.lineTo(p(0.015, 0.595).dx, p(0.015, 0.595).dy);
    bodyPath.quadraticBezierTo(p(0.03, 0.64).dx, p(0.03, 0.64).dy, p(0.045, 0.69).dx, p(0.045, 0.69).dy);
    bodyPath.lineTo(p(0.045, 0.735).dx, p(0.045, 0.735).dy);
    bodyPath.quadraticBezierTo(p(0.03, 0.81).dx, p(0.03, 0.81).dy, p(0.065, 0.93).dx, p(0.065, 0.93).dy);
    bodyPath.lineTo(p(0.05, 0.98).dx, p(0.05, 0.98).dy);
    bodyPath.lineTo(p(0.11, 0.98).dx, p(0.11, 0.98).dy);
    bodyPath.quadraticBezierTo(p(0.13, 0.96).dx, p(0.13, 0.96).dy, p(0.115, 0.93).dx, p(0.115, 0.93).dy);
    bodyPath.quadraticBezierTo(p(0.17, 0.79).dx, p(0.17, 0.79).dy, p(0.15, 0.735).dx, p(0.15, 0.735).dy);
    bodyPath.lineTo(p(0.155, 0.69).dx, p(0.155, 0.69).dy);
    bodyPath.quadraticBezierTo(p(0.20, 0.64).dx, p(0.20, 0.64).dy, p(0.205, 0.59).dx, p(0.205, 0.59).dy);
    bodyPath.quadraticBezierTo(p(0.225, 0.56).dx, p(0.225, 0.56).dy, p(0.22, 0.505).dx, p(0.22, 0.505).dy);

    // --- Right Torso & Arm (Mirrored) ---
    bodyPath.quadraticBezierTo(p(0.20, 0.44).dx, p(0.20, 0.44).dy, p(0.18, 0.385).dx, p(0.18, 0.385).dy);
    bodyPath.quadraticBezierTo(p(0.21, 0.32).dx, p(0.21, 0.32).dy, p(0.24, 0.265).dx, p(0.24, 0.265).dy);
    bodyPath.quadraticBezierTo(p(0.30, 0.32).dx, p(0.30, 0.32).dy, p(0.36, 0.38).dx, p(0.36, 0.38).dy);
    bodyPath.quadraticBezierTo(p(0.45, 0.47).dx, p(0.45, 0.47).dy, p(0.54, 0.57).dx, p(0.54, 0.57).dy);
    bodyPath.lineTo(p(0.58, 0.62).dx, p(0.58, 0.62).dy);
    bodyPath.lineTo(p(0.64, 0.64).dx, p(0.64, 0.64).dy);
    bodyPath.lineTo(p(0.63, 0.585).dx, p(0.63, 0.585).dy);
    bodyPath.lineTo(p(0.68, 0.585).dx, p(0.68, 0.585).dy);
    bodyPath.quadraticBezierTo(p(0.69, 0.57).dx, p(0.69, 0.57).dy, p(0.64, 0.55).dx, p(0.64, 0.55).dy);
    bodyPath.quadraticBezierTo(p(0.60, 0.535).dx, p(0.60, 0.535).dy, p(0.55, 0.44).dx, p(0.55, 0.44).dy);
    bodyPath.quadraticBezierTo(p(0.46, 0.375).dx, p(0.46, 0.375).dy, p(0.43, 0.32).dx, p(0.43, 0.32).dy);
    bodyPath.quadraticBezierTo(p(0.37, 0.265).dx, p(0.37, 0.265).dy, p(0.38, 0.20).dx, p(0.38, 0.20).dy);
    bodyPath.quadraticBezierTo(p(0.28, 0.17).dx, p(0.28, 0.17).dy, p(0.16, 0.155).dx, p(0.16, 0.155).dy);
    bodyPath.lineTo(p(0.07, 0.14).dx, p(0.07, 0.14).dy);
    bodyPath.lineTo(p(0.065, 0.115).dx, p(0.065, 0.115).dy);
    bodyPath.close();

    final headRect = Rect.fromCenter(
      center: p(0.0, 0.065),
      width: figureW * 0.22,
      height: figureH * 0.105,
    );

    // Draw base body silhouette
    canvas.drawOval(headRect, basePaint);
    canvas.drawPath(bodyPath, basePaint);

    // --- 2. Back Muscle Highlights ---

    // A. TRAPEZIUS (Kite / Diamond Shape)
    if (_isTrained(['trap', 'traps', 'trapezius', 'neck', 'upper back'])) {
      final traps = Path();
      traps.moveTo(p(0.0, 0.115).dx, p(0.0, 0.115).dy);
      traps.lineTo(p(-0.24, 0.17).dx, p(-0.24, 0.17).dy);
      traps.quadraticBezierTo(p(-0.10, 0.25).dx, p(-0.10, 0.25).dy, p(0.0, 0.35).dx, p(0.0, 0.35).dy);
      traps.quadraticBezierTo(p(0.10, 0.25).dx, p(0.10, 0.25).dy, p(0.24, 0.17).dx, p(0.24, 0.17).dy);
      traps.close();
      canvas.drawPath(traps, highlightPaint);
    }

    // B. REAR DELTOIDS
    if (_isTrained(['rear delt', 'shoulder', 'shoulders', 'delt', 'delts'])) {
      for (final sign in [-1.0, 1.0]) {
        final rDelt = Path();
        rDelt.moveTo(p(sign * 0.24, 0.17).dx, p(sign * 0.24, 0.17).dy);
        rDelt.quadraticBezierTo(p(sign * 0.37, 0.19).dx, p(sign * 0.37, 0.19).dy, p(sign * 0.37, 0.23).dx, p(sign * 0.37, 0.23).dy);
        rDelt.quadraticBezierTo(p(sign * 0.35, 0.27).dx, p(sign * 0.35, 0.27).dy, p(sign * 0.27, 0.275).dx, p(sign * 0.27, 0.275).dy);
        rDelt.close();
        canvas.drawPath(rDelt, highlightPaint);
      }
    }

    // C. LATS (Latissimus Dorsi & Rhomboids)
    if (_isTrained(['lat', 'lats', 'latissimus', 'back', 'middle back', 'lower back'])) {
      for (final sign in [-1.0, 1.0]) {
        final lat = Path();
        lat.moveTo(p(sign * 0.10, 0.25).dx, p(sign * 0.10, 0.25).dy);
        lat.lineTo(p(sign * 0.24, 0.265).dx, p(sign * 0.24, 0.265).dy);
        lat.quadraticBezierTo(p(sign * 0.21, 0.32).dx, p(sign * 0.21, 0.32).dy, p(sign * 0.175, 0.39).dx, p(sign * 0.175, 0.39).dy);
        lat.lineTo(p(sign * 0.02, 0.39).dx, p(sign * 0.02, 0.39).dy);
        lat.lineTo(p(sign * 0.02, 0.35).dx, p(sign * 0.02, 0.35).dy);
        lat.close();
        canvas.drawPath(lat, highlightPaint);
      }
    }

    // D. TRICEPS (Back of Arms)
    if (_isTrained(['tricep', 'triceps', 'arms'])) {
      for (final sign in [-1.0, 1.0]) {
        final tricep = Path();
        tricep.moveTo(p(sign * 0.26, 0.275).dx, p(sign * 0.26, 0.275).dy);
        tricep.lineTo(p(sign * 0.36, 0.275).dx, p(sign * 0.36, 0.275).dy);
        tricep.quadraticBezierTo(p(sign * 0.43, 0.33).dx, p(sign * 0.43, 0.33).dy, p(sign * 0.42, 0.375).dx, p(sign * 0.42, 0.375).dy);
        tricep.lineTo(p(sign * 0.34, 0.375).dx, p(sign * 0.34, 0.375).dy);
        tricep.quadraticBezierTo(p(sign * 0.29, 0.33).dx, p(sign * 0.29, 0.33).dy, p(sign * 0.26, 0.275).dx, p(sign * 0.26, 0.275).dy);
        tricep.close();
        canvas.drawPath(tricep, highlightPaint);
      }
    }

    // E. GLUTES (Gluteus Maximus — Matching Reference Rounded Heart/Butterfly Lobes!)
    if (_isTrained(['glute', 'glutes', 'gluteus', 'butt', 'hips', 'legs'])) {
      for (final sign in [-1.0, 1.0]) {
        final glute = Path();
        glute.moveTo(p(sign * 0.015, 0.47).dx, p(sign * 0.015, 0.47).dy);
        glute.quadraticBezierTo(p(sign * 0.10, 0.46).dx, p(sign * 0.10, 0.46).dy, p(sign * 0.18, 0.475).dx, p(sign * 0.18, 0.475).dy);
        glute.quadraticBezierTo(p(sign * 0.22, 0.52).dx, p(sign * 0.22, 0.52).dy, p(sign * 0.205, 0.58).dx, p(sign * 0.205, 0.58).dy);
        glute.quadraticBezierTo(p(sign * 0.10, 0.595).dx, p(sign * 0.10, 0.595).dy, p(sign * 0.015, 0.59).dx, p(sign * 0.015, 0.59).dy);
        glute.close();
        canvas.drawPath(glute, highlightPaint);
      }
    }

    // F. HAMSTRINGS (Biceps Femoris & Semitendinosus — Matching Reference Dual Bellies!)
    if (_isTrained(['hamstring', 'hamstrings', 'biceps femoris', 'legs', 'posterior chain'])) {
      for (final sign in [-1.0, 1.0]) {
        // 1. Lateral Head (Biceps Femoris)
        final hamLat = Path();
        hamLat.moveTo(p(sign * 0.20, 0.595).dx, p(sign * 0.20, 0.595).dy);
        hamLat.quadraticBezierTo(p(sign * 0.20, 0.64).dx, p(sign * 0.20, 0.64).dy, p(sign * 0.145, 0.695).dx, p(sign * 0.145, 0.695).dy);
        hamLat.lineTo(p(sign * 0.105, 0.695).dx, p(sign * 0.105, 0.695).dy);
        hamLat.quadraticBezierTo(p(sign * 0.105, 0.64).dx, p(sign * 0.105, 0.64).dy, p(sign * 0.105, 0.595).dx, p(sign * 0.105, 0.595).dy);
        hamLat.close();
        canvas.drawPath(hamLat, highlightPaint);

        // 2. Medial Head (Semitendinosus)
        final hamMed = Path();
        hamMed.moveTo(p(sign * 0.095, 0.595).dx, p(sign * 0.095, 0.595).dy);
        hamMed.quadraticBezierTo(p(sign * 0.095, 0.64).dx, p(sign * 0.095, 0.64).dy, p(sign * 0.095, 0.695).dx, p(sign * 0.095, 0.695).dy);
        hamMed.lineTo(p(sign * 0.05, 0.695).dx, p(sign * 0.05, 0.695).dy);
        hamMed.quadraticBezierTo(p(sign * 0.03, 0.64).dx, p(sign * 0.03, 0.64).dy, p(sign * 0.02, 0.595).dx, p(sign * 0.02, 0.595).dy);
        hamMed.close();
        canvas.drawPath(hamMed, highlightPaint);
      }
    }

    // G. CALVES (Rear Gastrocnemius & Achilles)
    if (_isTrained(['calf', 'calves', 'gastrocnemius', 'soleus'])) {
      for (final sign in [-1.0, 1.0]) {
        // Lateral Head
        final calfLat = Path();
        calfLat.moveTo(p(sign * 0.13, 0.72).dx, p(sign * 0.13, 0.72).dy);
        calfLat.quadraticBezierTo(p(sign * 0.165, 0.78).dx, p(sign * 0.165, 0.78).dy, p(sign * 0.105, 0.85).dx, p(sign * 0.105, 0.85).dy);
        calfLat.lineTo(p(sign * 0.095, 0.72).dx, p(sign * 0.095, 0.72).dy);
        calfLat.close();
        canvas.drawPath(calfLat, highlightPaint);

        // Medial Head
        final calfMed = Path();
        calfMed.moveTo(p(sign * 0.095, 0.72).dx, p(sign * 0.095, 0.72).dy);
        calfMed.lineTo(p(sign * 0.085, 0.85).dx, p(sign * 0.085, 0.85).dy);
        calfMed.quadraticBezierTo(p(sign * 0.035, 0.78).dx, p(sign * 0.035, 0.78).dy, p(sign * 0.06, 0.72).dx, p(sign * 0.06, 0.72).dy);
        calfMed.close();
        canvas.drawPath(calfMed, highlightPaint);
      }
    }

    // --- 3. Back Anatomical Contours & Striations (Dark Crisp Lines) ---
    // Outer perimeter line
    canvas.drawOval(headRect, linePaint);
    canvas.drawPath(bodyPath, linePaint);

    // Spine line (cervical to sacrum)
    canvas.drawLine(p(0.0, 0.115), p(0.0, 0.47), fineLinePaint);

    // Trapezius boundary lines
    canvas.drawLine(p(0.0, 0.115), p(-0.24, 0.17), linePaint);
    canvas.drawLine(p(0.0, 0.115), p(0.24, 0.17), linePaint);
    canvas.drawLine(p(-0.24, 0.17), p(0.0, 0.35), linePaint);
    canvas.drawLine(p(0.24, 0.17), p(0.0, 0.35), linePaint);

    // Scapulae (shoulder blades) medial borders
    for (final sign in [-1.0, 1.0]) {
      final scap = Path();
      scap.moveTo(p(sign * 0.10, 0.20).dx, p(sign * 0.10, 0.20).dy);
      scap.lineTo(p(sign * 0.10, 0.28).dx, p(sign * 0.10, 0.28).dy);
      scap.lineTo(p(sign * 0.14, 0.27).dx, p(sign * 0.14, 0.27).dy);
      canvas.drawPath(scap, fineLinePaint);
    }

    // Lats boundary line (sweeping inwards)
    canvas.drawLine(p(-0.24, 0.265), p(-0.10, 0.38), linePaint);
    canvas.drawLine(p(0.24, 0.265), p(0.10, 0.38), linePaint);

    // Lower back / Thoracolumbar fascia
    canvas.drawLine(p(-0.06, 0.42), p(0.0, 0.47), fineLinePaint);
    canvas.drawLine(p(0.06, 0.42), p(0.0, 0.47), fineLinePaint);

    // Intergluteal Cleft (Central Vertical Groove)
    canvas.drawLine(p(0.0, 0.47), p(0.0, 0.59), linePaint);

    // Gluteal Folds (Bottom Horizontal Buttock Creases)
    for (final sign in [-1.0, 1.0]) {
      final fold = Path();
      fold.moveTo(p(sign * 0.205, 0.58).dx, p(sign * 0.205, 0.58).dy);
      fold.quadraticBezierTo(p(sign * 0.10, 0.595).dx, p(sign * 0.10, 0.595).dy, p(sign * 0.015, 0.59).dx, p(sign * 0.015, 0.59).dy);
      canvas.drawPath(fold, linePaint);
    }

    // Hamstring Separation Groove (Between Biceps Femoris & Semitendinosus)
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(p(sign * 0.10, 0.595), p(sign * 0.10, 0.695), linePaint);
    }

    // Popliteal Fossa (Back of Knee Horizontal Crease)
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(p(sign * 0.14, 0.70), p(sign * 0.05, 0.70), linePaint);
    }

    // Rear Calf Midline & Achilles Tendon
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(p(sign * 0.095, 0.72), p(sign * 0.09, 0.85), linePaint);
      // Achilles tendon vertical lines down to heel
      canvas.drawLine(p(sign * 0.08, 0.86), p(sign * 0.08, 0.95), fineLinePaint);
      canvas.drawLine(p(sign * 0.10, 0.86), p(sign * 0.10, 0.95), fineLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnatomicalBodyPainter oldDelegate) {
    return oldDelegate.trainedMuscles != trainedMuscles ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.silhouetteColor != silhouetteColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
