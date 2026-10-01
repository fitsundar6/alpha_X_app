import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';

class AlphaXCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AlphaXCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AlphaXSpacing.md),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBorderRadius = borderRadius ?? AlphaXRadius.roundedMd;

    final cardContent = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardTheme.color ?? AlphaXColors.surfaceCard,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: borderColor ?? theme.dividerTheme.color ?? AlphaXColors.border,
          width: 1.0,
        ),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
