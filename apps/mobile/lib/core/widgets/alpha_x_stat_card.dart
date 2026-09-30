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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AlphaXRadius.roundedMd,
        child: Container(
          padding: const EdgeInsets.all(AlphaXSpacing.md),
          decoration: BoxDecoration(
            color: AlphaXColors.surfaceCard,
            borderRadius: AlphaXRadius.roundedMd,
            border: Border.all(color: AlphaXColors.border, width: 1.0),
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
                    style: const TextStyle(
                      color: AlphaXColors.textSecondary,
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
                style: const TextStyle(
                  color: AlphaXColors.textPrimary,
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
                    color: AlphaXColors.textTertiary,
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
