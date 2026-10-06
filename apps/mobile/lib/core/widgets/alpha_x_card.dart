import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Alpha X Gym - Card Component
/// Dark: Dark charcoal cards (#151515) with subtle borders (#2A2A2A)
/// Light: White cards (#FFFFFF) with subtle borders (#E2E2DE)
/// Corner radius: 14–18 px, controlled subtle shadows
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
  final bool hasGlow;

  const AlphaXCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(18);

    final cardContent = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? AppColors.surfaceCard : AppColors.lightSurfaceCard),
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: borderColor ?? (isDark ? AppColors.border : AppColors.lightBorder),
          width: 1.0,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: hasGlow ? AppColors.glow : Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
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
