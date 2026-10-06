import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/food_photo_model.dart';
import '../../data/services/food_photo_tracking_service.dart';

/// Screen integrated into Master Admin Dashboard allowing trainers to visually follow
/// what clients eat throughout the day and verify meal photos.
class AdminFoodPhotosMonitoringScreen extends StatefulWidget {
  final String? initialClientId;
  final bool showAppBar;

  const AdminFoodPhotosMonitoringScreen({
    super.key,
    this.initialClientId,
    this.showAppBar = true,
  });

  @override
  State<AdminFoodPhotosMonitoringScreen> createState() => _AdminFoodPhotosMonitoringScreenState();
}

class _AdminFoodPhotosMonitoringScreenState extends State<AdminFoodPhotosMonitoringScreen> {
  final _service = FoodPhotoTrackingService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<FoodPhotoModel> _photos = [];
  Map<String, dynamic> _summary = {};

  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _selectedMealType = 'ALL';
  String _selectedStatus = 'ALL';

  final List<String> _mealFilterOptions = const ['ALL', 'Breakfast', 'Lunch', 'Snack', 'Dinner'];
  final List<String> _statusFilterOptions = const ['ALL', 'PENDING', 'VERIFIED', 'NEEDS_ATTENTION'];

  @override
  void initState() {
    super.initState();
    if (widget.initialClientId != null) {
      _searchController.text = widget.initialClientId!;
    }
    _loadPhotos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final res = await _service.getAdminFoodPhotosMonitoring(
        clientId: widget.initialClientId,
        dateString: _selectedDate,
        mealType: _selectedMealType == 'ALL' ? null : _selectedMealType,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _photos = List<FoodPhotoModel>.from(res['photos'] ?? []);
          _summary = Map<String, dynamic>.from(res['summary'] ?? {});
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final current = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryRed,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      _loadPhotos();
    }
  }

  Future<void> _verifyPhoto(FoodPhotoModel photo, String newStatus, {String? adminNote}) async {
    final success = await _service.adminVerifyFoodPhoto(
      photoId: photo.id,
      status: newStatus,
      adminNote: adminNote,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: newStatus == 'VERIFIED' ? Colors.green.shade800 : AppColors.surfaceElevated,
          duration: const Duration(seconds: 2),
          content: Text(
            newStatus == 'VERIFIED'
                ? '${photo.clientName ?? photo.clientId}\'s ${photo.mealType} marked as ✓ Verified'
                : '${photo.clientName ?? photo.clientId}\'s ${photo.mealType} flagged for attention',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      _loadPhotos();
    }
  }

  void _showAttentionDialog(FoodPhotoModel photo) {
    final noteCtrl = TextEditingController(text: photo.adminNote ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.primaryRed, size: 22),
            SizedBox(width: 8),
            Text(
              'Diet Attention Guidance',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flag ${photo.clientName ?? photo.clientId}\'s ${photo.mealType} for diet follow-up. Add guidance notes below (optional):',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Please follow the assigned diet for dinner: reduce simple carbs.',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                filled: true,
                fillColor: AppColors.surfaceCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _verifyPhoto(photo, 'NEEDS_ATTENTION', adminNote: noteCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: const Text('Flag for Attention', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                    child: _buildPhotoImage(photo, height: 360, fit: BoxFit.contain),
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
                              photo.clientName ?? photo.clientId,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            _buildStatusBadge(photo),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${photo.mealType.toUpperCase()} • ${photo.formattedDateTime}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        if (photo.clientNote != null && photo.clientNote!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Client Note: ${photo.clientNote!}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _verifyPhoto(photo, 'VERIFIED');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                                label: const Text('VERIFY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _showAttentionDialog(photo);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                                label: const Text('ATTENTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
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
      label = 'Pending Review';
      icon = Icons.schedule;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'CLIENT FOOD PHOTOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: AppColors.primaryRed, size: 20),
                  tooltip: 'Filter Date',
                  onPressed: _selectDate,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: _loadPhotos,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // 1. Search Bar & Date Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search client by name or ID...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                _loadPhotos();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _loadPhotos(),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, color: AppColors.primaryRed, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now())
                              ? 'TODAY'
                              : DateFormat('dd MMM').format(DateTime.parse(_selectedDate)),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!widget.showAppBar) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _loadPhotos,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Filter Chips: Meal Type & Status
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Meal Type Filters
                ..._mealFilterOptions.map((type) {
                  final isSelected = _selectedMealType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(type),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryRed,
                      backgroundColor: AppColors.surface,
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedMealType = type);
                          _loadPhotos();
                        }
                      },
                    ),
                  );
                }),
                const SizedBox(width: 8),
                // Status Filters
                ..._statusFilterOptions.map((st) {
                  final isSelected = _selectedStatus == st;
                  final label = st == 'ALL'
                      ? 'All Status'
                      : st == 'PENDING'
                          ? '🟡 Pending'
                          : st == 'VERIFIED'
                              ? '🟢 Verified'
                              : '🔴 Attention';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(label),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: isSelected,
                      selectedColor: st == 'VERIFIED'
                          ? const Color(0xFF16A34A)
                          : st == 'NEEDS_ATTENTION'
                              ? AppColors.primaryRed
                              : Colors.amber.shade700,
                      backgroundColor: AppColors.surface,
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedStatus = st);
                          _loadPhotos();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Summary Stats Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('TOTAL', '${_summary['total'] ?? _photos.length}', Colors.white),
                  _buildStatItem('PENDING', '${_summary['pendingCount'] ?? 0}', Colors.amber),
                  _buildStatItem('VERIFIED', '${_summary['verifiedCount'] ?? 0}', const Color(0xFF4ADE80)),
                  _buildStatItem('ATTENTION', '${_summary['needsAttentionCount'] ?? 0}', const Color(0xFFF87171)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 4. Photo Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                : _photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No food photos found for $_selectedDate',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPhotos,
                        color: AppColors.primaryRed,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                          itemCount: _photos.length,
                          itemBuilder: (ctx, idx) => _buildAdminPhotoCard(_photos[idx]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6),
        ),
      ],
    );
  }

  String _getClientInitial(FoodPhotoModel photo) {
    final name = (photo.clientName?.trim().isNotEmpty ?? false)
        ? photo.clientName!.trim()
        : photo.clientId.trim();
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }

  Widget _buildAdminPhotoCard(FoodPhotoModel photo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: photo.isNeedsAttention
              ? AppColors.primaryRed.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Client info & Meal Type
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryRed.withOpacity(0.15),
                      child: Text(
                        _getClientInitial(photo),
                        style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo.clientName ?? photo.clientId,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          photo.clientId,
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildStatusBadge(photo),
              ],
            ),
          ),

          // Photo preview + Date / Notes
          InkWell(
            onTap: () => _showFullPhotoDialog(photo),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildPhotoImage(photo, height: 90)),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                photo.mealType.toUpperCase(),
                                style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              photo.formattedTime,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (photo.clientNote != null && photo.clientNote!.isNotEmpty) ...[
                          Text(
                            photo.clientNote!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (photo.adminNote != null && photo.adminNote!.isNotEmpty) ...[
                          Text(
                            'Admin: ${photo.adminNote!}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: photo.isNeedsAttention ? AppColors.primaryRed : Colors.green.shade300,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Verification Buttons
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _verifyPhoto(photo, 'VERIFIED'),
                    icon: const Icon(Icons.check, color: Color(0xFF4ADE80), size: 16),
                    label: const Text(
                      'VERIFY',
                      style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showAttentionDialog(photo),
                    icon: const Icon(Icons.warning_amber_rounded, color: AppColors.primaryRed, size: 16),
                    label: const Text(
                      'ATTENTION',
                      style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
