import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/food_photo_model.dart';
import '../../data/services/food_photo_tracking_service.dart';
import 'live_food_camera_screen.dart';

/// Screen displaying the athlete's Live Food Photo history and coach verification statuses.
class MyFoodPhotosScreen extends StatefulWidget {
  const MyFoodPhotosScreen({super.key});

  @override
  State<MyFoodPhotosScreen> createState() => _MyFoodPhotosScreenState();
}

class _MyFoodPhotosScreenState extends State<MyFoodPhotosScreen> {
  final _service = FoodPhotoTrackingService();
  bool _isLoading = true;
  List<FoodPhotoModel> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      // Sync any offline photos first
      await _service.syncPendingFoodPhotos();
      final list = await _service.getClientFoodPhotos();
      if (mounted) {
        setState(() {
          _photos = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveFoodCameraScreen(),
      ),
    ).then((_) => _loadPhotos());
  }

  void _showFullPhotoDialog(FoodPhotoModel photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _buildPhotoImage(photo, height: 340, fit: BoxFit.contain),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              photo.mealType.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            _buildStatusBadge(photo),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          photo.formattedDateTime,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        if (photo.clientNote != null && photo.clientNote!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Note: ${photo.clientNote!}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                        if (photo.adminNote != null && photo.adminNote!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: photo.isNeedsAttention
                                  ? AppColors.primaryRed.withOpacity(0.12)
                                  : Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: photo.isNeedsAttention
                                    ? AppColors.primaryRed.withOpacity(0.3)
                                    : Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  photo.isNeedsAttention ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                  color: photo.isNeedsAttention ? AppColors.primaryRed : Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Coach Note: ${photo.adminNote!}',
                                    style: TextStyle(
                                      color: photo.isNeedsAttention ? Colors.white : Colors.green.shade200,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoImage(FoodPhotoModel photo, {double height = 90, BoxFit fit = BoxFit.cover}) {
    final token = AuthService().currentToken;
    final fullUrl = photo.photoUrl.startsWith('http')
        ? photo.photoUrl
        : '${AppConstants.apiBaseUrl.replaceAll('/api/v1', '')}${photo.photoUrl}?token=$token';

    if (photo.photoUrl.isNotEmpty && (photo.photoUrl.startsWith('http') || photo.photoUrl.startsWith('/api'))) {
      return Image.network(
        fullUrl,
        height: height,
        width: double.infinity,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            color: AppColors.surfaceCard,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
              ),
            ),
          );
        },
      );
    }

    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      color: AppColors.surfaceCard,
      child: const Center(
        child: Icon(Icons.restaurant, color: Colors.white24, size: 28),
      ),
    );
  }

  Widget _buildStatusBadge(FoodPhotoModel photo) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (photo.isVerified) {
      bg = Colors.green.withOpacity(0.15);
      fg = const Color(0xFF4ADE80);
      label = '✓ Verified';
      icon = Icons.check_circle;
    } else if (photo.isNeedsAttention) {
      bg = AppColors.primaryRed.withOpacity(0.15);
      fg = const Color(0xFFF87171);
      label = '⚠ Needs Attention';
      icon = Icons.warning_amber_rounded;
    } else {
      bg = Colors.amber.withOpacity(0.15);
      fg = const Color(0xFFFBBF24);
      label = photo.isPendingSync ? 'Local (Pending Sync)' : 'Pending Review';
      icon = photo.isPendingSync ? Icons.cloud_off : Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayPhotos = _photos.where((p) => p.dateString == todayStr).toList();
    final previousPhotos = _photos.where((p) => p.dateString != todayStr).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MY FOOD PHOTOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: AppColors.primaryRed),
            tooltip: 'Take Food Photo',
            onPressed: _openCamera,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        backgroundColor: AppColors.primaryRed,
        icon: const Icon(Icons.photo_camera, color: Colors.white),
        label: const Text(
          'TAKE FOOD PHOTO',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
          : RefreshIndicator(
              onRefresh: _loadPhotos,
              color: AppColors.primaryRed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  // 1. Daily Tracking Summary
                  _buildDailySummaryCard(todayPhotos),
                  const SizedBox(height: 20),

                  // 2. Today's Food Photos Section
                  Row(
                    children: [
                      Container(width: 3, height: 16, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      const Text(
                        'TODAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('dd MMMM yyyy').format(DateTime.now()),
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (todayPhotos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.no_photography_outlined, color: Colors.white24, size: 42),
                          const SizedBox(height: 10),
                          const Text(
                            'No food photos recorded today',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Snap a live camera photo of your breakfast, lunch, or dinner so your trainer can review your diet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _openCamera,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            label: const Text('Capture Today\'s Meal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...todayPhotos.map((p) => _buildPhotoCard(p)),

                  // 3. Previous Days Section
                  if (previousPhotos.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(width: 3, height: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        const Text(
                          'PREVIOUS PHOTOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...previousPhotos.map((p) => _buildPhotoCard(p)),
                  ],

                  const SizedBox(height: 80), // Fab padding
                ],
              ),
            ),
    );
  }

  Widget _buildDailySummaryCard(List<FoodPhotoModel> todayPhotos) {
    final bool hasBreakfast = todayPhotos.any((p) => p.mealType.toLowerCase() == 'breakfast');
    final bool hasLunch = todayPhotos.any((p) => p.mealType.toLowerCase() == 'lunch');
    final bool hasSnack = todayPhotos.any((p) => p.mealType.toLowerCase() == 'snack' || p.mealType.toLowerCase() == 'snacks');
    final bool hasDinner = todayPhotos.any((p) => p.mealType.toLowerCase() == 'dinner');

    final verifiedCount = todayPhotos.where((p) => p.isVerified).length;
    final pendingCount = todayPhotos.where((p) => p.isPending).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TODAY\'S FOOD HABITS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${todayPhotos.length} / 4 Meals',
                  style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMealTrackerPill('Breakfast', hasBreakfast),
              const SizedBox(width: 8),
              _buildMealTrackerPill('Lunch', hasLunch),
              const SizedBox(width: 8),
              _buildMealTrackerPill('Snack', hasSnack),
              const SizedBox(width: 8),
              _buildMealTrackerPill('Dinner', hasDinner),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 14),
                  const SizedBox(width: 4),
                  Text('$verifiedCount Verified', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFFFBBF24), size: 14),
                  const SizedBox(width: 4),
                  Text('$pendingCount Pending Review', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealTrackerPill(String title, bool isDone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDone ? Colors.green.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDone ? Colors.green.withOpacity(0.5) : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: isDone ? Colors.green : AppColors.textTertiary,
              size: 16,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isDone ? Colors.white : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(FoodPhotoModel photo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showFullPhotoDialog(photo),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildPhotoImage(photo)),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            photo.mealType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          _buildStatusBadge(photo),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: AppColors.textTertiary, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            photo.formattedDateTime,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                      if (photo.clientNote != null && photo.clientNote!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          photo.clientNote!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                      if (photo.adminNote != null && photo.adminNote!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: photo.isNeedsAttention
                                ? AppColors.primaryRed.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Coach: ${photo.adminNote!}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: photo.isNeedsAttention ? AppColors.primaryRed : Colors.green.shade300,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
