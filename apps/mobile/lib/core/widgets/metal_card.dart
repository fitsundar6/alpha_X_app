import 'package:flutter/material.dart';

/// Reusable metallic card component for Alpha X Gym.
///
/// Implements the executive dark luxury design system:
/// - Brushed black-to-silver diagonal gradient
/// - Thin semi-transparent silver border (1.0px)
/// - 20px rounded corners (default)
/// - Controlled subtle drop shadow
/// - Optional [isSubtle] flag for restrained gradient on compact stat tiles & banners
/// - Optional [glowColor] for active/hero states
class MetalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool isSubtle;
  final Color? glowColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  const MetalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.borderRadius,
    this.isSubtle = false,
    this.glowColor,
    this.onTap,
    this.width,
    this.height,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);

    // Full metallic vs subtle metallic gradients
    final gradient = isSubtle
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF222328), // Subtle steel
              Color(0xFF131417), // Deep charcoal
            ],
            stops: [0.0, 1.0],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D2E34), // Brushed silver reflection
              Color(0xFF1B1C20), // Charcoal midtone
              Color(0xFF111215), // Deep obsidian
              Color(0xFF18191D), // Subtle metallic return
            ],
            stops: [0.0, 0.35, 0.72, 1.0],
          );

    final borderColor = isSubtle
        ? const Color(0x28A0A5B2) // Restrained silver border
        : (glowColor != null
            ? glowColor!.withOpacity(0.55)
            : const Color(0x3DF1F5F9)); // Thin crisp silver border

    final cardContent = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withOpacity(0.2),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

