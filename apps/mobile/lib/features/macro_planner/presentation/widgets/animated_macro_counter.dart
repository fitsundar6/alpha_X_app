import 'package:flutter/material.dart';

/// Smooth animated number counter widget for macro values and calories
/// Transitions gracefully between values (e.g. 145g -> 152g) without jarring layout shifts
class AnimatedMacroCounter extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final int decimals;
  final Duration duration;
  final Curve curve;

  const AnimatedMacroCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        final formattedNumber = decimals == 0
            ? animatedValue.round().toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                )
            : animatedValue.toStringAsFixed(decimals);
        return Text(
          '$prefix$formattedNumber$suffix',
          style: style,
        );
      },
    );
  }
}
