import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';
import '../theme/app_colors.dart';
import '../theme/alpha_x_motion.dart';
import 'alpha_x_pressable.dart';

/// Athletic Premium Stat Card Component
/// Big bold stat number (Sora), label, icon, and optional mini ring/progress.
class AlphaXStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtext;
  final Color? accentColor;
  final VoidCallback? onTap;
  final double? progress; // 0.0 to 1.0 for mini progress ring

  const AlphaXStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtext,
    this.accentColor,
    this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = accentColor ?? (isDark ? AppColors.primary : AppColors.lightPrimary);
    final surfaceColor = isDark ? AppColors.surfaceCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;
    final primaryTextColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final tertiaryTextColor = isDark ? AppColors.textTertiary : AppColors.lightTextMuted;

    return AlphaXPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AlphaXSpacing.md),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: secondaryTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress != null)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progress!.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedProgress, child) {
                      return SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          value: animatedProgress,
                          strokeWidth: 3.0,
                          backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.lightBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: effectiveColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: effectiveColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            AlphaXCountUpText(
              text: value,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: primaryTextColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext!,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: tertiaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
