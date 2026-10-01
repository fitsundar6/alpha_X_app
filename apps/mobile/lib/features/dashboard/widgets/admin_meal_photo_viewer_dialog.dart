import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Full-screen interactive viewer for Admin to inspect confirmed meal photos
/// Supports interactive zoom/pan, complete macro breakdown, individual food weights,
/// and weight source verification (AI Estimated vs Client Entered vs Smart Scale).
class AdminMealPhotoViewerDialog extends StatefulWidget {
  final Map<String, dynamic> mealPhoto;
  final String clientName;
  final String clientId;
  final VoidCallback? onPhotoDeleted;

  const AdminMealPhotoViewerDialog({
    super.key,
    required this.mealPhoto,
    required this.clientName,
    required this.clientId,
    this.onPhotoDeleted,
  });

  @override
  State<AdminMealPhotoViewerDialog> createState() => _AdminMealPhotoViewerDialogState();
}

class _AdminMealPhotoViewerDialogState extends State<AdminMealPhotoViewerDialog> {
  final TransformationController _transformationController = TransformationController();
  bool _isLoadingImage = true;
  bool _hasImageError = false;
  ImageProvider? _imageProvider;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoadingImage = true;
      _hasImageError = false;
    });

    final photoUrl = widget.mealPhoto['photoUrl']?.toString() ?? '';
    final photoId = widget.mealPhoto['id']?.toString() ?? '';
    final token = AuthService().token;

    if (photoUrl.isEmpty && photoId.isEmpty) {
      setState(() {
        _isLoadingImage = false;
        _hasImageError = true;
      });
      return;
    }

    try {
      final base = AppConstants.apiBaseUrl;
      final fullUrl = photoUrl.startsWith('http')
          ? photoUrl
          : (photoUrl.isNotEmpty ? '$base$photoUrl' : '$base/food-photos/$photoId/image');

      final uri = Uri.parse('$fullUrl?token=$token');
      final headers = <String, String>{};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _imageProvider = MemoryImage(response.bodyBytes);
            _isLoadingImage = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingImage = false;
            _hasImageError = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
          _hasImageError = true;
        });
      }
    }
  }

  Future<void> _deletePhoto() async {
    final photoId = widget.mealPhoto['id']?.toString() ?? '';
    if (photoId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Delete Meal Photo?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This will remove the photo file from secure storage. The meal nutrition log will be preserved.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/meal-photos/$photoId');
      final headers = <String, String>{};
      final token = AuthService().token;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        if (mounted) {
          widget.onPhotoDeleted?.call();
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealType = widget.mealPhoto['mealType']?.toString() ?? 'Meal';
    final weightSource = widget.mealPhoto['weightSource']?.toString() ?? 'AI_ESTIMATE';
    final isAiEstimated = weightSource == 'AI_ESTIMATE';
    final isSmartScale = weightSource == 'SMART_SCALE_BLE';

    final totalCal = (widget.mealPhoto['totalCalories'] as num?)?.toDouble() ?? 0.0;
    final totalProt = (widget.mealPhoto['totalProtein'] as num?)?.toDouble() ?? 0.0;
    final totalCrbs = (widget.mealPhoto['totalCarbs'] as num?)?.toDouble() ?? 0.0;
    final totalFt = (widget.mealPhoto['totalFat'] as num?)?.toDouble() ?? 0.0;
    final totalFbr = (widget.mealPhoto['totalFiber'] as num?)?.toDouble() ?? 0.0;

    DateTime confirmedDate = DateTime.now();
    if (widget.mealPhoto['confirmedAt'] != null) {
      confirmedDate = DateTime.tryParse(widget.mealPhoto['confirmedAt'].toString()) ?? DateTime.now();
    }
    final formattedTime = DateFormat('dd MMM yyyy • h:mm a').format(confirmedDate.toLocal());

    List<dynamic> items = [];
    if (widget.mealPhoto['items'] is List) {
      items = widget.mealPhoto['items'] as List;
    } else if (widget.mealPhoto['itemsJson'] is String) {
      try {
        items = jsonDecode(widget.mealPhoto['itemsJson'] as String);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$mealType Photo • ${widget.clientName}'.toUpperCase(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            Text(
              '${widget.clientId} • $formattedTime',
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Reset Zoom',
            onPressed: () {
              _transformationController.value = Matrix4.identity();
            },
          ),
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Photo',
              onPressed: _deletePhoto,
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Interactive Zoomable Photo Area
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: _isLoadingImage
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryRed),
                          SizedBox(height: 12),
                          Text('Decrypting meal photo...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    )
                  : _hasImageError || _imageProvider == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image, color: AppColors.textTertiary, size: 48),
                              const SizedBox(height: 8),
                              const Text('Could not load meal photo', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadImage,
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceElevated),
                                child: const Text('RETRY'),
                              ),
                            ],
                          ),
                        )
                      : InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 0.8,
                          maxScale: 4.5,
                          panEnabled: true,
                          scaleEnabled: true,
                          child: Center(
                            child: Image(
                              image: _imageProvider!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
            ),
          ),

          // 2. Nutrition Breakdown & Food Items Sheet
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ListView(
                children: [
                  // Weight Source Badge Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSmartScale
                              ? AppColors.success.withOpacity(0.15)
                              : (isAiEstimated ? AppColors.gold.withOpacity(0.15) : Colors.lightBlueAccent.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSmartScale
                                ? AppColors.success.withOpacity(0.5)
                                : (isAiEstimated ? AppColors.gold.withOpacity(0.5) : Colors.lightBlueAccent.withOpacity(0.5)),
                          ),
                        ),
                        child: Text(
                          isSmartScale
                              ? '⚖️ SMART SCALE MEASURED'
                              : (isAiEstimated ? '📷 AI ESTIMATED PORTION' : '✏️ CLIENT ENTERED WEIGHT'),
                          style: TextStyle(
                            color: isSmartScale
                                ? AppColors.success
                                : (isAiEstimated ? AppColors.gold : Colors.lightBlueAccent),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        'Pinch or double tap to zoom',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nutrition Totals Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MacroItem(label: 'Calories', value: '${totalCal.round()} kcal', color: AppColors.primaryRed),
                        _MacroItem(label: 'Protein', value: '${totalProt.toStringAsFixed(1)}g', color: AppColors.accentRed),
                        _MacroItem(label: 'Carbs', value: '${totalCrbs.toStringAsFixed(1)}g', color: AppColors.info),
                        _MacroItem(label: 'Fat', value: '${totalFt.toStringAsFixed(1)}g', color: AppColors.gold),
                        _MacroItem(label: 'Fiber', value: '${totalFbr.toStringAsFixed(1)}g', color: AppColors.success),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Confirmed Food Items List
                  const Text(
                    'FOOD ITEMS ON PLATE',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),

                  if (items.isEmpty)
                    const Text('No individual food items detected.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
                  else
                    ...items.map((item) {
                      final name = item['foodName'] ?? item['name'] ?? 'Item';
                      final serving = item['servingSize'] ?? 100;
                      final unit = item['servingUnit'] ?? 'g';
                      final q = item['quantity'] ?? 1.0;
                      final cal = item['calories'] ?? 0;
                      final p = item['protein'] ?? 0;
                      final c = item['carbohydrates'] ?? item['carbs'] ?? 0;
                      final f = item['fat'] ?? 0;
                      final src = item['weightSource'] ?? weightSource;
                      final isEst = src == 'AI_ESTIMATE';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$q× • $serving $unit • $cal kcal (P:${p}g C:${c}g F:${f}g)',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isEst ? AppColors.gold.withOpacity(0.12) : Colors.lightBlueAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isEst ? 'AI Estimate' : 'Confirmed',
                                style: TextStyle(
                                  color: isEst ? AppColors.gold : Colors.lightBlueAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
