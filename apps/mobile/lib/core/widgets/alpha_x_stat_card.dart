import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';

class AlphaXStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtext;
  final Color? accentColor;
  final VoidCallback? onTap;

  const AlphaXStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtext,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = accentColor ?? AlphaXColors.redAccent;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardTheme.color ?? AlphaXColors.surfaceCard;
    final borderColor = theme.dividerTheme.color ?? AlphaXColors.border;
    final primaryTextColor = isDark ? AlphaXColors.textPrimary : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AlphaXColors.textSecondary : const Color(0xFF4B5563);
    final tertiaryTextColor = isDark ? AlphaXColors.textTertiary : const Color(0xFF9CA3AF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AlphaXRadius.roundedMd,
        child: Container(
          padding: const EdgeInsets.all(AlphaXSpacing.md),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: AlphaXRadius.roundedMd,
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
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
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Icon(
                    icon,
                    size: 16,
                    color: effectiveColor.withValues(alpha: 0.85),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtext != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtext!,
                  style: TextStyle(
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
      ),
    );
  }
}
