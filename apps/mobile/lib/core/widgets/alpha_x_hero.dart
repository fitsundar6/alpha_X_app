import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';

class AlphaXHero extends StatelessWidget {
  final String imageUrl;
  final String? tag;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double height;
  final Widget? trailingBadge;

  const AlphaXHero({
    super.key,
    required this.imageUrl,
    this.tag,
    required this.title,
    this.subtitle,
    this.action,
    this.height = 320.0,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: AlphaXRadius.roundedXl,
        border: Border.all(color: AlphaXColors.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gym Image with Fallback
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.35),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E1E1E),
                      Color(0xFF101010),
                      Color(0xFF050505),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: AlphaXColors.surfaceCard,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AlphaXColors.redAccent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            },
          ),

          // Cinematic Dark Gradient Overlay (blends image naturally into pure black background)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.55),
                  AlphaXColors.background.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Content Layer: Tag + Title + Subtitle + Action
          Padding(
            padding: const EdgeInsets.all(AlphaXSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (tag != null || trailingBadge != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AlphaXSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AlphaXColors.redAccent.withValues(alpha: 0.18),
                              borderRadius: AlphaXRadius.roundedXs,
                              border: Border.all(
                                color: AlphaXColors.redAccent.withValues(alpha: 0.5),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AlphaXColors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tag!.toUpperCase(),
                                  style: AlphaXTypography.tag,
                                ),
                              ],
                            ),
                          ),
                        if (trailingBadge != null) ...[trailingBadge!],
                      ],
                    ),
                  ),
                Text(
                  title,
                  style: AlphaXTypography.displayMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AlphaXSpacing.xs),
                  Text(
                    subtitle!,
                    style: AlphaXTypography.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AlphaXSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
