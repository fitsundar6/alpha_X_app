import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

/// Service responsible for rendering and exporting high-resolution PNG images
/// from any widget wrapped in a [RepaintBoundary].
class CardCaptureService {
  /// Captures a [RepaintBoundary] as an uncompressed high-resolution PNG [Uint8List].
  /// Default pixelRatio is 3.0 for ultra-crisp social sharing and gallery export.
  static Future<Uint8List?> captureBoundaryToPng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('[CardCaptureService] RenderRepaintBoundary not found for key.');
        return null;
      }

      // If boundary is currently painting or marked needsPaint, wait a frame
      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('[CardCaptureService] Failed to encode image to PNG ByteData.');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e, stack) {
      debugPrint('[CardCaptureService] Error capturing card boundary: $e\n$stack');
      return null;
    }
  }

  /// Writes raw PNG bytes to the application's temporary cache directory,
  /// suitable for platform sharing sheets and external intent broadcasts.
  static Future<File?> writePngToTempCache(
    Uint8List pngBytes, {
    String? filename,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = filename ??
          'workout_summary_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(pngBytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('[CardCaptureService] Failed to write PNG to temp file: $e');
      return null;
    }
  }
}
