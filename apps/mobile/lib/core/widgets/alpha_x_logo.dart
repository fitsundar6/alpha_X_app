import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// The official Alpha X Gym brand logo widget.
///
/// Strictly preserves original proportions, transparency, and design.
/// Supports responsive sizing, subtle optional gold glow effects, and standard app bar sizing.
class AlphaXLogo extends StatelessWidget {
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final bool withGlow;
  final Color? glowColor;
  final double glowRadius;
  final EdgeInsetsGeometry padding;

  const AlphaXLogo({
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.withGlow = false,
    this.glowColor,
    this.glowRadius = 24.0,
    this.padding = EdgeInsets.zero,
  });

  /// Standard compact logo for AppBars and navigation headers
  const AlphaXLogo.appBar({
    super.key,
    this.size = 32.0,
    this.fit = BoxFit.contain,
    this.color,
    this.withGlow = false,
    this.glowColor,
    this.glowRadius = 12.0,
    this.padding = EdgeInsets.zero,
  })  : width = size,
        height = size;

  /// Large hero logo for Splash and Welcome screens
  const AlphaXLogo.splash({
    super.key,
    this.size = 140.0,
    this.fit = BoxFit.contain,
    this.color,
    this.withGlow = false,
    this.glowColor,
    this.glowRadius = 32.0,
    this.padding = EdgeInsets.zero,
  })  : width = size,
        height = size;

  /// Medium logo for Authentication and Login screens
  const AlphaXLogo.auth({
    super.key,
    this.size = 100.0,
    this.fit = BoxFit.contain,
    this.color,
    this.withGlow = false,
    this.glowColor,
    this.glowRadius = 20.0,
    this.padding = EdgeInsets.zero,
  })  : width = size,
        height = size;

  /// Small badge logo for cards and list tiles
  const AlphaXLogo.badge({
    super.key,
    this.size = 22.0,
    this.fit = BoxFit.contain,
    this.color,
    this.withGlow = false,
    this.glowColor,
    this.glowRadius = 8.0,
    this.padding = EdgeInsets.zero,
  })  : width = size,
        height = size;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? null : AppColors.lightTextPrimary);
    final effectiveGlowColor = glowColor ?? (isDark ? AppColors.glow : AppColors.lightGlow);

    Widget imageWidget = Image.asset(
      AppConstants.logoPath,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: fit,
      color: effectiveColor,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      semanticLabel: AppConstants.appName,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: Center(
            child: Icon(
              Icons.fitness_center_rounded,
              color: isDark ? AppColors.primary : AppColors.lightPrimary,
            ),
          ),
        );
      },
    );

    if (withGlow && effectiveWidth != null && effectiveHeight != null) {
      imageWidget = Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: effectiveWidth * 1.25,
            height: effectiveHeight * 1.25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  effectiveGlowColor.withOpacity(0.36),
                  effectiveGlowColor.withOpacity(0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          imageWidget,
        ],
      );
    }

    if (padding != EdgeInsets.zero) {
      imageWidget = Padding(
        padding: padding,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Standardized Brand Header showing the official Alpha X Gym Logo
/// together with bold typography and optional tag/subtitle.
class AlphaXBrandHeader extends StatelessWidget {
  final double logoSize;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final CrossAxisAlignment crossAxisAlignment;

  const AlphaXBrandHeader({
    super.key,
    this.logoSize = 32.0,
    this.title = 'ALPHA X GYM',
    this.subtitle,
    this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        AlphaXLogo(
          size: logoSize,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
