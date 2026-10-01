import 'package:flutter/material.dart';

/// Lightweight single-pass entrance animation widget for cards, headers, and sections.
/// Uses standard Flutter [TweenAnimationBuilder] which ties directly to the widget tree
/// and frame scheduler without creating asynchronous Dart timers, preventing timer leaks
/// and ensuring optimal 60/120fps performance on mobile, desktop, and web.
class AlphaXSubtleEntrance extends StatelessWidget {
  final Widget child;
  final Duration? delay;
  final Duration duration;
  final double slideOffset;

  const AlphaXSubtleEntrance({
    super.key,
    required this.child,
    this.delay,
    this.duration = const Duration(milliseconds: 400),
    this.slideOffset = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * slideOffset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
