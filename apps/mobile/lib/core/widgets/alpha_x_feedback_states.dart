import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/alpha_x_design_system.dart';
import '../theme/app_colors.dart';
import 'alpha_x_button.dart';
import 'alpha_x_logo.dart';
import 'alpha_x_pressable.dart';

/// Premium dark empty-state widget for Alpha X Gym.
class AlphaXEmptyState extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AlphaXEmptyState({
    super.key,
    this.icon,
    this.customIcon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AlphaXColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AlphaXColors.border, width: 1.0),
              ),
              child: Center(
                child: customIcon ??
                    Icon(
                      icon ?? Icons.fitness_center_outlined,
                      color: AlphaXColors.textSecondary,
                      size: 28,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                description,
                style: const TextStyle(
                  color: AlphaXColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              AlphaXButton(
                label: actionLabel!,
                onPressed: onAction!,
                isFullWidth: false,
                height: 44,
                variant: AlphaXButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Premium dark error card for non-distracting user-friendly error recovery.
class AlphaXErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AlphaXErrorCard({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: AlphaXRadius.roundedMd,
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connection Notice',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AlphaXColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            AlphaXPressable(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AlphaXColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AlphaXColors.border),
                ),
                child: Text(
                  retryLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer skeleton placeholder for smooth loading transitions.
class AlphaXSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const AlphaXSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<AlphaXSkeleton> createState() => _AlphaXSkeletonState();
}

class _AlphaXSkeletonState extends State<AlphaXSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _shimmerController.repeat(reverse: true);
    } else {
      _shimmerController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.4 + (_shimmerController.value * 0.4);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.fromRGBO(30, 30, 32, opacity),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            border: Border.all(
              color: Color.fromRGBO(40, 40, 44, opacity * 0.6),
              width: 1.0,
            ),
          ),
        );
      },
    );
  }
}

/// Athletic pulsing logo loader.
class AlphaXLoadingIndicator extends StatelessWidget {
  final double size;

  const AlphaXLoadingIndicator({super.key, this.size = 36.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AlphaXColors.redAccent),
                backgroundColor: AlphaXColors.surfaceElevated,
              ),
            ),
            AlphaXLogo(size: size * 0.45),
          ],
        ),
      ),
    );
  }
}
