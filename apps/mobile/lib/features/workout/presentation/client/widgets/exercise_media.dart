import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/exercise/data/exercise_media_mapping.dart';

/// Large, premium media viewer for client exercises.
/// Connects strictly to verified ANIMATED GIF exercise demonstrations.
///
/// CRITICAL REQUIREMENT:
/// ANIMATED GIF ONLY -> NEVER hero images, static photos, or MP4 videos.
///
/// FALLBACK LOGIC:
/// - VALID EXERCISE GIF FOUND -> SHOW THE ANIMATED GIF
/// - NO VALID GIF FOUND -> SHOW "Demonstration unavailable"
/// - ERROR / FAILED LOAD -> SHOW "Unable to load demonstration" WITH RETRY ACTION
/// - NEVER SHOW HERO IMAGE AS DEMONSTRATION
class ExerciseMedia extends StatefulWidget {
  final String exerciseId;
  final String gifUrl;
  final String animationUrl;
  final String imageUrl;
  final String videoUrl;
  final String thumbnailUrl;
  final String exerciseName;
  final String category;
  final String movementPattern;

  const ExerciseMedia({
    super.key,
    this.exerciseId = '',
    this.gifUrl = '',
    this.animationUrl = '',
    this.imageUrl = '',
    this.videoUrl = '',
    this.thumbnailUrl = '',
    required this.exerciseName,
    this.category = '',
    this.movementPattern = '',
  });

  @override
  State<ExerciseMedia> createState() => _ExerciseMediaState();
}

class _ExerciseMediaState extends State<ExerciseMedia> {
  int _retryKey = 0;

  /// Resolves the actual animated GIF demonstration URL belonging specifically to this exercise.
  /// Strict rule: ANIMATED GIF ONLY.
  /// NEVER falls back to hero.jpeg, hero.png, static images, or MP4 videos.
  String get _displayableMediaUrl {
    // 1. Direct explicit gifUrl
    final gif = widget.gifUrl.trim();
    if (ExerciseMediaMapping.isValidGif(gif)) return gif;

    // 2. Direct explicit animationUrl (if it is a valid gif)
    final anim = widget.animationUrl.trim();
    if (ExerciseMediaMapping.isValidGif(anim)) return anim;

    // 3. Media mapping via exerciseId (strict 1:1 mapping)
    if (widget.exerciseId.trim().isNotEmpty) {
      final mapped = ExerciseMediaMapping.getGifForExerciseId(widget.exerciseId);
      if (mapped != null && ExerciseMediaMapping.isValidGif(mapped)) {
        return mapped;
      }
    }

    // 4. Media mapping via exerciseName
    if (widget.exerciseName.trim().isNotEmpty) {
      final mapped = ExerciseMediaMapping.getGifForExerciseName(widget.exerciseName);
      if (mapped != null && ExerciseMediaMapping.isValidGif(mapped)) {
        return mapped;
      }
    }

    // STRICT FALLBACK RULE:
    // If no valid GIF exists -> return empty string (triggers "Demonstration unavailable").
    // NEVER fall back to imageUrl (hero image) or videoUrl.
    return '';
  }

  bool get _hasMedia => _displayableMediaUrl.isNotEmpty;

  void _retryLoading() {
    setState(() {
      _retryKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF111114),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_hasMedia)
              _buildNoDemonstrationAvailableView()
            else
              _buildActualMediaContent(),

            // Top-right animated loop badge (only when real animated GIF is available)
            if (_hasMedia)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.loop,
                        size: 13,
                        color: AppColors.primaryRed,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ANIMATED FORM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActualMediaContent() {
    final url = _displayableMediaUrl;

    // 1. Local Asset GIF
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        key: ValueKey('$url-$_retryKey'),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildUnableToLoadView();
        },
      );
    }

    // 2. Network Animated GIF (animates automatically and loops continuously)
    return Image.network(
      url,
      key: ValueKey('$url-$_retryKey'),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final expected = loadingProgress.expectedTotalBytes;
        final loaded = loadingProgress.cumulativeBytesLoaded;
        final progress = (expected != null && expected > 0) ? (loaded / expected) : null;

        return _buildLoadingState(progress);
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildUnableToLoadView();
      },
    );
  }

  /// Professional Alpha X loading state.
  Widget _buildLoadingState(double? progress) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
              backgroundColor: AppColors.surfaceElevated,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Loading demonstration...',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Error state when GIF media fails to load.
  /// Displays "Unable to load demonstration" with retry action.
  /// NEVER falls back to hero images.
  Widget _buildUnableToLoadView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Unable to load demonstration',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            AlphaXPressable(
              onTap: _retryLoading,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryRed),
                    SizedBox(width: 6),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clean empty state when no animated GIF exists for this exercise.
  /// Displays "Demonstration unavailable" and guides the client to the instructions.
  Widget _buildNoDemonstrationAvailableView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF131317),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.border,
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.fitness_center_outlined,
                    color: AppColors.textTertiary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Demonstration unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Refer to the detailed form instructions below',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
