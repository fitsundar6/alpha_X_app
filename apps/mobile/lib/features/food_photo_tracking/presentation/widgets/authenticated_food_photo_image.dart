import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/food_photo_model.dart';

/// Secure authenticated image widget for displaying diet and meal photos.
///
/// Features:
/// 1. Reliable on both Flutter Web and Native mobile (Android/iOS).
///    - Web: Image.network drops Authorization headers on HTML <img> tags. This widget fetches bytes via
///      authenticated HTTP GET with Bearer token, then renders via Image.memory.
/// 2. Resolves relative URLs cleanly using AppConstants.resolveImageUrl (eliminates duplicated /api/v1).
/// 3. In-memory caching prevents duplicate network roundtrips on widget rebuilds.
/// 4. Handles local offline captured files gracefully via File(localFilePath).
/// 5. Graceful loading and error states with a retry action instead of a silent blank area.
class AuthenticatedFoodPhotoImage extends StatefulWidget {
  final String photoUrl;
  final String? localFilePath;
  final String? photoId;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isPendingSync;
  final Widget? fallbackWidget;

  const AuthenticatedFoodPhotoImage({
    super.key,
    required this.photoUrl,
    this.localFilePath,
    this.photoId,
    this.height = 90,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isPendingSync = false,
    this.fallbackWidget,
  });

  factory AuthenticatedFoodPhotoImage.fromModel(
    FoodPhotoModel photo, {
    double? height = 90,
    double? width = double.infinity,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? fallbackWidget,
  }) {
    return AuthenticatedFoodPhotoImage(
      photoUrl: photo.photoUrl,
      localFilePath: photo.localFilePath,
      photoId: photo.id,
      height: height,
      width: width,
      fit: fit,
      borderRadius: borderRadius,
      isPendingSync: photo.isPendingSync,
      fallbackWidget: fallbackWidget,
    );
  }

  /// Global session cache for meal photo bytes to avoid redundant network traffic.
  static final Map<String, Uint8List> _imageCache = {};

  /// Clear the in-memory cache if needed (e.g., on logout or pull-to-refresh).
  static void clearCache() {
    _imageCache.clear();
  }

  @override
  State<AuthenticatedFoodPhotoImage> createState() => _AuthenticatedFoodPhotoImageState();
}

class _AuthenticatedFoodPhotoImageState extends State<AuthenticatedFoodPhotoImage> {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedFoodPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.localFilePath != widget.localFilePath ||
        oldWidget.photoId != widget.photoId) {
      _loadImage();
    }
  }

  String _deriveResolvedUrl() {
    final rawUrl = widget.photoUrl.trim();
    if (rawUrl.isNotEmpty && (rawUrl.startsWith('http') || rawUrl.startsWith('/api'))) {
      return AppConstants.resolveImageUrl(rawUrl);
    }
    if (widget.photoId != null && widget.photoId!.isNotEmpty) {
      return AppConstants.resolveImageUrl('/api/v1/food-photos/${widget.photoId}/image');
    }
    return '';
  }

  Future<void> _loadImage() async {
    // 1. Check local disk file first (if offline or just captured on device)
    if (!kIsWeb && widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      try {
        final file = File(widget.localFilePath!);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          if (mounted && bytes.isNotEmpty) {
            setState(() {
              _imageBytes = bytes;
              _isLoading = false;
              _hasError = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // 2. Check if photoUrl is a data URI
    if (widget.photoUrl.startsWith('data:image/')) {
      try {
        final commaIdx = widget.photoUrl.indexOf(',');
        final base64Data = commaIdx >= 0 ? widget.photoUrl.substring(commaIdx + 1) : widget.photoUrl;
        final bytes = base64Decode(base64Data);
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _isLoading = false;
            _hasError = false;
          });
          return;
        }
      } catch (_) {}
    }

    // 3. Resolve remote URL
    final resolvedUrl = _deriveResolvedUrl();
    if (resolvedUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = widget.photoUrl.isNotEmpty;
        });
      }
      return;
    }

    // 4. Check in-memory cache
    if (AuthenticatedFoodPhotoImage._imageCache.containsKey(resolvedUrl)) {
      if (mounted) {
        setState(() {
          _imageBytes = AuthenticatedFoodPhotoImage._imageCache[resolvedUrl];
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    // 5. Fetch via authenticated HTTP GET
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final token = AuthService().token;
      final headers = <String, String>{};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse(resolvedUrl);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        AuthenticatedFoodPhotoImage._imageCache[resolvedUrl] = response.bodyBytes;
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
          _hasError = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      content = Image.memory(
        _imageBytes!,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } else if (_isLoading) {
      content = Container(
        height: widget.height,
        width: widget.width,
        color: AppColors.surfaceCard,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
          ),
        ),
      );
    } else if (_hasError) {
      content = _buildErrorWidget();
    } else {
      content = widget.fallbackWidget ?? _buildFallbackWidget();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildErrorWidget() {
    return GestureDetector(
      onTap: _loadImage,
      child: Container(
        height: widget.height,
        width: widget.width,
        color: AppColors.surfaceCard,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
              size: (widget.height != null && widget.height! < 120) ? 22 : 32,
            ),
            if (widget.height == null || widget.height! >= 120) ...[
              const SizedBox(height: 6),
              const Text(
                'Photo unavailable',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to retry',
                style: TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackWidget() {
    return Container(
      height: widget.height,
      width: widget.width,
      color: AppColors.surfaceCard,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant,
        color: Colors.white24,
        size: (widget.height != null && widget.height! < 120) ? 24 : 36,
      ),
    );
  }
}

