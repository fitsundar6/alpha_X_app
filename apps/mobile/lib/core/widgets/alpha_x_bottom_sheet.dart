import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';

class AlphaXBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.bottomSheetTheme.backgroundColor ?? theme.cardTheme.color ?? AlphaXColors.surfaceCard;
    final borderColor = theme.dividerTheme.color ?? AlphaXColors.border;
    final primaryTextColor = isDark ? AlphaXColors.textPrimary : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AlphaXColors.textSecondary : const Color(0xFF4B5563);

    double dragStartX = 0;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: surfaceColor,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) {
            dragStartX = details.globalPosition.dx;
          },
          onHorizontalDragEnd: (details) {
            if (dragStartX <= 60 && (details.primaryVelocity ?? 0) > 150) {
              Navigator.pop(ctx);
            }
          },
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: AlphaXTypography.headlineMedium.copyWith(color: primaryTextColor),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: secondaryTextColor,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}
