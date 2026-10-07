import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// The official Alpha X Gym Animated Logo Reveal Widget.
///
/// Implements a 4–5 second cinematic logo reveal directly in Flutter:
/// 1. Dark Intro (0.0–0.6s): Clean dark void, subtle ambient gathering.
/// 2. Energy Build (0.6–1.5s): Smooth progressive reveal & diagonal energy sweep.
/// 3. Logo Reveal (1.5–2.6s): Complete PNG reveal with gold/titanium specular sheen.
/// 4. Brand Hold (2.6–3.8s): Rock-solid hero hold with micro-resonance breathing.
/// 5. Login Transition (3.8–5.0s): Seamless settle into the login interface.
///
/// Strictly preserves the original Alpha X Gym PNG logo proportions,
/// typography, and quality without distortion, stretching, or modification.
class AlphaXLogoAnimation extends StatefulWidget {
  /// Base size of the hero logo.
  final double size;

  /// Optional external animation controller if driven by a parent screen.
  final AnimationController? controller;

  /// Callback when the animation reaches full completion (5.0s).
  final VoidCallback? onComplete;

  /// Callback when the transition phase begins (at ~3.8s) so parent UI can animate.
  final VoidCallback? onTransitionStart;

  /// Whether the animation should auto-play on mount (default true).
  final bool autoPlay;

  /// If true, initializes directly at the final settled state (used on back-navigation).
  final bool startSettled;

  /// Allows user to tap anywhere to smoothly fast-forward to the settled state.
  final bool allowTapToSkip;

  /// Optional custom glow color (defaults to [AppColors.primaryGold]).
  final Color? glowColor;

  const AlphaXLogoAnimation({
    super.key,
    this.size = 140.0,
    this.controller,
    this.onComplete,
    this.onTransitionStart,
    this.autoPlay = true,
    this.startSettled = false,
    this.allowTapToSkip = true,
    this.glowColor,
  });

  @override
  State<AlphaXLogoAnimation> createState() => AlphaXLogoAnimationState();
}

class AlphaXLogoAnimationState extends State<AlphaXLogoAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _internalController;
  AnimationController get _effectiveController =>
      widget.controller ?? _internalController;

  late final Animation<double> _ambientFade;
  late final Animation<double> _energyFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _sweepPosition;
  late final Animation<double> _backGlowIntensity;
  late final Animation<double> _settleAnimation;

  /// Exposes the settle phase (0.0 to 1.0 between 3.8s and 4.6s) for coordinating parent transitions
  Animation<double> get settleAnimation => _settleAnimation;

  bool _transitionTriggered = false;

  @override
  void initState() {
    super.initState();

    _internalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    );

    _initAnimations();

    _effectiveController.addListener(_onProgress);

    if (widget.startSettled) {
      _effectiveController.value = 1.0;
      _transitionTriggered = true;
    } else if (widget.autoPlay && widget.controller == null) {
      _effectiveController.forward();
    }
  }

  void _initAnimations() {
    final controller = _effectiveController;

    // Phase 1: Ambient Background Warmth (0.0s - 0.6s -> 0.000 - 0.130)
    _ambientFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.03, 0.13, curve: Curves.easeOut),
      ),
    );

    // Phase 2 & 3: Logo Opacity Reveal (0.6s - 2.5s -> 0.130 - 0.543)
    _energyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.13, 0.52, curve: Curves.easeOutCubic),
      ),
    );

    // Subtle scale expansion from 0.95 to 1.00 (0.6s - 2.5s)
    _logoScale = Tween<double>(begin: 0.95, end: 1.00).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.13, 0.52, curve: Curves.easeOutCubic),
      ),
    );

    // Specular Sheen Sweep: travels diagonally from -1.6 to +1.6 (0.8s - 2.4s)
    _sweepPosition = Tween<double>(begin: -1.6, end: 1.6).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.17, 0.52, curve: Curves.easeInOutCubic),
      ),
    );

    // Atmospheric Back-Glow Lighting Envelope
    _backGlowIntensity = TweenSequence<double>([
      // Pre-ignition
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 13,
      ),
      // Power surge expansion
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.08, end: 0.32)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 39,
      ),
      // Hero hold plateau
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.32, end: 0.26)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      // Settle down to resting ambient aura
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.26, end: 0.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
    ]).animate(controller);

    // Phase 5: Settle Transition into Login UI (3.8s - 4.6s -> 0.826 - 1.000)
    _settleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.826, 1.000, curve: Curves.easeInOutCubic),
      ),
    );
  }

  void _onProgress() {
    final val = _effectiveController.value;

    // Trigger transition callback when entering Phase 5 (~3.8s)
    if (val >= 0.826 && !_transitionTriggered) {
      _transitionTriggered = true;
      widget.onTransitionStart?.call();
    }

    if (val >= 1.0) {
      widget.onComplete?.call();
    }
  }

  /// Fast-forwards smoothly to the completed/settled state.
  void skipToSettled() {
    if (_effectiveController.value < 1.0) {
      _effectiveController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Restarts the animation from the beginning.
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

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = widget.glowColor ?? AppColors.primaryGold;

    Widget content = AnimatedBuilder(
      animation: _effectiveController,
      builder: (context, _) {
        final double opacity = _energyFade.value;
        final double scale = _logoScale.value;
        final double sweep = _sweepPosition.value;
        final double glowVal = _backGlowIntensity.value;

        // Subtle micro-resonance breathing during Brand Hold (2.6s - 3.8s)
        double breathingGlow = glowVal;
        if (_effectiveController.value >= 0.56 && _effectiveController.value < 0.826) {
          final holdProgress = (_effectiveController.value - 0.56) / (0.826 - 0.56);
          breathingGlow += 0.025 * math.sin(2 * math.pi * holdProgress * 1.5);
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Atmospheric Back-Glow Radial Layer (Soft Gold Aura)
            if (breathingGlow > 0.005)
              Opacity(
                opacity: _ambientFade.value,
                child: Container(
                  width: widget.size * 2.2,
                  height: widget.size * 2.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        effectiveGlowColor.withOpacity((breathingGlow * 1.0).clamp(0.0, 1.0)),
                        effectiveGlowColor.withOpacity((breathingGlow * 0.35).clamp(0.0, 1.0)),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.48, 1.0],
                    ),
                  ),
                ),
              ),

            // 2. The Official Alpha X Gym PNG Logo with Specular Light Sheen
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (Rect bounds) {
                    // When sweep is active (-1.5 to +1.5), pass the diagonal specular beam
                    if (sweep >= -1.4 && sweep <= 1.4) {
                      return LinearGradient(
                        begin: Alignment(sweep - 0.7, -1.0),
                        end: Alignment(sweep + 0.7, 1.0),
                        colors: const [
                          Colors.white,
                          Colors.white,
                          AppColors.brightGold, // Leading gold glint
                          Colors.white,          // Peak specular highlight
                          AppColors.brightGold, // Trailing gold glow
                          Colors.white,
                          Colors.white,
                        ],
                        stops: const [0.0, 0.38, 0.46, 0.50, 0.54, 0.62, 1.0],
                      ).createShader(bounds);
                    }
                    // Outside the sweep pass, keep pure untouched white strokes
                    return const LinearGradient(
                      colors: [Colors.white, Colors.white],
                    ).createShader(bounds);
                  },
                  child: Image.asset(
                    AppConstants.logoPath,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: AppConstants.appName,
                  ),
                ),
              ),
            ),
          ],
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
}
