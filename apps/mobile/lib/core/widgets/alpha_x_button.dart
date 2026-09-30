import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';
import 'alpha_x_pressable.dart';

enum AlphaXButtonVariant { primary, secondary, text }

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

    Widget childWidget;
    if (isLoading) {
      childWidget = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );
    } else {
      childWidget = Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      );
    }

    Widget buttonWidget;

    if (variant == AlphaXButtonVariant.secondary) {
      buttonWidget = OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AlphaXColors.textPrimary,
          side: const BorderSide(color: AlphaXColors.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: AlphaXRadius.roundedMd),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      );
    } else if (variant == AlphaXButtonVariant.text) {
      buttonWidget = TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AlphaXColors.redAccent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      );
    } else {
      // Primary Red CTA Button
      buttonWidget = ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AlphaXColors.redAccent,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AlphaXColors.redAccent.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: AlphaXRadius.roundedMd),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
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
