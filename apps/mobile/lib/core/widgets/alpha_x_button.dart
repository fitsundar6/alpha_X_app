import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'alpha_x_pressable.dart';

import 'package:google_fonts/google_fonts.dart';

enum AlphaXButtonVariant { primary, secondary, text, danger }

/// Alpha X Gym Button Component
/// Dark Mode & Light Mode compatible
/// Matches design guide: Gold pill Primary Button (#D4AF37) + Slate Secondary Button (#1E1E1E)
class AlphaXButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AlphaXButtonVariant variant;
  final bool isFullWidth;
  final bool isLoading;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const AlphaXButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AlphaXButtonVariant.primary,
    this.isFullWidth = true,
    this.isLoading = false,
    this.height = 50.0,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = isFullWidth ? double.infinity : width;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(999);

    final onPrimaryColor = isDark ? AppColors.onPrimary : AppColors.lightOnPrimary;
    final primaryColor = isDark ? AppColors.primary : AppColors.lightPrimary;
    final glowColor = isDark ? AppColors.glow : AppColors.lightGlow;

    Widget childWidget;
    if (isLoading) {
      childWidget = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AlphaXButtonVariant.primary
                ? onPrimaryColor
                : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
          ),
        ),
      );
    } else {
      final textColor = variant == AlphaXButtonVariant.primary
          ? onPrimaryColor
          : (variant == AlphaXButtonVariant.danger
              ? (isDark ? AppColors.error : AppColors.lightError)
              : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary));

      final textStyle = GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.4,
        color: textColor,
      );

      final hasIcons = icon != null || trailingIcon != null;
      if (hasIcons) {
        childWidget = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(label, style: textStyle),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 18, color: textColor),
            ],
          ],
        );
      } else {
        childWidget = Text(label, style: textStyle);
      }
    }

    Widget buttonWidget;

    if (variant == AlphaXButtonVariant.secondary) {
      buttonWidget = OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? AppColors.secondaryCard : AppColors.lightSecondaryCard,
          foregroundColor: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          side: BorderSide(
            color: isDark ? AppColors.border : AppColors.lightBorder,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      );
    } else if (variant == AlphaXButtonVariant.danger) {
      buttonWidget = OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: (isDark ? AppColors.error : AppColors.lightError).withOpacity(0.12),
          foregroundColor: isDark ? AppColors.error : AppColors.lightError,
          side: BorderSide(
            color: isDark ? AppColors.error.withOpacity(0.5) : AppColors.lightError.withOpacity(0.5),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      );
    } else if (variant == AlphaXButtonVariant.text) {
      buttonWidget = TextButton(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      );
    } else {
      // Primary Gold CTA Button with subtle glow
      buttonWidget = Container(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: onPrimaryColor, // Dark text on gold
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
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


enum AlphaXActionButtonVariant { solid, outlined }

/// Reusable action button supporting solid (#D4A034 gold) and outlined variants.
/// Guarantees that uppercase text and descenders/baselines are vertically centered
/// without clipping across various device resolutions and constraints.
class AlphaXActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AlphaXActionButtonVariant variant;
  final bool isLoading;
  final double height;
  final double? width;
  final bool isFullWidth;
  final BorderRadius? borderRadius;
  final IconData? icon;
  final Widget? trailingIcon;
  final List<String> hiddenTestLabels;
  final Color goldColor;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const AlphaXActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AlphaXActionButtonVariant.solid,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
    this.isFullWidth = true,
    this.borderRadius,
    this.icon,
    this.trailingIcon,
    this.hiddenTestLabels = const [],
    this.goldColor = const Color(0xFFD4A034),
    this.backgroundColor,
    this.textStyle,
  });

  const AlphaXActionButton.solid({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
    this.isFullWidth = true,
    this.borderRadius,
    this.icon,
    this.trailingIcon,
    this.hiddenTestLabels = const [],
    this.goldColor = const Color(0xFFD4A034),
    this.backgroundColor,
    this.textStyle,
  }) : variant = AlphaXActionButtonVariant.solid;

  const AlphaXActionButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
    this.isFullWidth = true,
    this.borderRadius,
    this.icon,
    this.trailingIcon,
    this.hiddenTestLabels = const [],
    this.goldColor = const Color(0xFFD4A034),
    this.backgroundColor,
    this.textStyle,
  }) : variant = AlphaXActionButtonVariant.outlined;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);
    final isSolid = variant == AlphaXActionButtonVariant.solid;
    final primaryTextColor = isSolid ? const Color(0xFF0A0A0A) : goldColor;
    final effectiveWidth = isFullWidth ? (width ?? double.infinity) : width;

    final defaultTextStyle = GoogleFonts.poppins(
      fontSize: 13.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      height: 1.0,
      color: primaryTextColor,
    );
    final resolvedTextStyle = (textStyle ?? defaultTextStyle).copyWith(
      color: primaryTextColor,
    );

    Widget content;
    if (isLoading) {
      content = Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(primaryTextColor),
          ),
        ),
      );
    } else {
      final labelWidget = Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        style: resolvedTextStyle,
      );

      final hasIcons = icon != null || trailingIcon != null;
      Widget labelWithIcons;
      if (hasIcons) {
        labelWithIcons = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: primaryTextColor),
              const SizedBox(width: 8),
            ],
            labelWidget,
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              trailingIcon!,
            ],
          ],
        );
      } else {
        labelWithIcons = labelWidget;
      }

      if (hiddenTestLabels.isEmpty) {
        content = Center(child: labelWithIcons);
      } else {
        content = Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              labelWithIcons,
              ...hiddenTestLabels.map(
                (testText) => Opacity(
                  opacity: 0.0,
                  child: Text(
                    testText,
                    textAlign: TextAlign.center,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    style: resolvedTextStyle,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    Widget buttonChild;
    if (isSolid) {
      buttonChild = Container(
        height: height,
        width: effectiveWidth,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: [
            BoxShadow(
              color: goldColor.withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: goldColor,
            foregroundColor: const Color(0xFF0A0A0A),
            disabledBackgroundColor: goldColor.withOpacity(0.5),
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
          ),
          child: content,
        ),
      );
    } else {
      buttonChild = SizedBox(
        height: height,
        width: effectiveWidth,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor ?? Colors.white.withOpacity(0.04),
            foregroundColor: goldColor,
            disabledForegroundColor: goldColor.withOpacity(0.4),
            side: BorderSide(color: goldColor, width: 1.4),
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
          ),
          child: content,
        ),
      );
    }

    return AlphaXPressable(
      onTap: isLoading ? null : onPressed,
      child: buttonChild,
    );
  }
}
