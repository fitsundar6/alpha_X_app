import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';
import '../theme/app_colors.dart';

/// Athletic Premium Card Component
/// Surface background, radius 24, soft depth (colored subtle glow on dark, soft shadow on light).
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
    this.padding = const EdgeInsets.all(AlphaXSpacing.lg),
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
    final effectiveBorderRadius = borderRadius ?? AlphaXRadius.roundedXl; // Radius 24

    final cardContent = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? AppColors.surfaceCard : AppColors.lightSurface),
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: borderColor ?? (isDark ? AppColors.border : AppColors.lightBorder),
          width: 1.0,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: hasGlow ? AppColors.glow.withOpacity(0.2) : Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06), // soft gray shadow y8 blur24 ~10%
                  blurRadius: 24,
                  offset: const Offset(0, 8),
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
