import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single character or icon debris particle in the seismic disintegration cascade.
class DebrisParticle {
  final String char;
  final double origX;
  final double origY;
  final double vx;
  final double vy;
  final double driftX;
  final double targetRotDeg;
  final double detachTimeMs;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final bool isIcon;

  const DebrisParticle({
    required this.char,
    required this.origX,
    required this.origY,
    required this.vx,
    required this.vy,
    required this.driftX,
    required this.targetRotDeg,
    required this.detachTimeMs,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
    this.isIcon = false,
  });
}

/// Computes the multi-harmonic low-frequency seismic ground offset (X, Y)
Offset computeQuakeOffset(double elapsedMs) {
  double quakeX = 0;
  double quakeY = 0;

  if (elapsedMs < 1000) {
    // Phase 1 (0.0s – 1.0s): Barely perceptible tremor, ~1-2px shift, low rumble
    final progress = elapsedMs / 1000.0;
    final amp = 0.7 + progress * 1.2;
    quakeX = math.sin(elapsedMs * 0.016) * amp + math.cos(elapsedMs * 0.027) * (amp * 0.5);
    quakeY = math.sin(elapsedMs * 0.021 + 1.2) * (amp * 0.8);
  } else if (elapsedMs < 2200) {
    // Phase 2 (1.0s – 2.2s): Gradually increasing tremor (~3-6px irregular undulating sway)
    final progress = (elapsedMs - 1000.0) / 1200.0;
    final amp = 1.9 + progress * 4.2;
    quakeX = math.sin(elapsedMs * 0.019) * amp + math.sin(elapsedMs * 0.007) * (amp * 0.6);
    quakeY = math.cos(elapsedMs * 0.024) * (amp * 0.75) + math.sin(elapsedMs * 0.041) * (amp * 0.25);
  } else if (elapsedMs < 2850) {
    // Phase 3 (2.2s – 2.85s): Peak seismic tremor (~8-12px deep ground roll)
    final progress = (elapsedMs - 2200.0) / 650.0;
    final amp = 6.1 + progress * 5.2;
    quakeX = math.sin(elapsedMs * 0.022) * amp + math.cos(elapsedMs * 0.011) * (amp * 0.7);
    quakeY = math.sin(elapsedMs * 0.028 + 0.8) * (amp * 0.85) + math.sin(elapsedMs * 0.052) * 2.0;
  } else {
    // Phase 4: Vibration decay after peak detachment
    final decay = math.max(0.0, 1.0 - (elapsedMs - 2850.0) / 800.0);
    quakeX = math.sin(elapsedMs * 0.022) * 5.0 * decay;
    quakeY = math.cos(elapsedMs * 0.028) * 4.0 * decay;
  }

  return Offset(quakeX, quakeY);
}

/// Computes the seismic rotational tilt in radians
double computeQuakeRotation(double elapsedMs) {
  double deg = 0;
  if (elapsedMs < 1000) {
    deg = math.sin(elapsedMs * 0.013) * 0.18;
  } else if (elapsedMs < 2200) {
    final progress = (elapsedMs - 1000.0) / 1200.0;
    deg = math.sin(elapsedMs * 0.015) * (0.2 + progress * 0.45);
  } else if (elapsedMs < 2850) {
    deg = math.sin(elapsedMs * 0.018) * 0.95;
  } else {
    final decay = math.max(0.0, 1.0 - (elapsedMs - 2850.0) / 800.0);
    deg = math.sin(elapsedMs * 0.018) * 0.4 * decay;
  }
  return deg * (math.pi / 180.0);
}

/// Builds debris particles positioned around the center of the mobile screen
List<DebrisParticle> generateLoginDebrisParticles({
  required Size screenSize,
  required String usernameText,
  required String passwordText,
}) {
  final random = math.Random(42);
  final particles = <DebrisParticle>[];
  final centerX = screenSize.width / 2;
  final startY = math.max(80.0, (screenSize.height - 520) / 2);

  void addTextLine({
    required String text,
    required double y,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double letterSpacing = 0.0,
    double? customStartX,
  }) {
    final charWidth = fontSize * 0.65 + letterSpacing;
    final totalWidth = text.length * charWidth;
    final lineStartX = customStartX ?? (centerX - totalWidth / 2);

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch.trim().isEmpty) continue;

      final initX = lineStartX + i * charWidth;
      final initY = y;

      // Staggered detachment time between 2700ms and 4100ms
      final isEarlyRogue = random.nextDouble() < 0.08;
      final detachTime = isEarlyRogue
          ? 2700.0 + random.nextDouble() * 250.0
          : 2850.0 + random.nextDouble() * 1250.0 + (initY / screenSize.height) * 200.0;

      particles.add(
        DebrisParticle(
          char: ch,
          origX: initX,
          origY: initY,
          vx: (random.nextDouble() - 0.5) * 1.6,
          vy: 0.0,
          driftX: (random.nextDouble() - 0.5) * 35.0,
          targetRotDeg: (random.nextBool() ? 1.0 : -1.0) * (90.0 + random.nextDouble() * 60.0),
          detachTimeMs: detachTime,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      );
    }
  }

  // 1. Top status bar
  addTextLine(
    text: 'ALPHA X • AUTH',
    y: 44,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFA3A3A3),
    letterSpacing: 2.0,
    customStartX: 24,
  );
  addTextLine(
    text: 'ENCRYPTED',
    y: 44,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFA3A3A3),
    letterSpacing: 1.8,
    customStartX: screenSize.width - 100,
  );

  // 2. Logo Block
  addTextLine(
    text: 'ALPHA X GYM',
    y: startY + 54,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  addTextLine(
    text: 'MEMBERSHIP ACCESS PORTAL',
    y: startY + 86,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFA3A3A3),
    letterSpacing: 0.8,
  );

  // 3. Username Field Label & Input
  addTextLine(
    text: 'EMAIL OR USERNAME',
    y: startY + 124,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFA3A3A3),
    letterSpacing: 1.2,
    customStartX: centerX - 160,
  );
  final userDisplay = usernameText.isNotEmpty ? usernameText : 'alexander.vance@alphax.com';
  addTextLine(
    text: userDisplay,
    y: startY + 152,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    customStartX: centerX - 150,
  );

  // 4. Password Field Label & Input
  addTextLine(
    text: 'PASSWORD',
    y: startY + 196,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFA3A3A3),
    letterSpacing: 1.2,
    customStartX: centerX - 160,
  );
  final passDisplay = passwordText.isNotEmpty ? '•' * passwordText.length : '••••••••••••';
  addTextLine(
    text: passDisplay,
    y: startY + 224,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 2.0,
    customStartX: centerX - 150,
  );

  // 5. Secondary Actions
  addTextLine(
    text: 'PREFILL DEFAULTS',
    y: startY + 264,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF737373),
    letterSpacing: 1.0,
    customStartX: centerX - 160,
  );
  addTextLine(
    text: 'Forgot Password?',
    y: startY + 264,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFA3A3A3),
    customStartX: centerX + 50,
  );

  // 6. Submit Button
  addTextLine(
    text: 'LOGIN',
    y: startY + 300,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: Colors.black,
    letterSpacing: 2.0,
  );

  // 7. Create Account Button
  addTextLine(
    text: 'CREATE ACCOUNT',
    y: startY + 360,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 1.5,
  );

  return particles;
}

/// CustomPainter rendering the tumbling, gravitational disintegration cascade
class SeismicDisintegrationPainter extends CustomPainter {
  final double elapsedMs;
  final List<DebrisParticle> particles;
  final double quakeX;
  final double quakeY;
  final double quakeRot;
  final double viewportHeight;

  SeismicDisintegrationPainter({
    required this.elapsedMs,
    required this.particles,
    required this.quakeX,
    required this.quakeY,
    required this.quakeRot,
    required this.viewportHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 580.0; // px/s^2 from Stitch spec

    for (final p in particles) {
      if (elapsedMs < p.detachTimeMs) {
        // 1. Attached to UI: follow seismic ground shift
        canvas.save();
        canvas.translate(p.origX + quakeX, p.origY + quakeY);
        if (quakeRot != 0.0) {
          canvas.rotate(quakeRot);
        }

        final tp = TextPainter(
          text: TextSpan(
            text: p.char,
            style: GoogleFonts.montserrat(
              fontSize: p.fontSize,
              fontWeight: p.fontWeight,
              color: p.color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      } else {
        // 2. Detached: accelerate under gravity with tumbling rotation & horizontal drift
        final t = (elapsedMs - p.detachTimeMs) / 1000.0; // seconds
        final currentY = p.origY + (p.vy * t) + (0.5 * gravity * t * t);
        final currentX = p.origX + (p.driftX * math.min(1.0, t * 1.2)) + (p.vx * t * 15.0);

        final rotProgress = math.min(1.0, t / 1.1);
        final currentRotDeg = p.targetRotDeg * (rotProgress * (2.0 - rotProgress)); // easeOutQuad
        final currentRotRad = currentRotDeg * (math.pi / 180.0);

        // Fade out near bottom of screen
        final bottomMargin = viewportHeight - 120.0;
        double opacity = 1.0;
        if (currentY > bottomMargin) {
          opacity = math.max(0.0, 1.0 - (currentY - bottomMargin) / 160.0);
        }

        if (opacity <= 0.001) continue;

        canvas.save();
        canvas.translate(currentX, currentY);
        canvas.rotate(currentRotRad);

        final tp = TextPainter(
          text: TextSpan(
            text: p.char,
            style: GoogleFonts.montserrat(
              fontSize: p.fontSize,
              fontWeight: p.fontWeight,
              color: p.color.withOpacity((opacity * p.color.opacity).clamp(0.0, 1.0)),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant SeismicDisintegrationPainter oldDelegate) {
    return oldDelegate.elapsedMs != elapsedMs ||
        oldDelegate.quakeX != quakeX ||
        oldDelegate.quakeY != quakeY;
  }
}
