import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';
import '../theme/app_colors.dart';
import 'alpha_x_pressable.dart';

enum AlphaXButtonVariant { primary, secondary, text }

/// Athletic Premium Button Component
/// Primary: Electric Lime Pill + Dark Text (#0A0B0D) + Lime Glow
/// Secondary: Outlined Pill
class AlphaXButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AlphaXButtonVariant variant;
  final bool isFullWidth;
  final bool isLoading;
  final double height;
  final double? width;

  const AlphaXButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AlphaXButtonVariant.primary,
    this.isFullWidth = true,
    this.isLoading = false,
    this.height = 52.0,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = isFullWidth ? double.infinity : width;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget childWidget;
    if (isLoading) {
      childWidget = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AlphaXButtonVariant.primary
                ? AppColors.onPrimary
                : (isDark ? Colors.white : AppColors.lightTextPrimary),
          ),
        ),
      );
    } else if (icon != null) {
      childWidget = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.1,
              color: variant == AlphaXButtonVariant.primary
                  ? AppColors.onPrimary
                  : null,
            ),
          ),
        ],
      );
    } else {
      childWidget = Text(
        label.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.1,
          color: variant == AlphaXButtonVariant.primary
              ? AppColors.onPrimary
              : null,
        ),
      );
    }

    Widget buttonWidget;

    if (variant == AlphaXButtonVariant.secondary) {
      buttonWidget = OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(
            color: isDark ? AppColors.border : AppColors.lightBorder,
            width: 1.5,
          ),
          shape: const StadiumBorder(), // Pill button
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      );
    } else if (variant == AlphaXButtonVariant.text) {
      buttonWidget = TextButton(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.primary : AppColors.lightPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      );
    } else {
      // Primary Lime Pill CTA Button with vibrant glow
      final primaryColor = isDark ? AppColors.primary : AppColors.lightPrimary;
      final glowColor = isDark ? AppColors.glow : const Color(0x334AD400);

      buttonWidget = Container(
        decoration: BoxDecoration(
          borderRadius: AlphaXRadius.roundedFull,
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: AppColors.onPrimary, // Dark text #0A0B0D on lime
            elevation: 0,
            shape: const StadiumBorder(), // Pill button
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          onPressed: isLoading ? null : onPressed,
          child: childWidget,
        ),
      );
    }

    return SizedBox(
      width: effectiveWidth,
      height: height,
      child: AlphaXPressable(
        onTap: isLoading ? null : onPressed,
        child: buttonWidget,
      ),
    );
  }
}
