import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium micro-interaction wrapper for Alpha X Gym.
///
/// Provides a subtle physical scale feedback (1.0 -> 0.97 -> 1.0)
/// on pointer down and release, paired with optional subtle haptic feedback.
class AlphaXPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  const AlphaXPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.97,
    this.duration = const Duration(milliseconds: 110),
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<AlphaXPressable> createState() => _AlphaXPressableState();
}

class _AlphaXPressableState extends State<AlphaXPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
      value: 1.0,
      lowerBound: widget.scaleFactor,
      upperBound: 1.0,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.animateTo(widget.scaleFactor);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.animateTo(1.0);
  }

  void _onTapCancel() {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null || widget.onLongPress != null;

    return MouseRegion(
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: isClickable ? _onTapDown : null,
        onTapUp: isClickable ? _onTapUp : null,
        onTapCancel: isClickable ? _onTapCancel : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
