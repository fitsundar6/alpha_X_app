import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/workout_summary_models.dart';

/// Renders the FRONT and BACK anatomical figures side-by-side using vector SVGs.
/// Dynamically updates the SVG markup so trained muscle paths reflect their
/// computed orange/amber highlight colors, while untrained muscles remain #3A3A3A.
class MuscleBodyWidget extends StatefulWidget {
  final List<MuscleActivation> activations;
  final double height;
  final bool animateEntry;

  const MuscleBodyWidget({
    super.key,
    required this.activations,
    this.height = 230,
    this.animateEntry = true,
  });

  @override
  State<MuscleBodyWidget> createState() => _MuscleBodyWidgetState();
}

class _MuscleBodyWidgetState extends State<MuscleBodyWidget>
    with SingleTickerProviderStateMixin {
  static String? _cachedFrontSvg;
  static String? _cachedBackSvg;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _loadSvgAssets();
  }

  @override
  void didUpdateWidget(covariant MuscleBodyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activations != widget.activations) {
      if (widget.animateEntry) {
        _animController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSvgAssets() async {
    try {
      _cachedFrontSvg ??= await rootBundle.loadString('assets/svg/body_front.svg');
      _cachedBackSvg ??= await rootBundle.loadString('assets/svg/body_back.svg');
    } catch (e) {
      debugPrint('[MuscleBodyWidget] Error loading SVG assets: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (widget.animateEntry) {
          _animController.forward();
        } else {
          _animController.value = 1.0;
        }
      }
    }
  }

  /// Replaces the fill of each trained muscle path with its animated color.
  String _colorizeSvg(String rawSvg, double animationProgress) {
    if (rawSvg.isEmpty) return rawSvg;

    var result = rawSvg;
    for (final act in widget.activations) {
      final targetColor = act.color;
      final currentColor = Color.lerp(
        const Color(0xFF3A3A3A),
        targetColor,
        animationProgress,
      )!;

      final hex =
          '#${currentColor.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';

      // Replace fill attribute for path or group with id matching muscleId
      final regex1 = RegExp(
          '(<(?:path|g)[^>]*id=["\']${RegExp.escape(act.muscleId)}["\'][^>]*fill=["\'])#[0-9a-fA-F]{3,8}(["\'])');
      if (regex1.hasMatch(result)) {
        result = result.replaceAllMapped(
            regex1, (m) => '${m.group(1)}$hex${m.group(2)}');
      } else {
        final regex2 = RegExp(
            '(<(?:path|g)[^>]*fill=["\'])#[0-9a-fA-F]{3,8}(["\'][^>]*id=["\']${RegExp.escape(act.muscleId)}["\'])');
        if (regex2.hasMatch(result)) {
          result = result.replaceAllMapped(
              regex2, (m) => '${m.group(1)}$hex${m.group(2)}');
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFFC400),
            ),
          ),
        ),
      );
    }

    final frontSvgRaw = _cachedFrontSvg ?? '';
    final backSvgRaw = _cachedBackSvg ?? '';

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, _) {
        final frontSvg = _colorizeSvg(frontSvgRaw, _fadeAnimation.value);
        final backSvg = _colorizeSvg(backSvgRaw, _fadeAnimation.value);

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FRONT VIEW
              Flexible(
                child: AspectRatio(
                  aspectRatio: 380 / 580,
                  child: SvgPicture.string(
                    frontSvg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // BACK VIEW
              Flexible(
                child: AspectRatio(
                  aspectRatio: 380 / 580,
                  child: SvgPicture.string(
                    backSvg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
