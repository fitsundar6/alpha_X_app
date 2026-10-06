import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

bool get _isTestEnvironment {
  if (kIsWeb) return false;
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

/// Centralized Motion, Animation, and Haptics Engine for Alpha X Gym.
/// Engineered for 60fps native performance, tactile sensory delight,
/// and buttery smooth Athletic Premium interactions.
class AlphaXHaptics {
  /// Light haptic tap on button/chip presses and tab switches
  static void tap() {
    HapticFeedback.lightImpact();
  }

  /// Success haptic buzz on save, booking confirmed, meal added, workout completed
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Celebratory haptic pulse on PRs, goal completion, and confetti bursts
  static void celebrate() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.mediumImpact();
    });
  }

  /// Haptic feedback on segmented controls and toggles
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Satisfying haptic tick for set completion or rest timer countdown
  static void tick() {
    HapticFeedback.lightImpact();
  }
}

/// Smooth count-up animation for numeric stat displays (calories, steps, streaks, etc.)
class AlphaXCountUpText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AlphaXCountUpText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    // Attempt to extract the numeric value and non-numeric prefix/suffix
    final match = RegExp(r'^([^0-9]*)([\d,]+(?:\.\d+)?)(.*)$').firstMatch(text.trim());
    if (match == null) {
      return Text(text, style: style);
    }

    final prefix = match.group(1) ?? '';
    final rawNumberStr = (match.group(2) ?? '').replaceAll(',', '');
    final suffix = match.group(3) ?? '';
    final targetValue = double.tryParse(rawNumberStr);

    if (targetValue == null) {
      return Text(text, style: style);
    }

    final isInteger = !rawNumberStr.contains('.');
    final effectiveDuration = _isTestEnvironment ? Duration.zero : duration;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _isTestEnvironment ? targetValue : 0.0, end: targetValue),
      duration: effectiveDuration,
      curve: curve,
      builder: (context, value, child) {
        String formattedNum;
        if (isInteger) {
          final intVal = value.round();
          formattedNum = intVal.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]},',
              );
        } else {
          formattedNum = value.toStringAsFixed(1);
        }
        return Text('$prefix$formattedNum$suffix', style: style);
      },
    );
  }
}

/// Frosted-glass (blur) container with translucent surface fill and crisp border.
/// Perfect for floating bottom tab bars, sticky headers, and elevated overlays.
class AlphaXGlassBar extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final Color? color;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;

  const AlphaXGlassBar({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.borderRadius,
    this.color,
    this.border,
    this.padding,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(24);
    final effectiveColor = color ??
        (isDark
            ? AppColors.surface.withOpacity(0.85)
            : AppColors.lightSurface.withOpacity(0.85));
    final effectiveBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : AppColors.lightBorder.withOpacity(0.8),
          width: 1.0,
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: radius,
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Subtle breathing aurora mesh gradient for hero cards and stats headers.
class AlphaXAuroraBackground extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  const AlphaXAuroraBackground({
    super.key,
    required this.child,
    this.borderRadius,
  });

  @override
  State<AlphaXAuroraBackground> createState() => _AlphaXAuroraBackgroundState();
}

class _AlphaXAuroraBackgroundState extends State<AlphaXAuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (!_isTestEnvironment) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(24);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + progress * 0.4, -1.0 + progress * 0.4),
              end: Alignment(1.0 - progress * 0.4, 1.0 - progress * 0.4),
              colors: [
                AppColors.primary.withOpacity(0.18 + progress * 0.08),
                AppColors.surface,
                AppColors.secondary.withOpacity(0.12 + (1.0 - progress) * 0.08),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Animated Streak Flame with scale pulse and neon lime glow
class AlphaXStreakFlame extends StatefulWidget {
  final int streakDays;
  final double size;

  const AlphaXStreakFlame({
    super.key,
    required this.streakDays,
    this.size = 20.0,
  });

  @override
  State<AlphaXStreakFlame> createState() => _AlphaXStreakFlameState();
}

class _AlphaXStreakFlameState extends State<AlphaXStreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flameController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_isTestEnvironment) {
      _flameController.repeat(reverse: true);
    } else {
      _flameController.value = 0.5;
    }

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.10).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          Icons.local_fire_department_rounded,
          color: AppColors.primary,
          size: widget.size,
        ),
      ),
    );
  }
}

/// 60fps Skeleton Shimmer Loader for modern loading states
class AlphaXShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AlphaXShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  @override
  State<AlphaXShimmer> createState() => _AlphaXShimmerState();
}

class _AlphaXShimmerState extends State<AlphaXShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!_isTestEnvironment) {
      _shimmerController.repeat();
    } else {
      _shimmerController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.surfaceElevated : AppColors.lightBorder;
    final highlightColor = isDark
        ? AppColors.surfaceCard.withOpacity(0.9)
        : Colors.white.withOpacity(0.7);

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value.clamp(0.0, 1.0),
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Celebration confetti burst overlay for workouts, personal records, and goal achievement
class AlphaXCelebrationBurst {
  static void show(BuildContext context, {String message = 'NEW PERSONAL RECORD!'}) {
    AlphaXHaptics.celebrate();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _CelebrationBurstWidget(
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _CelebrationBurstWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _CelebrationBurstWidget({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_CelebrationBurstWidget> createState() => _CelebrationBurstWidgetState();
}

class _CelebrationBurstWidgetState extends State<_CelebrationBurstWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    for (int i = 0; i < 40; i++) {
      _particles.add(
        _ConfettiParticle(
          angle: _random.nextDouble() * 2 * math.pi,
          distance: 60 + _random.nextDouble() * 160,
          size: 6 + _random.nextDouble() * 8,
          color: [
            AppColors.primary,
            AppColors.secondary,
            AppColors.success,
            Colors.white,
          ][_random.nextInt(4)],
        ),
      );
    }

    _controller.forward().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final opacity = (1.0 - t).clamp(0.0, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                ..._particles.map((p) {
                  final currentDist = p.distance * Curves.easeOutCubic.transform(t);
                  final dx = math.cos(p.angle) * currentDist;
                  final dy = math.sin(p.angle) * currentDist + (t * 80); // gravity
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: p.size,
                        height: p.size,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: p.color.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // Celebration Badge Card
                Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: 0.8 + Curves.easeOutBack.transform(t.clamp(0.0, 0.4) / 0.4) * 0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.glow,
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            widget.message,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _ConfettiParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}
