import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'alpha_x_logo.dart';

/// Theme-aware AppBar for Alpha X Gym
class AlphaXAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showLogo;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const AlphaXAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showLogo = false,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation = 0,
    this.bottom,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AppColors.background : AppColors.lightBackground);
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    Widget? effectiveTitle = titleWidget;
    if (effectiveTitle == null) {
      if (showLogo) {
        effectiveTitle = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AlphaXLogo(size: 26),
            if (title != null) ...[
              const SizedBox(width: 8),
              Text(
                title!,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ],
        );
      } else if (title != null) {
        effectiveTitle = Text(
          title!,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        );
      }
    }

    return AppBar(
      backgroundColor: bg,
      elevation: elevation,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      iconTheme: IconThemeData(color: textColor),
      title: effectiveTitle,
      actions: actions,
      bottom: bottom,
    );
  }
}
