import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Athletic Premium Bottom Sheet Modal Component
/// Rounded top 24, grabber handle, surface background, accessible touch targets.
class AlphaXBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceElevated : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;
    final primaryTextColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    double dragStartX = 0;

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: surfaceColor,
      barrierColor: Colors.black.withOpacity(0.7),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) {
            dragStartX = details.globalPosition.dx;
          },
          onHorizontalDragEnd: (details) {
            final screenWidth = MediaQuery.of(ctx).size.width;
            final isLeftEdge = dragStartX <= 60 && (details.primaryVelocity ?? 0) > 150;
            final isRightEdge = dragStartX >= (screenWidth - 60) && (details.primaryVelocity ?? 0) < -150;
            if (isLeftEdge || isRightEdge) {
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
                  // Grabber handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.border : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(3),
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
                            style: TextStyle(
                              fontFamily: 'Sora',
                              color: primaryTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: secondaryTextColor,
                              size: 22,
                            ),
                            tooltip: 'Close',
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
