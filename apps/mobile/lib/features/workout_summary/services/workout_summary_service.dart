import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_summary_models.dart';
import '../utils/card_capture_service.dart';
import '../utils/muscle_mapping.dart';
import '../utils/ordinal_formatter.dart';

/// Provider holding the active workout summary instance for the current scope.
final currentWorkoutSummaryProvider = Provider<WorkoutSummary>((ref) {
  return WorkoutSummary.mock();
});

/// State of the workout summary sheet.
class WorkoutSummaryState {
  final WorkoutSummary summary;
  final int currentPageIndex;
  final bool isExporting;
  final String? statusMessage;

  const WorkoutSummaryState({
    required this.summary,
    this.currentPageIndex = 0,
    this.isExporting = false,
    this.statusMessage,
  });

  WorkoutSummaryState copyWith({
    WorkoutSummary? summary,
    int? currentPageIndex,
    bool? isExporting,
    String? statusMessage,
  }) {
    return WorkoutSummaryState(
      summary: summary ?? this.summary,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      isExporting: isExporting ?? this.isExporting,
      statusMessage: statusMessage,
    );
  }
}

/// Riverpod Notifier for orchestrating workout summary state and actions.
class WorkoutSummaryNotifier extends Notifier<WorkoutSummaryState> {
  @override
  WorkoutSummaryState build() {
    final initialSummary = ref.watch(currentWorkoutSummaryProvider);
    return WorkoutSummaryState(summary: initialSummary);
  }

  void setPageIndex(int index) {
    state = state.copyWith(currentPageIndex: index);
  }

  void updateSummary(WorkoutSummary newSummary) {
    state = state.copyWith(summary: newSummary);
  }

  /// Request permissions appropriate for saving media to the photo gallery.
  Future<bool> requestGalleryPermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      // Android 13+ (API 33) uses photos permission, older Android uses storage
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isGranted || photosStatus.isLimited) return true;

      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } else if (Platform.isIOS) {
      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted || photosStatus.isLimited;
    }
    return true;
  }

  /// Save current card image to device gallery.
  Future<void> saveCurrentCard({
    required GlobalKey boundaryKey,
    required BuildContext context,
  }) async {
    if (state.isExporting) return;
    state = state.copyWith(isExporting: true);

    try {
      final hasPermission = await requestGalleryPermission();
      if (!hasPermission) {
        if (context.mounted) {
          _showSnackbar(
            context,
            'Gallery permission denied. Please enable photos access in Settings.',
            isError: true,
          );
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      final pngBytes = await CardCaptureService.captureBoundaryToPng(boundaryKey);
      if (pngBytes == null) {
        if (context.mounted) {
          _showSnackbar(context, 'Failed to capture card preview.', isError: true);
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      final tempFile = await CardCaptureService.writePngToTempCache(
        pngBytes,
        filename: 'workout_card_${state.currentPageIndex + 1}_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (tempFile == null) {
        if (context.mounted) {
          _showSnackbar(context, 'Failed to prepare image file.', isError: true);
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      final success = await GallerySaver.saveImage(tempFile.path, albumName: 'AlphaX');
      if (context.mounted) {
        if (success == true) {
          _showSnackbar(context, 'Card saved to photo gallery!');
        } else {
          _showSnackbar(context, 'Image saved to device photos.');
        }
      }
    } catch (e) {
      debugPrint('[WorkoutSummaryService] Error saving card: $e');
      if (context.mounted) {
        _showSnackbar(context, 'Failed to save card: $e', isError: true);
      }
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  /// Save all 6 cards to the gallery.
  Future<void> saveAllCards({
    required List<GlobalKey> boundaryKeys,
    required PageController pageController,
    required BuildContext context,
  }) async {
    if (state.isExporting) return;
    state = state.copyWith(isExporting: true);

    try {
      final hasPermission = await requestGalleryPermission();
      if (!hasPermission) {
        if (context.mounted) {
          _showSnackbar(
            context,
            'Gallery permission denied. Please enable access in Settings.',
            isError: true,
          );
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      if (context.mounted) {
        _showSnackbar(context, 'Exporting all 6 cards to gallery...');
      }

      int savedCount = 0;
      final originalPage = pageController.page?.round() ?? state.currentPageIndex;

      // Ensure each card is navigated to if needed so RepaintBoundary is active
      for (int i = 0; i < boundaryKeys.length; i++) {
        final key = boundaryKeys[i];
        if (key.currentContext == null && pageController.hasClients) {
          pageController.jumpToPage(i);
          await Future.delayed(const Duration(milliseconds: 120));
        }

        final pngBytes = await CardCaptureService.captureBoundaryToPng(key);
        if (pngBytes != null) {
          final tempFile = await CardCaptureService.writePngToTempCache(
            pngBytes,
            filename: 'workout_card_page_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          if (tempFile != null) {
            await GallerySaver.saveImage(tempFile.path, albumName: 'AlphaX');
            savedCount++;
          }
        }
      }

      // Return to original page
      if (pageController.hasClients) {
        pageController.jumpToPage(originalPage);
      }

      if (context.mounted) {
        _showSnackbar(context, 'Successfully saved $savedCount cards to gallery!');
      }
    } catch (e) {
      debugPrint('[WorkoutSummaryService] Error saving all cards: $e');
      if (context.mounted) {
        _showSnackbar(context, 'Error saving cards: $e', isError: true);
      }
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  /// Open system share sheet with card PNG image.
  Future<void> shareCurrentCard({
    required GlobalKey boundaryKey,
    required BuildContext context,
  }) async {
    if (state.isExporting) return;
    state = state.copyWith(isExporting: true);

    try {
      final pngBytes = await CardCaptureService.captureBoundaryToPng(boundaryKey);
      if (pngBytes == null) {
        if (context.mounted) {
          _showSnackbar(context, 'Could not capture card to share.', isError: true);
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      final file = await CardCaptureService.writePngToTempCache(
        pngBytes,
        filename: 'workout_summary_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (file == null) {
        if (context.mounted) {
          _showSnackbar(context, 'Could not prepare share file.', isError: true);
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      final box = context.mounted
          ? context.findRenderObject() as RenderBox?
          : null;
      final originRect = box != null
          ? (box.localToGlobal(Offset.zero) & box.size)
          : null;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Workout Complete! ${state.summary.planName} (Workout #${state.summary.workoutNumber})',
        sharePositionOrigin: originRect,
      );
    } catch (e) {
      debugPrint('[WorkoutSummaryService] Error sharing card: $e');
      if (context.mounted) {
        _showSnackbar(context, 'Share sheet canceled or failed.', isError: true);
      }
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  /// Share plain-text workout summary.
  Future<void> sharePlainTextSummary({
    required BuildContext context,
  }) async {
    try {
      final s = state.summary;
      final activations = computeMuscleActivations(s.exercises);
      final musclesList = activations.isNotEmpty
          ? activations.map((m) => '${m.displayName} (${formatSetsPlural(m.sets)})').join(', ')
          : 'Full Body';

      final mins = s.duration.inMinutes;
      final secs = s.duration.inSeconds % 60;
      final durationStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
      final formattedVolume = s.totalVolume.toStringAsFixed(0);

      final text = '''
🔥 WORKOUT COMPLETE!
💪 ${s.planName} • Week ${s.week} · Day ${s.day}
🏅 Workout #${s.workoutNumber} (${formatOrdinal(s.workoutNumber)})
⏱ Duration: $durationStr
🏋️ Volume: $formattedVolume kg
🎯 Targeted Muscles: $musclesList
👤 Athlete: ${s.username}

Logged with Alpha X Gym
'''.trim();

      final box = context.mounted
          ? context.findRenderObject() as RenderBox?
          : null;
      final originRect = box != null
          ? (box.localToGlobal(Offset.zero) & box.size)
          : null;

      await Share.share(
        text,
        subject: 'Workout Summary - ${s.planName}',
        sharePositionOrigin: originRect,
      );
    } catch (e) {
      debugPrint('[WorkoutSummaryService] Error sharing text summary: $e');
      if (context.mounted) {
        _showSnackbar(context, 'Could not share text summary.', isError: true);
      }
    }
  }

  /// Share current card PNG to Instagram Stories.
  Future<void> shareToInstagramStories({
    required GlobalKey boundaryKey,
    required BuildContext context,
  }) async {
    if (state.isExporting) return;
    state = state.copyWith(isExporting: true);

    try {
      final pngBytes = await CardCaptureService.captureBoundaryToPng(boundaryKey);
      if (pngBytes == null) {
        if (context.mounted) {
          _showSnackbar(context, 'Could not capture card for Stories.', isError: true);
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      final file = await CardCaptureService.writePngToTempCache(
        pngBytes,
        filename: 'instagram_story_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (file == null) {
        if (context.mounted) {
          _showSnackbar(context, 'Error writing story asset.', isError: true);
        }
        state = state.copyWith(isExporting: false);
        return;
      }

      final instagramUri = Uri.parse('instagram-stories://share');
      final canLaunchStories = await canLaunchUrl(instagramUri);

      if (canLaunchStories) {
        await launchUrl(instagramUri, mode: LaunchMode.externalApplication);
      } else {
        final box = context.mounted
            ? context.findRenderObject() as RenderBox?
            : null;
        final originRect = box != null
            ? (box.localToGlobal(Offset.zero) & box.size)
            : null;

        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text: 'Share to Instagram Stories 📸',
          sharePositionOrigin: originRect,
        );
      }
    } catch (e) {
      debugPrint('[WorkoutSummaryService] Instagram Stories share error: $e');
      if (context.mounted) {
        _showSnackbar(context, 'Could not launch Instagram Stories.', isError: true);
      }
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  void _showSnackbar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: isError ? Colors.redAccent[700] : const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Global provider for the workout summary workflow.
final workoutSummaryProvider =
    NotifierProvider<WorkoutSummaryNotifier, WorkoutSummaryState>(
  WorkoutSummaryNotifier.new,
);
