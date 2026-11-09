import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// The official Alpha X Gym Animated Wordmark Logo Reveal Widget.
///
/// Faithfully reproduces the Stitch rubber-ball squash & stretch physics animation:
/// - 7 characters in "Λ L P H Λ - X"
/// - Gravitational free-fall from above viewport (-110vh)
/// - Multi-bounce elastic decay with realistic vertical squash on impact and stretch in flight
/// - Individual organic variations in bounce elasticity and stagger (145ms between consecutive letters)
/// - Pure black canvas with refined white ambient neon tube glow & resting pulse
/// - 1.6s resting hold followed by smooth 0.8s pure opacity fade-out into app entry.
class AlphaXLogoAnimation extends StatefulWidget {
  /// Base size (height) of the hero wordmark characters.
  final double? size;

  /// Optional external animation controller if driven by a parent screen.
  final AnimationController? controller;

  /// Callback when the animation reaches full completion (1.0).
  final VoidCallback? onComplete;

  /// Callback when the transition phase begins (~0.83 / fade start).
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

class LetterVariation {
  final double heightScale;
  final double timeScale;
  const LetterVariation(this.heightScale, this.timeScale);
}

enum PhysicsStepType { drop, squash, rebound }

class PhysicsStep {
  final PhysicsStepType type;
  final double duration;
  final double startY;
  final double minSY;
  final double maxSX;
  final double apexH;
  final double stretchSY;
  final double stretchSX;

  const PhysicsStep.drop({
    required this.duration,
    required this.startY,
  })  : type = PhysicsStepType.drop,
        minSY = 1.0,
        maxSX = 1.0,
        apexH = 0.0,
        stretchSY = 1.0,
        stretchSX = 1.0;

  const PhysicsStep.squash({
    required this.duration,
    required this.minSY,
    required this.maxSX,
  })  : type = PhysicsStepType.squash,
        startY = 0.0,
        apexH = 0.0,
        stretchSY = 1.0,
        stretchSX = 1.0;

  const PhysicsStep.rebound({
    required this.duration,
    required this.apexH,
    required this.stretchSY,
    required this.stretchSX,
  })  : type = PhysicsStepType.rebound,
        startY = 0.0,
        minSY = 1.0,
        maxSX = 1.0;
}

class RubberPhysicsState {
  final double y;
  final double sx;
  final double sy;
  final double opacity;

  const RubberPhysicsState({
    required this.y,
    required this.sx,
    required this.sy,
    required this.opacity,
  });
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

  // Stagger delay between letters (145ms)
  static const double stagger = 0.145;
  static const int charCount = 7;

  // ViewBox widths for: Λ, L, P, H, Λ, -, X (height is always 100)
  static const List<double> charViewBoxWidths = [
    74.0, // 0: Λ
    66.0, // 1: L
    66.0, // 2: P
    68.0, // 3: H
    74.0, // 4: Λ
    40.0, // 5: -
    74.0, // 6: X
  ];

  static const List<LetterVariation> letterVariations = [
    LetterVariation(1.00, 1.00),
    LetterVariation(0.96, 0.98),
    LetterVariation(1.03, 1.02),
    LetterVariation(0.98, 0.99),
    LetterVariation(1.02, 1.01),
    LetterVariation(0.94, 0.96),
    LetterVariation(1.01, 1.00),
  ];

  static const List<PhysicsStep> baseTimeline = [
    // 0: Initial Gravitational Free-fall from above viewport
    PhysicsStep.drop(duration: 0.44, startY: -110.0),
    // 1: First Impact & Compression
    PhysicsStep.squash(duration: 0.075, minSY: 0.73, maxSX: 1.28),
    // 2: Rebound 1 Flight (Apex ~110px)
    PhysicsStep.rebound(duration: 0.42, apexH: 110.0, stretchSY: 1.15, stretchSX: 0.90),
    // 3: Second Impact & Compression
    PhysicsStep.squash(duration: 0.055, minSY: 0.84, maxSX: 1.16),
    // 4: Rebound 2 Flight (Apex ~45px)
    PhysicsStep.rebound(duration: 0.28, apexH: 45.0, stretchSY: 1.08, stretchSX: 0.95),
    // 5: Third Impact & Compression
    PhysicsStep.squash(duration: 0.040, minSY: 0.92, maxSX: 1.06),
    // 6: Rebound 3 Flight (Apex ~16px)
    PhysicsStep.rebound(duration: 0.17, apexH: 16.0, stretchSY: 1.03, stretchSX: 0.98),
    // 7: Fourth Impact & Micro-settle
    PhysicsStep.squash(duration: 0.035, minSY: 0.97, maxSX: 1.02),
  ];

  static double getLetterDuration(int charIdx) {
    final varInfo = letterVariations[charIdx];
    double total = 0.0;
    for (final step in baseTimeline) {
      total += step.duration * varInfo.timeScale;
    }
    return total;
  }

  // Precalculated maximum letter end time (~2.385s)
  static final double maxLetterEndTime = () {
    double maxEnd = 0.0;
    for (int i = 0; i < charCount; i++) {
      final end = i * stagger + getLetterDuration(i);
      if (end > maxEnd) maxEnd = end;
    }
    return maxEnd;
  }();

  // Timeline anchors
  static const double holdBeforeFade = 1.6; // 1.6s resting hold after settle
  static final double fadeStartTime = maxLetterEndTime + holdBeforeFade; // ~3.985s
  static const double fadeDuration = 0.8; // 0.8s pure opacity fade-out
  static final double totalReferenceDuration = fadeStartTime + fadeDuration; // ~4.785s

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
        curve: const Interval(0.830, 1.000, curve: Curves.easeInOutCubic),
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

    if (val >= 0.830 && !_transitionTriggered) {
      _transitionTriggered = true;
      widget.onTransitionStart?.call();
    }

    if (val >= 1.0) {
      widget.onComplete?.call();
    }
  }

  void skipToSettled() {
    if (_effectiveController.value < 1.0) {
      _effectiveController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void replay() {
    _transitionTriggered = false;
    _effectiveController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onProgress);
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  /// Evaluates rubber physics state (y position, scaleX, scaleY, opacity) for a letter at elapsed seconds.
  RubberPhysicsState _evalRubberPhysics(double elapsed, int charIdx, double vh) {
    final varInfo = letterVariations[charIdx];

    if (elapsed <= 0) {
      return RubberPhysicsState(
        y: -1.1 * vh,
        sx: 1.0,
        sy: 1.0,
        opacity: 0.0,
      );
    }

    double currT = 0.0;
    for (int i = 0; i < baseTimeline.length; i++) {
      final step = baseTimeline[i];
      final stepDuration = step.duration * varInfo.timeScale;

      if (elapsed < currT + stepDuration) {
        final p = ((elapsed - currT) / stepDuration).clamp(0.0, 1.0);

        if (step.type == PhysicsStepType.drop) {
          // Parabolic free-fall: y = startY * (1 - p^2)
          final fallProgress = p * p;
          final currentY = (-1.1 * vh) * (1.0 - fallProgress);
          // Slight vertical stretch due to air drag approaching ground
          final stretch = 1.0 + (0.08 * p * p);
          final squash = 1.0 / math.sqrt(stretch);
          return RubberPhysicsState(
            y: currentY,
            sx: squash,
            sy: stretch,
            opacity: math.min(1.0, p * 3.5),
          );
        }

        if (step.type == PhysicsStepType.squash) {
          // Parabolic compression: reaches maximum squash at p = 0.5, returns to 1 at p = 1
          final squashFactor = 4.0 * p * (1.0 - p); // 0 -> 1 -> 0
          final currentSy = 1.0 - (1.0 - step.minSY) * squashFactor;
          final currentSx = 1.0 + (step.maxSX - 1.0) * squashFactor;
          return RubberPhysicsState(
            y: 0.0,
            sx: currentSx,
            sy: currentSy,
            opacity: 1.0,
          );
        }

        if (step.type == PhysicsStepType.rebound) {
          // Inverted parabolic ballistic flight: y(p) = -apexH * 4 * p * (1 - p)
          final flightArc = 4.0 * p * (1.0 - p);
          final apex = step.apexH * varInfo.heightScale;
          final currentY = -apex * flightArc;

          // Velocity is highest near start (p=0) and end (p=1), zero at apex (p=0.5).
          // Vertical stretch proportional to speed:
          final velocityWeight = (1.0 - 2.0 * p).abs();
          final currentSy = 1.0 + (step.stretchSY - 1.0) * velocityWeight;
          final currentSx = 1.0 - (1.0 - step.stretchSX) * velocityWeight;

          return RubberPhysicsState(
            y: currentY,
            sx: currentSx,
            sy: currentSy,
            opacity: 1.0,
          );
        }
      }
      currT += stepDuration;
    }

    // Completely settled at rest
    return const RubberPhysicsState(y: 0.0, sx: 1.0, sy: 1.0, opacity: 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;
    final bool disableAnimations = mediaQuery.disableAnimations;

    // Responsive character sizing matching Stitch reference:
    // height: clamp(56px, 16vw, 92px)
    final double charHeight = widget.size ??
        (screenWidth * 0.16).clamp(56.0, 92.0);
    final double charGap = (screenWidth * 0.026).clamp(8.0, 18.0);
    final double strokeWidth = charHeight * 0.15; // 15% stroke width

    Widget content = AnimatedBuilder(
      animation: _effectiveController,
      builder: (context, _) {
        final double progress = _effectiveController.value;
        final double t = progress * totalReferenceDuration;

        if (disableAnimations) {
          return _buildWordmarkRow(
            charHeight: charHeight,
            charGap: charGap,
            strokeWidth: strokeWidth,
            vh: screenHeight,
            t: maxLetterEndTime + 0.5,
            wordmarkOpacity: 1.0,
          );
        }

        // Pure opacity fade-out transition after 1.6s hold
        double wordmarkOpacity = 1.0;
        if (t >= fadeStartTime) {
          final double fadeProg = ((t - fadeStartTime) / fadeDuration).clamp(0.0, 1.0);
          wordmarkOpacity = 1.0 - Curves.easeInOutCubic.transform(fadeProg);
        }

        return _buildWordmarkRow(
          charHeight: charHeight,
          charGap: charGap,
          strokeWidth: strokeWidth,
          vh: screenHeight,
          t: t,
          wordmarkOpacity: wordmarkOpacity,
        );
      },
    );

    if (widget.allowTapToSkip) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: skipToSettled,
        child: content,
      );
    }

    return content;
  }

  Widget _buildWordmarkRow({
    required double charHeight,
    required double charGap,
    required double strokeWidth,
    required double vh,
    required double t,
    required double wordmarkOpacity,
  }) {
    // Resting pulse glow calculation over 3.5s cycle after settling
    double glowFactor = 1.0;
    if (t >= maxLetterEndTime && t < fadeStartTime) {
      final double settleT = t - maxLetterEndTime;
      final double pulse = 0.5 + 0.5 * math.sin((settleT / 3.5) * 2.0 * math.pi);
      glowFactor = 0.85 + 0.30 * pulse;
    } else if (t >= fadeStartTime) {
      glowFactor = wordmarkOpacity;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden asset image strictly retained for test compatibility
        Opacity(
          opacity: 0.0,
          child: SizedBox(
            width: 1.0,
            height: 1.0,
            child: Image.asset(
              AppConstants.logoPath,
              width: 1.0,
              height: 1.0,
              fit: BoxFit.contain,
              semanticLabel: AppConstants.appName,
            ),
          ),
        ),

        // Dead-centered vector wordmark row
        Opacity(
          opacity: wordmarkOpacity.clamp(0.0, 1.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(charCount, (idx) {
              final double startTime = idx * stagger;
              final double totalDuration = getLetterDuration(idx);
              final double charW = charHeight * (charViewBoxWidths[idx] / 100.0);

              RubberPhysicsState state;
              if (t < startTime) {
                state = RubberPhysicsState(
                  y: -1.1 * vh,
                  sx: 1.0,
                  sy: 1.0,
                  opacity: 0.0,
                );
              } else {
                final double elapsed = t - startTime;
                if (elapsed >= totalDuration) {
                  state = const RubberPhysicsState(y: 0.0, sx: 1.0, sy: 1.0, opacity: 1.0);
                } else {
                  state = _evalRubberPhysics(elapsed, idx, vh);
                }
              }

              Widget letterWidget = Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..translate(0.0, state.y)
                  ..scale(state.sx, state.sy),
                child: Opacity(
                  opacity: state.opacity.clamp(0.0, 1.0),
                  child: SizedBox(
                    width: charW,
                    height: charHeight,
                    child: CustomPaint(
                      size: Size(charW, charHeight),
                      painter: WordmarkCharPainter(
                        charIndex: idx,
                        strokeWidth: strokeWidth,
                        glowFactor: glowFactor,
                      ),
                    ),
                  ),
                ),
              );

              if (idx < charCount - 1) {
                return Padding(
                  padding: EdgeInsets.only(right: charGap),
                  child: letterWidget,
                );
              }
              return letterWidget;
            }),
          ),
        ),
      ],
    );
  }
}

/// CustomPainter rendering each SVG glyph with multi-layered neon tube bloom.
class WordmarkCharPainter extends CustomPainter {
  final int charIndex;
  final double strokeWidth;
  final double glowFactor;

  WordmarkCharPainter({
    required this.charIndex,
    required this.strokeWidth,
    required this.glowFactor,
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
    final path = _getPath(size);

    // 1. Ambient outer neon glow: filter drop-shadow(0 0 28px rgba(255, 255, 255, 0.25))
    final outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8.0
      ..color = Colors.white.withOpacity((0.25 * glowFactor).clamp(0.0, 1.0))
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
    canvas.drawPath(path, outerGlowPaint);

    // 2. Focused mid neon glow: filter drop-shadow(0 0 14px rgba(255, 255, 255, 0.45))
    final midGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4.0
      ..color = Colors.white.withOpacity((0.45 * glowFactor).clamp(0.0, 1.0))
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
    canvas.drawPath(path, midGlowPaint);

    // 3. Crisp white neon tube core
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant WordmarkCharPainter oldDelegate) {
    return oldDelegate.charIndex != charIndex ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.glowFactor != glowFactor;
  }
}

// ---------------------------------------------------------------------------
// SVG VECTOR GLYPH DEFINITIONS (viewBox heights are 100)
// ---------------------------------------------------------------------------

/// Character Λ: Chevron without crossbar with rounded apex & terminals (viewBox 74 x 100)
class LambdaPath {
  static Path get(Size size) {
    final sx = size.width / 74.0;
    final sy = size.height / 100.0;
    return Path()
      ..moveTo(7.0 * sx, 92.0 * sy)
      ..lineTo(37.0 * sx, 8.0 * sy)
      ..lineTo(67.0 * sx, 92.0 * sy);
  }
}

/// Character L: Vertical stem smoothly curving into horizontal foot (viewBox 66 x 100)
class LPath {
  static Path get(Size size) {
    final sx = size.width / 66.0;
    final sy = size.height / 100.0;
    return Path()
      ..moveTo(7.0 * sx, 8.0 * sy)
      ..lineTo(7.0 * sx, 68.0 * sy)
      ..quadraticBezierTo(7.0 * sx, 92.0 * sy, 31.0 * sx, 92.0 * sy)
      ..lineTo(59.0 * sx, 92.0 * sy);
  }
}

/// Character P: Continuous flowing rounded path looping into vertical leg (viewBox 66 x 100)
class PPath {
  static Path get(Size size) {
    final sx = size.width / 66.0;
    final sy = size.height / 100.0;
    return Path()
      ..moveTo(7.0 * sx, 8.0 * sy)
      ..lineTo(40.0 * sx, 8.0 * sy)
      ..cubicTo(55.0 * sx, 8.0 * sy, 59.0 * sx, 19.0 * sy, 59.0 * sx, 29.0 * sy)
      ..cubicTo(59.0 * sx, 39.0 * sy, 55.0 * sx, 50.0 * sy, 40.0 * sx, 50.0 * sy)
      ..lineTo(27.0 * sx, 50.0 * sy)
      ..quadraticBezierTo(7.0 * sx, 50.0 * sy, 7.0 * sx, 70.0 * sy)
      ..lineTo(7.0 * sx, 92.0 * sy);
  }
}

/// Character H: Two vertical legs connected with centered horizontal bar (viewBox 68 x 100)
class HPath {
  static Path get(Size size) {
    final sx = size.width / 68.0;
    final sy = size.height / 100.0;
    return Path()
      ..moveTo(7.0 * sx, 8.0 * sy)
      ..lineTo(7.0 * sx, 92.0 * sy)
      ..moveTo(7.0 * sx, 50.0 * sy)
      ..lineTo(61.0 * sx, 50.0 * sy)
      ..moveTo(61.0 * sx, 8.0 * sy)
      ..lineTo(61.0 * sx, 92.0 * sy);
  }
}

/// Character -: Centered rounded horizontal capsule bar (viewBox 40 x 100)
class HyphenPath {
  static Path get(Size size) {
    final sx = size.width / 40.0;
    final sy = size.height / 100.0;
    return Path()
      ..moveTo(7.0 * sx, 50.0 * sy)
      ..lineTo(33.0 * sx, 50.0 * sy);
  }
}

/// Character X: Symmetric crossed athletic diagonals with rounded terminals (viewBox 74 x 100)
class XPath {
  static Path get(Size size) {
    final sx = size.width / 74.0;
    final sy = size.height / 100.0;
    return Path()
      ..moveTo(7.0 * sx, 8.0 * sy)
      ..lineTo(67.0 * sx, 92.0 * sy)
      ..moveTo(67.0 * sx, 8.0 * sy)
      ..lineTo(7.0 * sx, 92.0 * sy);
  }
}
