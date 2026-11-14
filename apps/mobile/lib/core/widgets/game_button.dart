import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual style variants for [GameButton]
enum GameButtonType {
  /// Gold / Amber neon accent — ideal for primary hero actions like "START WORKOUT"
  primary,

  /// Silver / Liquid Steel accent — for secondary actions, settings, or filters
  secondary,

  /// Neon Crimson accent — for high-stakes actions like "END WORKOUT", "CANCEL", "DELETE"
  danger,

  /// Neon Emerald accent — for positive milestones like "COMPLETE SET", "SAVE WORKOUT"
  success,
}

/// A chunky 3D "arcade" styled push button designed for gym & workout tracking apps.
///
/// Features:
/// - Raised 3D base layer with visible bottom bevel depth.
/// - Dark brushed black-to-silver metallic face gradient.
/// - Glossy polycarbonate highlight strip along the top edge.
/// - Tactile mechanical sink on press with smooth elastic spring release ([Curves.elasticOut]).
/// - Medium impact haptic feedback on touch.
/// - Pulsing neon glow border and ground shadow.
/// - Optional sweeping light shine animation ([showShine]).
/// - Optional floating corner badge ([badgeText]) for gamification XP, streaks, or level badges.
/// - Seamless loading state ([isLoading]) and disabled state.
class GameButton extends StatefulWidget {
  /// The uppercase text label displayed inside the button face.
  final String label;

  /// Callback when button is tapped. When null, the button enters the disabled state.
  final VoidCallback? onPressed;

  /// Optional leading icon displayed inside a glowing circular badge.
  final IconData? icon;

  /// Optional trailing icon displayed after the label.
  final IconData? trailingIcon;

  /// Color palette variant preset. Defaults to [GameButtonType.primary].
  final GameButtonType type;

  /// Button width. If null, fills the available horizontal space ([double.infinity]).
  final double? width;

  /// Total button height including the 3D raised bottom edge. Defaults to 56.0.
  final double height;

  /// Corner radius of the button. Defaults to 20.0 for Alpha X Gym design system.
  final double borderRadius;

  /// Optional top-right floating corner badge text (e.g. "+15 XP", "NEW", "2X").
  final String? badgeText;

  /// When true, a light beam sweeps diagonally across the button face periodically.
  final bool showShine;

  /// When true, displays a glowing spinner instead of the button text and icon.
  final bool isLoading;

  /// Optional accent color override to customize neon colors (e.g. Electric Cyan).
  final Color? accentColorOverride;

  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.type = GameButtonType.primary,
    this.width,
    this.height = 56.0,
    this.borderRadius = 20.0,
    this.badgeText,
    this.showShine = false,
    this.isLoading = false,
    this.accentColorOverride,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> with TickerProviderStateMixin {
  /// 3D press depression & bounce controller
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _sinkAnimation;

  /// Ambient neon glow pulse controller
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  /// Periodic shine sweep controller
  late final AnimationController _shineController;
  late final Animation<double> _shineAnimation;

  /// Depth of the 3D raised bottom edge (in logical pixels)
  static const double _depth = 5.0;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();

    // 1. Press & Spring Bounce Setup
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 380),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );

    _sinkAnimation = Tween<double>(begin: 0.0, end: _depth * 0.75).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );

    // 2. Soft Neon Pulse Setup (1600ms breathing cycle)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOutSine,
      ),
    );

    if (_isEnabled) {
      _glowController.repeat(reverse: true);
    }

    // 3. Periodic Shine Sweep Setup (3200ms total cycle, active for first 45%)
    _shineController = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    );

    _shineAnimation = Tween<double>(begin: -1.4, end: 2.2).animate(
      CurvedAnimation(
        parent: _shineController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeInOutCubic),
      ),
    );

    if (widget.showShine && _isEnabled) {
      _shineController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GameButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync glow controller with enabled state
    if (_isEnabled && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!_isEnabled && _glowController.isAnimating) {
      _glowController.stop();
    }

    // Sync shine controller with showShine flag & enabled state
    if (widget.showShine && _isEnabled) {
      if (!_shineController.isAnimating) {
        _shineController.repeat();
      }
    } else {
      if (_shineController.isAnimating) {
        _shineController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _glowController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  /// Resolve primary accent color based on variant enum and custom override
  Color _resolveAccentColor() {
    if (widget.accentColorOverride != null) {
      return widget.accentColorOverride!;
    }
    switch (widget.type) {
      case GameButtonType.primary:
        return const Color(0xFFFFB020); // Electric Gold / Amber
      case GameButtonType.secondary:
        return const Color(0xFFD1D5DB); // Polished Steel / Silver
      case GameButtonType.danger:
        return const Color(0xFFFF334B); // Neon Crimson
      case GameButtonType.success:
        return const Color(0xFF00E676); // Neon Emerald
    }
  }

  /// Compute darker base edge bevel color from accent color
  Color _resolveBaseColor(Color accent) {
    switch (widget.type) {
      case GameButtonType.primary:
        if (widget.accentColorOverride != null) {
          return _darken(accent, 0.42);
        }
        return const Color(0xFF785100);
      case GameButtonType.secondary:
        if (widget.accentColorOverride != null) {
          return _darken(accent, 0.35);
        }
        return const Color(0xFF22262E);
      case GameButtonType.danger:
        if (widget.accentColorOverride != null) {
          return _darken(accent, 0.38);
        }
        return const Color(0xFF7A0B1A);
      case GameButtonType.success:
        if (widget.accentColorOverride != null) {
          return _darken(accent, 0.38);
        }
        return const Color(0xFF065F46);
    }
  }

  Color _darken(Color c, double factor) {
    final hsl = HSLColor.fromColor(c);
    final darkened = hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.mediumImpact();
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _resolveAccentColor();
    final baseEdgeColor = _resolveBaseColor(accentColor);
    final borderRadius = BorderRadius.circular(widget.borderRadius);
    final faceHeight = (widget.height - _depth).clamp(32.0, 200.0);

    return RepaintBoundary(
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height,
        child: GestureDetector(
          onTapDown: _isEnabled ? _handleTapDown : null,
          onTapUp: _isEnabled ? _handleTapUp : null,
          onTapCancel: _isEnabled ? _handleTapCancel : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pressController, _glowController]),
            builder: (context, _) {
              final scale = _scaleAnimation.value;
              final sink = _sinkAnimation.value;
              final glow = _glowAnimation.value;

              return Transform.scale(
                scale: scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // =========================================================
                    // 1. BASE LAYER: 3D Raised Edge & Ambient Ground Glow
                    // =========================================================
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: faceHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isEnabled ? baseEdgeColor : const Color(0xFF1B1B1E),
                          borderRadius: borderRadius,
                          border: Border.all(
                            color: _isEnabled
                                ? accentColor.withOpacity(0.35)
                                : const Color(0xFF28282C),
                            width: 1.0,
                          ),
                          boxShadow: _isEnabled
                              ? [
                                  // Heavy bottom drop shadow
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.65),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                  // Soft pulsing neon ground glow
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.30 * glow),
                                    blurRadius: 14 + (6 * glow),
                                    spreadRadius: 1.0,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                      ),
                    ),

                    // =========================================================
                    // 2. FACE PLATE: Sinking Metallic Button Plate
                    // =========================================================
                    Positioned(
                      left: 0,
                      right: 0,
                      top: sink,
                      height: faceHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _isEnabled
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2F3036), // Brushed silver-black highlight
                                    Color(0xFF1D1E22), // Deep charcoal midtone
                                    Color(0xFF121316), // Obsidian base
                                    Color(0xFF1B1C20), // Subtle reflection return
                                  ],
                                  stops: [0.0, 0.38, 0.72, 1.0],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF242428), Color(0xFF18181A)],
                                ),
                          borderRadius: borderRadius,
                          border: Border.all(
                            color: _isEnabled
                                ? accentColor.withOpacity(0.55 + (0.35 * glow))
                                : const Color(0xFF333338),
                            width: 1.4,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: borderRadius,
                          child: Stack(
                            children: [
                              // -----------------------------------------------
                              // Top Glossy Highlight Strip
                              // -----------------------------------------------
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: faceHeight * 0.44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(_isEnabled ? 0.20 : 0.06),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // -----------------------------------------------
                              // Animated Diagonal Light Sweep (Shine)
                              // -----------------------------------------------
                              if (widget.showShine && _isEnabled)
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _shineAnimation,
                                    builder: (context, _) {
                                      final val = _shineAnimation.value;
                                      if (val <= -1.4 || val >= 1.8) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment(val - 0.45, -1.0),
                                            end: Alignment(val + 0.45, 1.0),
                                            colors: [
                                              Colors.transparent,
                                              Colors.white.withOpacity(0.24),
                                              Colors.transparent,
                                            ],
                                            stops: const [0.0, 0.5, 1.0],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              // -----------------------------------------------
                              // Content: Icon + Uppercase Label / Loading Spinner
                              // -----------------------------------------------
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: widget.isLoading
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Circular Badge Icon
                                            if (widget.icon != null) ...[
                                              Container(
                                                width: 28,
                                                height: 28,
                                                margin: const EdgeInsets.only(right: 10),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: _isEnabled
                                                      ? accentColor.withOpacity(0.18)
                                                      : Colors.white.withOpacity(0.05),
                                                  border: Border.all(
                                                    color: _isEnabled
                                                        ? accentColor.withOpacity(0.55)
                                                        : Colors.white.withOpacity(0.12),
                                                    width: 1.2,
                                                  ),
                                                  boxShadow: _isEnabled
                                                      ? [
                                                          BoxShadow(
                                                            color: accentColor.withOpacity(0.35),
                                                            blurRadius: 6,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Icon(
                                                  widget.icon,
                                                  size: 15,
                                                  color: _isEnabled
                                                      ? accentColor
                                                      : const Color(0xFF77777E),
                                                ),
                                              ),
                                            ],

                                            // Uppercase Poppins Label
                                            Flexible(
                                              child: Text(
                                                widget.label.toUpperCase(),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.2,
                                                  color: _isEnabled
                                                      ? Colors.white
                                                      : const Color(0xFF77777E),
                                                  shadows: _isEnabled
                                                      ? [
                                                          Shadow(
                                                            color: Colors.black.withOpacity(0.85),
                                                            offset: const Offset(0, 1.5),
                                                            blurRadius: 3,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                              ),
                                            ),

                                            // Optional Trailing Icon
                                            if (widget.trailingIcon != null) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                widget.trailingIcon,
                                                size: 16,
                                                color: _isEnabled
                                                    ? accentColor
                                                    : const Color(0xFF77777E),
                                              ),
                                            ],
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // =========================================================
                    // 3. CORNER BADGE: Floating Game Badge (e.g. "+15 XP")
                    // =========================================================
                    if (widget.badgeText != null && widget.badgeText!.trim().isNotEmpty)
                      Positioned(
                        top: -5,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: _isEnabled
                                ? LinearGradient(
                                    colors: [
                                      accentColor,
                                      Color.lerp(accentColor, Colors.white, 0.28)!,
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF52525A), Color(0xFF38383E)],
                                  ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(_isEnabled ? 0.75 : 0.2),
                              width: 1,
                            ),
                            boxShadow: _isEnabled
                                ? [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.6),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            widget.badgeText!.trim().toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: _isEnabled ? Colors.black : const Color(0xFF9E9EA8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

