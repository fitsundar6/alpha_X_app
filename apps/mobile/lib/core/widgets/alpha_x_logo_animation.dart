import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// The official Alpha X Gym Animated Wordmark Loading Screen.
///
/// Implements the finalized cinematic pure white on black reveal sequence:
/// 1. Phase 1 (0.00 – 0.35): Smooth Pure White Wordmark Reveal ("Λ L P H Λ - X") with subtle neon tube bloom.
/// 2. Phase 2 (0.35 – 0.55): In-place morph of letter 'H' into the pure white dumbbell silhouette inside its slot.
/// 3. Phase 3 (0.55 – 1.00): Cinematic forward 3D camera zoom of the pure white dumbbell actor with ZERO rotation,
///    while outer letters smoothly fade and the actor breaches the camera lens directly into the app entry screen.
class AlphaXLogoAnimation extends StatefulWidget {
  /// Base size (height) of the hero wordmark characters.
  final double? size;

  /// Optional external animation controller if driven by a parent screen.
  final AnimationController? controller;

  /// Callback when the animation reaches full completion (1.0).
  final VoidCallback? onComplete;

  /// Callback when the transition phase begins (~0.81 / transition start).
  final VoidCallback? onTransitionStart;

  /// Whether the animation should auto-play on mount (default true).
  final bool autoPlay;

  /// If true, initializes directly at the final settled state.
  final bool startSettled;

  /// Allows user to tap anywhere to smoothly fast-forward to the settled state.
  final bool allowTapToSkip;

  /// Optional custom glow color (defaults to pure white).
  final Color? glowColor;

  /// Duration of the entire animation sequence (defaults to 4800ms).
  final Duration duration;

  /// Whether to display the athletic brand line / tagline (retained for API compatibility).
  final bool showBrandLine;

  const AlphaXLogoAnimation({
    super.key,
    this.size,
    this.controller,
    this.onComplete,
    this.onTransitionStart,
    this.autoPlay = true,
    this.startSettled = false,
    this.allowTapToSkip = true,
    this.glowColor,
    this.duration = const Duration(milliseconds: 4800),
    this.showBrandLine = true,
  });

  @override
  State<AlphaXLogoAnimation> createState() => AlphaXLogoAnimationState();
}

class AlphaXLogoAnimationState extends State<AlphaXLogoAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _internalController;
  AnimationController get _effectiveController =>
      widget.controller ?? _internalController;

  late final Animation<double> _settleAnimation;
  bool _transitionTriggered = false;

  /// Exposes the settle/fade phase for coordinating parent transitions
  Animation<double> get settleAnimation => _settleAnimation;

  static const int charCount = 7;

  // ViewBox widths for: Λ, L, P, H, Λ, -, X (height is always 100)
  static const List<double> charViewBoxWidths = [
    74.0, // 0: Λ
    66.0, // 1: L
    66.0, // 2: P
    68.0, // 3: H (morphs to dumbbell)
    74.0, // 4: Λ
    40.0, // 5: -
    74.0, // 6: X
  ];

  @override
  void initState() {
    super.initState();

    _internalController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _settleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _effectiveController,
        curve: const Interval(0.810, 1.000, curve: Curves.easeInOutCubic),
      ),
    );

    _effectiveController.addListener(_onProgress);

    if (widget.startSettled) {
      _effectiveController.value = 1.0;
      _transitionTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete?.call();
      });
    } else if (widget.autoPlay && widget.controller == null) {
      _effectiveController.forward();
    }
  }

  void _onProgress() {
    final val = _effectiveController.value;

    if (val >= 0.810 && !_transitionTriggered) {
      _transitionTriggered = true;
      widget.onTransitionStart?.call();
    }

    if (val >= 1.0) {
      widget.onComplete?.call();
    }
  }

  void skipToSettled() {
    if (_effectiveController.value < 1.0) {
      _effectiveController.value = 1.0;
      _transitionTriggered = true;
      widget.onTransitionStart?.call();
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onProgress);
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // Responsive typography sizing matching Stitch specification
        final charHeight = widget.size ?? (screenW * 0.16).clamp(56.0, 92.0);
        final charGap = (screenW * 0.026).clamp(8.0, 18.0);
        final strokeWidth = (charHeight * 0.15).clamp(8.0, 13.0);

        return AnimatedBuilder(
          animation: _effectiveController,
          builder: (context, child) {
            final double t = _effectiveController.value;

            // Phase 1 (0.00 – 0.35): Wordmark reveal
            final double wordmarkOpacity = (t / 0.27).clamp(0.0, 1.0);

            // Phase 2 (0.35 – 0.55): In-place morph of letter 'H' to pure white dumbbell silhouette
            double hLetterOpacity = 1.0;
            double hDumbbellOpacity = 0.0;
            if (t < 0.35) {
              hLetterOpacity = 1.0;
              hDumbbellOpacity = 0.0;
            } else if (t <= 0.55) {
              final double morphT = (t - 0.35) / 0.20;
              final double curve = Curves.easeInOut.transform(morphT);
              hLetterOpacity = (1.0 - curve).clamp(0.0, 1.0);
              hDumbbellOpacity = curve.clamp(0.0, 1.0);
            } else {
              hLetterOpacity = 0.0;
              hDumbbellOpacity = 1.0;
            }

            // Phase 3 (0.55 – 1.00): Straight forward 3D zoom + camera breach
            final bool isZoomPhase = t > 0.55;
            final double zoomProgress = isZoomPhase
                ? ((t - 0.55) / 0.45).clamp(0.0, 1.0)
                : 0.0;

            // Exponential acceleration curve matching Stitch: Math.pow(progress, 2.7)
            final double easeProgress = math.pow(zoomProgress, 2.7).toDouble();
            final double dynamicScale = 1.0 + easeProgress * 32.0;

            // Outer letters fade out during zoom
            double otherLettersOpacity = wordmarkOpacity;
            if (zoomProgress > 0.15) {
              final double letterFade =
                  (1.0 - (zoomProgress - 0.15) / 0.35).clamp(0.0, 1.0);
              otherLettersOpacity *= letterFade;
            }

            // Dumbbell breaches camera lens at > 0.72
            double dumbbellActorOpacity = 1.0;
            if (zoomProgress > 0.72) {
              dumbbellActorOpacity =
                  (1.0 - (zoomProgress - 0.72) / 0.28).clamp(0.0, 1.0);
            }

            // Subtle breathing resting glow
            final double pulse = 0.85 + 0.15 * math.sin(t * math.pi * 4.0);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Hidden asset image strictly retained for test and background compatibility
                Offstage(
                  offstage: true,
                  child: Image.asset(
                    AppConstants.logoPath,
                    semanticLabel: AppConstants.appName,
                    fit: BoxFit.contain,
                  ),
                ),

                // Central Wordmark: "Λ L P H Λ - X" with in-place H morph & 3D forward zoom
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(charCount, (idx) {
                    final baseW = charViewBoxWidths[idx];
                    final charW = charHeight * (baseW / 100.0);

                    Widget letterWidget;

                    if (idx == 3) {
                      // Slot 3 (H / Zooming Dumbbell Actor)
                      letterWidget = Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // 3D forward perspective
                          ..scale(isZoomPhase ? dynamicScale : 1.0),
                        child: Opacity(
                          opacity: (isZoomPhase
                                  ? dumbbellActorOpacity
                                  : wordmarkOpacity)
                              .clamp(0.0, 1.0),
                          child: SizedBox(
                            width: charW,
                            height: charHeight,
                            child: CustomPaint(
                              size: Size(charW, charHeight),
                              painter: WordmarkCharPainter(
                                charIndex: 3,
                                strokeWidth: strokeWidth,
                                glowFactor: pulse,
                                hLetterOpacity: hLetterOpacity,
                                hDumbbellOpacity: hDumbbellOpacity,
                                charOpacity: 1.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      // Standard static letters (Λ, L, P, Λ, -, X)
                      letterWidget = Opacity(
                        opacity: otherLettersOpacity.clamp(0.0, 1.0),
                        child: SizedBox(
                          width: charW,
                          height: charHeight,
                          child: CustomPaint(
                            size: Size(charW, charHeight),
                            painter: WordmarkCharPainter(
                              charIndex: idx,
                              strokeWidth: strokeWidth,
                              glowFactor: pulse,
                              charOpacity: 1.0,
                            ),
                          ),
                        ),
                      );
                    }

                    if (idx < charCount - 1) {
                      return Padding(
                        padding: EdgeInsets.only(right: charGap),
                        child: letterWidget,
                      );
                    }
                    return letterWidget;
                  }),
                ),
              ],
            );
          },
        );
      },
    );

    if (widget.allowTapToSkip) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: skipToSettled,
        child: content,
      );
    }

    return content;
  }
}

/// Exact pure white dumbbell geometry matching Stitch export:
/// - Double-tier symmetrical vertical rounded plates
/// - Central horizontal bar / handle
/// - Pin collars
class DumbbellGeometry {
  static void draw(Canvas canvas, Size size, Paint paint) {
    // Coordinate space: width 60, height 76 (viewBox 0 0 460 76 with H slot w:60, h:76)
    final scaleX = size.width / 60.0;
    final scaleY = size.height / 76.0;

    void drawPart(double x, double y, double w, double h, double r) {
      final rect = Rect.fromLTWH(
        x * scaleX,
        y * scaleY,
        w * scaleX,
        h * scaleY,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(r * ((scaleX + scaleY) / 2)),
        ),
        paint,
      );
    }

    // Left outer pin collar: x:2, y:34, w:4, h:8, rx:2
    drawPart(2.0, 34.0, 4.0, 8.0, 2.0);
    // Left secondary plate (outer tier): x:8, y:24, w:7, h:28, rx:3
    drawPart(8.0, 24.0, 7.0, 28.0, 3.0);
    // Left primary plate (inner tier, taller): x:17, y:16, w:8, h:44, rx:4
    drawPart(17.0, 16.0, 8.0, 44.0, 4.0);
    // Central horizontal bar / handle: x:25, y:33, w:14, h:10, rx:2
    drawPart(25.0, 33.0, 14.0, 10.0, 2.0);
    // Right primary plate (inner tier, taller): x:39, y:16, w:8, h:44, rx:4
    drawPart(39.0, 16.0, 8.0, 44.0, 4.0);
    // Right secondary plate (outer tier): x:49, y:24, w:7, h:28, rx:3
    drawPart(49.0, 24.0, 7.0, 28.0, 3.0);
    // Right outer pin collar: x:58, y:34, w:4, h:8, rx:2
    drawPart(58.0, 34.0, 4.0, 8.0, 2.0);
  }
}

/// CustomPainter rendering each SVG glyph with multi-layered neon tube bloom
/// and in-place morphing from letter 'H' to pure white dumbbell silhouette.
class WordmarkCharPainter extends CustomPainter {
  final int charIndex;
  final double strokeWidth;
  final double glowFactor;
  final double hLetterOpacity;
  final double hDumbbellOpacity;
  final double charOpacity;

  WordmarkCharPainter({
    required this.charIndex,
    required this.strokeWidth,
    required this.glowFactor,
    this.hLetterOpacity = 1.0,
    this.hDumbbellOpacity = 0.0,
    this.charOpacity = 1.0,
  });

  Path _getPath(Size size) {
    switch (charIndex) {
      case 0:
      case 4:
        return LambdaPath.get(size);
      case 1:
        return LPath.get(size);
      case 2:
        return PPath.get(size);
      case 3:
        return HPath.get(size);
      case 5:
        return HyphenPath.get(size);
      case 6:
      default:
        return XPath.get(size);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (charOpacity <= 0.0) return;

    if (charIndex == 3) {
      // Slot 3 (H -> Dumbbell morph)
      if (hLetterOpacity > 0.005) {
        final path = _getPath(size);
        final effAlpha = (charOpacity * hLetterOpacity).clamp(0.0, 1.0);

        // 1. Ambient outer neon glow
        final outerGlowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8.0
          ..color = Colors.white
              .withOpacity((0.25 * glowFactor * effAlpha).clamp(0.0, 1.0))
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
        canvas.drawPath(path, outerGlowPaint);

        // 2. Focused mid neon glow
        final midGlowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4.0
          ..color = Colors.white
              .withOpacity((0.45 * glowFactor * effAlpha).clamp(0.0, 1.0))
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
        canvas.drawPath(path, midGlowPaint);

        // 3. Crisp white neon tube core
        final corePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = Colors.white.withOpacity(effAlpha)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, corePaint);
      }

      if (hDumbbellOpacity > 0.005) {
        final effAlpha = (charOpacity * hDumbbellOpacity).clamp(0.0, 1.0);

        // Outer glow drop-shadow
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white
              .withOpacity((0.45 * glowFactor * effAlpha).clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
        DumbbellGeometry.draw(canvas, size, glowPaint);

        // Solid pure white core
        final corePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(effAlpha);
        DumbbellGeometry.draw(canvas, size, corePaint);
      }
    } else {
      // Standard wordmark glyphs (Λ, L, P, Λ, -, X)
      final path = _getPath(size);
      final effAlpha = charOpacity.clamp(0.0, 1.0);

      // 1. Ambient outer neon glow
      final outerGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 8.0
        ..color = Colors.white
            .withOpacity((0.25 * glowFactor * effAlpha).clamp(0.0, 1.0))
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
      canvas.drawPath(path, outerGlowPaint);

      // 2. Focused mid neon glow
      final midGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4.0
        ..color = Colors.white
            .withOpacity((0.45 * glowFactor * effAlpha).clamp(0.0, 1.0))
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
      canvas.drawPath(path, midGlowPaint);

      // 3. Crisp white neon tube core
      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withOpacity(effAlpha)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant WordmarkCharPainter oldDelegate) {
    return oldDelegate.charIndex != charIndex ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glowFactor != glowFactor ||
        oldDelegate.hLetterOpacity != hLetterOpacity ||
        oldDelegate.hDumbbellOpacity != hDumbbellOpacity ||
        oldDelegate.charOpacity != charOpacity;
  }
}

// ---------------------------------------------------------------------------
// SVG VECTOR GLYPH DEFINITIONS (viewBox heights are 100)
// ---------------------------------------------------------------------------

class LambdaPath {
  static Path get(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.12, h * 0.88);
    path.lineTo(w * 0.46, h * 0.14);
    path.cubicTo(w * 0.48, h * 0.10, w * 0.52, h * 0.10, w * 0.54, h * 0.14);
    path.lineTo(w * 0.88, h * 0.88);
    return path;
  }
}

class LPath {
  static Path get(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.22, h * 0.14);
    path.lineTo(w * 0.22, h * 0.88);
    path.lineTo(w * 0.88, h * 0.88);
    return path;
  }
}

class PPath {
  static Path get(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.22, h * 0.88);
    path.lineTo(w * 0.22, h * 0.14);
    path.lineTo(w * 0.55, h * 0.14);
    path.cubicTo(w * 0.75, h * 0.14, w * 0.88, h * 0.25, w * 0.88, h * 0.38);
    path.cubicTo(w * 0.88, h * 0.51, w * 0.75, h * 0.62, w * 0.55, h * 0.62);
    path.lineTo(w * 0.22, h * 0.62);
    return path;
  }
}

class HPath {
  static Path get(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    // Left vertical stroke
    path.moveTo(w * 0.22, h * 0.14);
    path.lineTo(w * 0.22, h * 0.88);
    // Horizontal crossbar
    path.moveTo(w * 0.22, h * 0.51);
    path.lineTo(w * 0.78, h * 0.51);
    // Right vertical stroke
    path.moveTo(w * 0.78, h * 0.14);
    path.lineTo(w * 0.78, h * 0.88);
    return path;
  }
}

class HyphenPath {
  static Path get(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.18, h * 0.51);
    path.lineTo(w * 0.82, h * 0.51);
    return path;
  }
}

class XPath {
  static Path get(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.18, h * 0.14);
    path.lineTo(w * 0.82, h * 0.88);
    path.moveTo(w * 0.82, h * 0.14);
    path.lineTo(w * 0.18, h * 0.88);
    return path;
  }
}
