import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class ClientTransformationTimelineScreen extends StatefulWidget {
  final String? adminTargetClientId; // If non-null, Admin is viewing this client
  final String? athleteName;
  final List<Map<String, dynamic>>? initialMilestones;

  const ClientTransformationTimelineScreen({
    super.key,
    this.adminTargetClientId,
    this.athleteName,
    this.initialMilestones,
  });

  @override
  State<ClientTransformationTimelineScreen> createState() => _ClientTransformationTimelineScreenState();
}

class _ClientTransformationTimelineScreenState extends State<ClientTransformationTimelineScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  String? _uploadingAngle;
  int? _uploadingWeek;
  String? _error;
  List<Map<String, dynamic>> _milestones = [];

  // Angle selection for top Before & After comparison
  String _comparisonAngle = 'FRONT'; // FRONT, SIDE, BACK
  int? _selectedBeforeWeek;
  int? _selectedAfterWeek;
  bool _isSliderView = false;
  double _sliderPosition = 0.5;

  final List<int> _defaultSupportedWeeks = [1, 4, 8, 12, 16];

  @override
  void initState() {
    super.initState();
    if (widget.initialMilestones != null) {
      _milestones = List<Map<String, dynamic>>.from(widget.initialMilestones!);
      _initComparisonWeeks();
      _isLoading = false;
    } else {
      _fetchMilestones();
    }
  }

  @override
  void didUpdateWidget(covariant ClientTransformationTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMilestones != null && widget.initialMilestones != oldWidget.initialMilestones) {
      setState(() {
        _milestones = List<Map<String, dynamic>>.from(widget.initialMilestones!);
        _initComparisonWeeks();
      });
    }
  }

  bool _hasAnyPhoto(Map<String, dynamic> m) {
    return (m['frontPhotoUrl'] != null && m['frontPhotoUrl'].toString().isNotEmpty) ||
        (m['sidePhotoUrl'] != null && m['sidePhotoUrl'].toString().isNotEmpty) ||
        (m['backPhotoUrl'] != null && m['backPhotoUrl'].toString().isNotEmpty);
  }

  void _initComparisonWeeks([int? newlyUploadedWeek]) {
    final withPhotos = _milestones.where(_hasAnyPhoto).toList();

    if (withPhotos.length >= 2) {
      if (newlyUploadedWeek != null) {
        // Automatically compare newly uploaded check-in
        final baselineWeek = withPhotos.first['weekNumber'] as int;
        _selectedBeforeWeek = (newlyUploadedWeek == baselineWeek)
            ? (withPhotos.last['weekNumber'] as int)
            : baselineWeek;
        _selectedAfterWeek = newlyUploadedWeek;
      } else {
        // Validate currently selected weeks
        final bool beforeValid = _selectedBeforeWeek != null &&
            withPhotos.any((m) => m['weekNumber'] == _selectedBeforeWeek);
        final bool afterValid = _selectedAfterWeek != null &&
            withPhotos.any((m) => m['weekNumber'] == _selectedAfterWeek);

        if (!beforeValid || !afterValid || _selectedBeforeWeek == _selectedAfterWeek) {
          _selectedBeforeWeek = withPhotos.first['weekNumber'] as int;
          _selectedAfterWeek = withPhotos.last['weekNumber'] as int;
        }
      }
    } else if (withPhotos.length == 1) {
      _selectedBeforeWeek = withPhotos.first['weekNumber'] as int;
      _selectedAfterWeek = null;
    } else {
      _selectedBeforeWeek = null;
      _selectedAfterWeek = null;
    }
  }

  void _showSameWeekWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot compare the same check-in twice. Please select two distinct weeks.'),
        backgroundColor: AppColors.primaryRed,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _swapSelectedWeeks() {
    if (_selectedBeforeWeek == null || _selectedAfterWeek == null) return;
    setState(() {
      final temp = _selectedBeforeWeek;
      _selectedBeforeWeek = _selectedAfterWeek;
      _selectedAfterWeek = temp;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Swapped comparison: Week $_selectedBeforeWeek vs Week $_selectedAfterWeek'),
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyComparison() {
    if (_selectedBeforeWeek == null || _selectedAfterWeek == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select two check-in weeks to compare.'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
      return;
    }
    if (_selectedBeforeWeek == _selectedAfterWeek) {
      _showSameWeekWarning();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comparing Week $_selectedBeforeWeek vs Week $_selectedAfterWeek'),
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _resolvedUrl(String? url) {
    return AppConstants.resolveImageUrl(url, authToken: AuthService().token);
  }

  Future<void> _fetchMilestones({int? newlyUploadedWeek}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = AuthService().token;
      final baseUrl = AppConstants.currentBaseUrl;
      final uri = widget.adminTargetClientId != null
          ? Uri.parse('$baseUrl/admin/clients/${widget.adminTargetClientId}/transformation-timeline')
          : Uri.parse('$baseUrl/client/me/transformation-timeline');

      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _milestones = list.cast<Map<String, dynamic>>();
            _initComparisonWeeks(newlyUploadedWeek);
          });
        }
      } else {
        if (mounted) {
          setState(() => _error = 'Failed to load timeline (${res.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Network error loading transformation timeline: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto({
    required int weekNumber,
    required String angle,
    required ImageSource source,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 2000,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadingAngle = angle;
        _uploadingWeek = weekNumber;
      });

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      final token = AuthService().token;
      final baseUrl = AppConstants.currentBaseUrl;
      final uri = Uri.parse('$baseUrl/client/me/transformation-timeline/upload-photo');

      final Map<String, dynamic> payload = {
        'weekNumber': weekNumber,
        'angle': angle.toLowerCase(),
        'imageBase64': base64String,
        'mimeType': 'image/jpeg',
      };

      if (widget.adminTargetClientId != null) {
        payload['targetClientId'] = widget.adminTargetClientId;
      }

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        await _fetchMilestones(newlyUploadedWeek: weekNumber);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$angle photo for Week $weekNumber saved successfully!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          final errBody = jsonDecode(res.body);
          final msg = errBody['error']?['message'] ?? 'Upload failed (${res.statusCode})';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg'), backgroundColor: AppColors.primaryRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: AppColors.primaryRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingAngle = null;
          _uploadingWeek = null;
        });
      }
    }
  }

  void _showPhotoOptionsSheet({
    required int weekNumber,
    required String angle,
    required String? currentPhotoUrl,
    required Map<String, dynamic> milestone,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'WEEK $weekNumber • $angle ANGLE',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.fullscreen_rounded, color: AppColors.gold),
                  title: const Text('View Full Screen Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFullPhotoDialog(
                      title: 'WEEK $weekNumber • $angle PHOTO',
                      imageUrl: _resolvedUrl(currentPhotoUrl),
                      milestone: milestone,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: Colors.white70),
                  title: const Text('Retake with Camera', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(weekNumber: weekNumber, angle: angle, source: ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.white70),
                  title: const Text('Choose Replacement from Gallery', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(weekNumber: weekNumber, angle: angle, source: ImageSource.gallery);
                  },
                ),
                if (widget.adminTargetClientId == null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppColors.primaryRed),
                    title: const Text('Remove Photo', style: TextStyle(color: AppColors.primaryRed)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deletePhotoAngle(weekNumber, angle);
                    },
                  ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primaryRed),
                  title: const Text('Take Photo with Camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Live capture front, side, or back pose', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(weekNumber: weekNumber, angle: angle, source: ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.gold),
                  title: const Text('Select from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Upload previously taken milestone photo', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(weekNumber: weekNumber, angle: angle, source: ImageSource.gallery);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePhotoAngle(int weekNumber, String angle) async {
    try {
      final token = AuthService().token;
      final baseUrl = AppConstants.currentBaseUrl;
      final uri = Uri.parse('$baseUrl/client/me/transformation-timeline/$weekNumber/photo/${angle.toLowerCase()}');

      final res = await http.delete(uri, headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final previousBefore = _selectedBeforeWeek;
        final previousAfter = _selectedAfterWeek;
        await _fetchMilestones();
        if (mounted) {
          final withPhotos = _milestones.where(_hasAnyPhoto).toList();
          final bool beforeLost = previousBefore != null && !withPhotos.any((m) => m['weekNumber'] == previousBefore);
          final bool afterLost = previousAfter != null && !withPhotos.any((m) => m['weekNumber'] == previousAfter);

          if (beforeLost || afterLost) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Removed photo. Comparison updated to remaining valid check-ins.'),
                backgroundColor: AppColors.surfaceElevated,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Removed $angle photo for Week $weekNumber.'), backgroundColor: AppColors.surfaceElevated),
            );
          }
        }
      }
    } catch (_) {}
  }

  void _openAddMilestoneDialog([int? defaultWeek]) {
    final weightCtrl = TextEditingController();
    final waistCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    int weekNum = defaultWeek ?? 1;
    DateTime selectedDate = DateTime.now();

    // Prepopulate if milestone exists
    final existing = _milestones.firstWhere((m) => m['weekNumber'] == weekNum, orElse: () => {});
    if (existing.isNotEmpty) {
      if (existing['weightKg'] != null) weightCtrl.text = existing['weightKg'].toString();
      if (existing['waistCm'] != null) waistCtrl.text = existing['waistCm'].toString();
      if (existing['notes'] != null) notesCtrl.text = existing['notes'].toString();
      if (existing['date'] != null) {
        selectedDate = DateTime.tryParse(existing['date'].toString()) ?? DateTime.now();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.flag_circle_outlined, color: AppColors.primaryRed, size: 22),
              const SizedBox(width: 8),
              Text(
                'WEEK $weekNum MILESTONE',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Week selector if creating new
                if (defaultWeek == null) ...[
                  const Text('Select Protocol Week:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: weekNum,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: [1, 2, 4, 6, 8, 10, 12, 16, 20, 24]
                        .map((w) => DropdownMenuItem(value: w, child: Text('Week $w ${w == 1 ? "(Baseline)" : ""}')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => weekNum = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Date Picker Tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 18),
                  title: const Text('Milestone Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  subtitle: Text(
                    DateFormat('dd MMMM yyyy').format(selectedDate),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.primaryRed,
                            onPrimary: Colors.white,
                            surface: AppColors.surface,
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const Divider(color: AppColors.borderSubtle),
                const SizedBox(height: 8),

                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Body Weight (kg)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    suffixText: 'kg',
                    suffixStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: waistCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Waist Circumference (cm)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    suffixText: 'cm',
                    suffixStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Transformation Notes',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'Conditioning, energy, muscle fullness, progress...',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveMilestone(
                  weekNum,
                  double.tryParse(weightCtrl.text),
                  double.tryParse(waistCtrl.text),
                  notesCtrl.text.trim(),
                  selectedDate,
                );
              },
              child: const Text('SAVE MILESTONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMilestone(int weekNumber, double? weight, double? waist, String notes, DateTime date) async {
    try {
      final token = AuthService().token;
      final baseUrl = AppConstants.currentBaseUrl;
      final uri = widget.adminTargetClientId != null
          ? Uri.parse('$baseUrl/admin/clients/${widget.adminTargetClientId}/transformation-timeline')
          : Uri.parse('$baseUrl/client/me/transformation-timeline');

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'weekNumber': weekNumber,
          'weightKg': weight,
          'waistCm': waist,
          'notes': notes,
          'date': date.toIso8601String(),
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        _fetchMilestones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Week $weekNumber protocol recorded successfully.'),
              backgroundColor: AppColors.surfaceElevated,
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _showFullPhotoDialog({
    required String title,
    required String imageUrl,
    required Map<String, dynamic>? milestone,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // Interactive Zoomable Image
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 250,
                      child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, color: AppColors.primaryRed, size: 36),
                          SizedBox(height: 8),
                          Text('Failed to load photo binary', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Metrics Summary Bar
            if (milestone != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (milestone['weightKg'] != null)
                      _metricBadge('WEIGHT', '${milestone['weightKg']} kg', AppColors.primaryRed),
                    if (milestone['waistCm'] != null)
                      _metricBadge('WAIST', '${milestone['waistCm']} cm', AppColors.gold),
                    if (milestone['date'] != null)
                      _metricBadge(
                        'LOGGED DATE',
                        DateFormat('dd MMM yyyy').format(DateTime.tryParse(milestone['date'].toString()) ?? DateTime.now()),
                        Colors.lightBlueAccent,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.athleteName != null
        ? '${widget.athleteName!.toUpperCase()} • TRANSFORMATION'
        : 'TRANSFORMATION TIMELINE';

    // Combine default supported weeks and any custom weeks logged
    final loggedWeeks = _milestones.map((m) => m['weekNumber'] as int).toList();
    final allWeeks = {..._defaultSupportedWeeks, ...loggedWeeks}.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Timeline',
            onPressed: _fetchMilestones,
          ),
          if (widget.adminTargetClientId == null)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.gold, size: 22),
              tooltip: 'Add Milestone',
              onPressed: () => _openAddMilestoneDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      ElevatedButton(onPressed: _fetchMilestones, child: const Text('RETRY')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primaryRed,
                  onRefresh: _fetchMilestones,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Prominent Before & After Comparison Hero Card
                      _buildBeforeAfterComparisonCard(),
                      const SizedBox(height: 20),

                      // 2. Protocol Milestones Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.timeline_rounded, color: AppColors.primaryRed, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'PROGRESSION PROTOCOL HISTORY',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.adminTargetClientId == null)
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 14, color: AppColors.gold),
                              label: const Text('ADD WEEK', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => _openAddMilestoneDialog(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. Milestone Timeline Cards
                      ...allWeeks.map((week) {
                        final milestone = _milestones.firstWhere((m) => m['weekNumber'] == week, orElse: () => {});
                        return _buildMilestoneCard(week, milestone);
                      }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  // ==========================================
  // COMPONENT 1: SIDE-BY-SIDE BEFORE & AFTER COMPARISON
  // ==========================================
  Widget _buildBeforeAfterComparisonCard() {
    final withPhotos = _milestones.where(_hasAnyPhoto).toList();

    // 1. If no photos logged yet, show empty state guidance
    if (withPhotos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, color: AppColors.primaryRed, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEFORE & AFTER COMPARISON',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Unlock visual side-by-side progression tracking',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Capture your Week 1 Baseline photos (Front, Side, Back) to automatically unlock side-by-side transformation comparisons against future milestones.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (widget.adminTargetClientId == null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('RECORD WEEK 1 BASELINE PHOTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
                onPressed: () {
                  _showPhotoOptionsSheet(
                    weekNumber: 1,
                    angle: 'FRONT',
                    currentPhotoUrl: null,
                    milestone: {},
                  );
                },
              ),
          ],
        ),
      );
    }

    // 2. If client has only one photo check-in, ask them to upload another before comparing
    if (withPhotos.length == 1) {
      final single = withPhotos.first;
      final singleWeek = single['weekNumber'] ?? 1;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.gold, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 CHECK-IN RECORDED',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Upload another check-in photo to compare',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'You have 1 transformation check-in logged (Week $singleWeek). Upload at least one more check-in photo to unlock side-by-side transformation comparisons!',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (widget.adminTargetClientId == null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('UPLOAD NEXT CHECK-IN PHOTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
                onPressed: () {
                  final nextWeek = (singleWeek == 1) ? 4 : (singleWeek + 4);
                  _openAddMilestoneDialog(nextWeek);
                },
              ),
          ],
        ),
      );
    }

    // 3. Resolve Compare From & Compare With Milestones
    final beforeMilestone = _milestones.firstWhere(
      (m) => m['weekNumber'] == _selectedBeforeWeek,
      orElse: () => withPhotos.first,
    );
    final afterMilestone = _milestones.firstWhere(
      (m) => m['weekNumber'] == _selectedAfterWeek,
      orElse: () => withPhotos.last,
    );

    // Resolve photo URLs according to selected angle
    String? beforePhotoUrl;
    String? afterPhotoUrl;
    if (_comparisonAngle == 'FRONT') {
      beforePhotoUrl = beforeMilestone['frontPhotoUrl'];
      afterPhotoUrl = afterMilestone['frontPhotoUrl'];
    } else if (_comparisonAngle == 'SIDE') {
      beforePhotoUrl = beforeMilestone['sidePhotoUrl'];
      afterPhotoUrl = afterMilestone['sidePhotoUrl'];
    } else {
      beforePhotoUrl = beforeMilestone['backPhotoUrl'];
      afterPhotoUrl = afterMilestone['backPhotoUrl'];
    }

    // Delta calculations
    final beforeWeight = beforeMilestone['weightKg'] != null ? (beforeMilestone['weightKg'] as num).toDouble() : null;
    final afterWeight = afterMilestone['weightKg'] != null ? (afterMilestone['weightKg'] as num).toDouble() : null;
    final weightDelta = (beforeWeight != null && afterWeight != null) ? (afterWeight - beforeWeight) : null;

    final beforeWaist = beforeMilestone['waistCm'] != null ? (beforeMilestone['waistCm'] as num).toDouble() : null;
    final afterWaist = afterMilestone['waistCm'] != null ? (afterMilestone['waistCm'] as num).toDouble() : null;
    final waistDelta = (beforeWaist != null && afterWaist != null) ? (afterWaist - beforeWaist) : null;

    final beforeWeekNum = beforeMilestone['weekNumber'] ?? 1;
    final afterWeekNum = afterMilestone['weekNumber'] ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glowRed.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with View Toggle & Angle Selectors
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.glowRed.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.gold, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'SIDE-BY-SIDE TRANSFORMATION',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(width: 4),
                _angleChip('FRONT'),
                const SizedBox(width: 3),
                _angleChip('SIDE'),
                const SizedBox(width: 3),
                _angleChip('BACK'),
                const SizedBox(width: 5),
                _viewModeChip(_isSliderView ? 'SPLIT' : 'SLIDER', _isSliderView, () => setState(() => _isSliderView = !_isSliderView)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Milestone Selectors: COMPARE FROM, SWAP, COMPARE WITH, COMPARE BUTTON
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _milestoneDropdown(
                        label: 'COMPARE FROM',
                        value: _selectedBeforeWeek ?? beforeWeekNum,
                        excludeValue: _selectedAfterWeek,
                        onChanged: (val) {
                          if (val != null) {
                            if (val == _selectedAfterWeek) {
                              _showSameWeekWarning();
                              return;
                            }
                            setState(() => _selectedBeforeWeek = val);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.gold, size: 20),
                      tooltip: 'Swap comparison weeks',
                      onPressed: _swapSelectedWeeks,
                    ),
                    Expanded(
                      flex: 4,
                      child: _milestoneDropdown(
                        label: 'COMPARE WITH',
                        value: _selectedAfterWeek ?? afterWeekNum,
                        excludeValue: _selectedBeforeWeek,
                        onChanged: (val) {
                          if (val != null) {
                            if (val == _selectedBeforeWeek) {
                              _showSameWeekWarning();
                              return;
                            }
                            setState(() => _selectedAfterWeek = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _applyComparison,
                        child: const Text(
                          'COMPARE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Visual Photos: Interactive Slider or Side-by-Side
                if (_isSliderView) ...[
                  _buildSliderComparisonView(
                    beforePhotoUrl: beforePhotoUrl,
                    afterPhotoUrl: afterPhotoUrl,
                    beforeWeekNum: beforeWeekNum,
                    afterWeekNum: afterWeekNum,
                    beforeDate: beforeMilestone['date'],
                    afterDate: afterMilestone['date'],
                    angle: _comparisonAngle,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _comparisonPhotoBox(
                          tag: 'BEFORE (WEEK $beforeWeekNum)',
                          date: beforeMilestone['date'],
                          weight: beforeWeight,
                          photoUrl: beforePhotoUrl,
                          angle: _comparisonAngle,
                          milestone: beforeMilestone,
                          isBaseline: beforeWeekNum == 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _comparisonPhotoBox(
                          tag: 'AFTER (WEEK $afterWeekNum)',
                          date: afterMilestone['date'],
                          weight: afterWeight,
                          photoUrl: afterPhotoUrl,
                          angle: _comparisonAngle,
                          milestone: afterMilestone,
                          isBaseline: afterWeekNum == 1,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Delta Transformation Metrics Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Weight Delta
                      Column(
                        children: [
                          const Text('WEIGHT CHANGE', style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            weightDelta != null
                                ? '${weightDelta > 0 ? "+" : ""}${weightDelta.toStringAsFixed(1)} kg'
                                : '—',
                            style: TextStyle(
                              color: weightDelta != null
                                  ? (weightDelta < 0 ? AppColors.success : AppColors.gold)
                                  : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 24, color: AppColors.borderSubtle),
                      // Waist Delta
                      Column(
                        children: [
                          const Text('WAIST CHANGE', style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            waistDelta != null
                                ? '${waistDelta > 0 ? "+" : ""}${waistDelta.toStringAsFixed(1)} cm'
                                : '—',
                            style: TextStyle(
                              color: waistDelta != null
                                  ? (waistDelta < 0 ? AppColors.success : AppColors.gold)
                                  : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 24, color: AppColors.borderSubtle),
                      // Time Span
                      Column(
                        children: [
                          const Text('DURATION', style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '${(afterWeekNum - beforeWeekNum).abs()} Weeks',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewModeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : Colors.black26,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppColors.gold : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: 9.0,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderComparisonView({
    required String? beforePhotoUrl,
    required String? afterPhotoUrl,
    required int beforeWeekNum,
    required int afterWeekNum,
    required dynamic beforeDate,
    required dynamic afterDate,
    required String angle,
  }) {
    final resolvedBefore = _resolvedUrl(beforePhotoUrl);
    final resolvedAfter = _resolvedUrl(afterPhotoUrl);

    if (resolvedBefore.isEmpty || resolvedAfter.isEmpty) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_not_supported_outlined, color: AppColors.textTertiary, size: 36),
                const SizedBox(height: 8),
                Text(
                  'Both Week $beforeWeekNum and Week $afterWeekNum require a $angle photo for the slider view.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    DateTime? dtBefore;
    if (beforeDate != null) dtBefore = DateTime.tryParse(beforeDate.toString());
    final beforeDateStr = dtBefore != null ? DateFormat('dd MMM yyyy').format(dtBefore) : '—';

    DateTime? dtAfter;
    if (afterDate != null) dtAfter = DateTime.tryParse(afterDate.toString());
    final afterDateStr = dtAfter != null ? DateFormat('dd MMM yyyy').format(dtAfter) : '—';

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final splitX = totalWidth * _sliderPosition;

          final beforeWidget = Image.network(
            resolvedBefore,
            fit: BoxFit.cover,
            width: totalWidth,
            height: constraints.maxHeight,
            errorBuilder: (_, __, ___) => _buildPhotoErrorPlaceholder(angle),
          );

          final afterWidget = Image.network(
            resolvedAfter,
            fit: BoxFit.cover,
            width: totalWidth,
            height: constraints.maxHeight,
            errorBuilder: (_, __, ___) => _buildPhotoErrorPlaceholder(angle),
          );

          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sliderPosition = (details.localPosition.dx / totalWidth).clamp(0.05, 0.95);
              });
            },
            child: Stack(
              children: [
                // 1. Full AFTER image in background
                Positioned.fill(child: afterWidget),

                // 2. BEFORE image clipped to splitX on the left
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: splitX,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: totalWidth,
                      maxWidth: totalWidth,
                      minHeight: constraints.maxHeight,
                      maxHeight: constraints.maxHeight,
                      child: beforeWidget,
                    ),
                  ),
                ),

                // 3. Vertical Divider Line
                Positioned(
                  left: splitX - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: AppColors.gold),
                ),

                // 4. Circular Slider Handle
                Positioned(
                  left: splitX - 16,
                  top: (constraints.maxHeight - 32) / 2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                    ),
                    child: const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
                  ),
                ),

                // 5. Left (Before) Label Overlay
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'WEEK $beforeWeekNum • $beforeDateStr',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 9.5),
                    ),
                  ),
                ),

                // 6. Right (After) Label Overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'WEEK $afterWeekNum • $afterDateStr',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9.5),
                    ),
                  ),
                ),

                // 7. Bottom Drag Instruction Hint
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '◀ Drag handle left or right to compare ▶',
                        style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _angleChip(String angle) {
    final isSelected = _comparisonAngle == angle;
    return GestureDetector(
      onTap: () => setState(() => _comparisonAngle = angle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : Colors.black26,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppColors.primaryRed : AppColors.border),
        ),
        child: Text(
          angle,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: 9.5,
          ),
        ),
      ),
    );
  }

  Widget _milestoneDropdown({
    required String label,
    required int value,
    int? excludeValue,
    required ValueChanged<int?> onChanged,
  }) {
    final eligible = _milestones.where(_hasAnyPhoto).toList();
    final available = eligible.map((m) => m['weekNumber'] as int).toSet().toList()..sort();
    if (available.isEmpty && !available.contains(value)) available.add(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: available.contains(value) ? value : (available.isNotEmpty ? available.first : null),
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
              items: available.map((w) {
                final m = eligible.firstWhere((item) => item['weekNumber'] == w, orElse: () => {});
                DateTime? dt;
                if (m['date'] != null) dt = DateTime.tryParse(m['date'].toString());
                final dateStr = dt != null ? ' (${DateFormat('dd MMM').format(dt)})' : '';
                final baselineStr = (w == 1) ? ' (Baseline)' : '';
                final isExcluded = (excludeValue != null && w == excludeValue);

                return DropdownMenuItem<int>(
                  value: w,
                  enabled: !isExcluded,
                  child: Text(
                    'Week $w$baselineStr$dateStr${isExcluded ? " (Selected)" : ""}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isExcluded ? AppColors.textTertiary : Colors.white,
                      fontWeight: isExcluded ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _comparisonPhotoBox({
    required String tag,
    required dynamic date,
    required double? weight,
    required String? photoUrl,
    required String angle,
    required Map<String, dynamic> milestone,
    required bool isBaseline,
  }) {
    DateTime? dt;
    if (date != null) dt = DateTime.tryParse(date.toString());
    final dateDisplay = dt != null ? DateFormat('dd MMM yyyy').format(dt) : '—';
    final resolved = _resolvedUrl(photoUrl);

    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Photo content
          Positioned.fill(
            child: (resolved.isNotEmpty)
                ? GestureDetector(
                    onTap: () => _showFullPhotoDialog(
                      title: '$tag • $angle',
                      imageUrl: resolved,
                      milestone: milestone,
                    ),
                    child: Image.network(
                      resolved,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPhotoErrorPlaceholder(angle),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed));
                      },
                    ),
                  )
                : _buildNoPhotoActionBox(
                    weekNumber: milestone['weekNumber'] ?? 1,
                    angle: angle,
                    milestone: milestone,
                  ),
          ),
          // Top Overlay Label
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: Colors.black.withOpacity(0.65),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tag,
                    style: TextStyle(
                      color: isBaseline ? AppColors.gold : Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (weight != null)
                    Text(
                      '${weight.toStringAsFixed(1)} kg',
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
          // Bottom Date Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.black.withOpacity(0.65),
              child: Text(
                dateDisplay,
                style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPONENT 2: MILESTONE CARD IN PROTOCOL LIST
  // ==========================================
  Widget _buildMilestoneCard(int week, Map<String, dynamic> milestone) {
    final hasData = milestone.isNotEmpty;
    DateTime date = DateTime.now();
    if (hasData && milestone['date'] != null) {
      date = DateTime.tryParse(milestone['date'].toString()) ?? DateTime.now();
    }
    final dateDisplay = DateFormat('dd MMM yyyy').format(date);

    final frontUrl = milestone['frontPhotoUrl'] as String?;
    final sideUrl = milestone['sidePhotoUrl'] as String?;
    final backUrl = milestone['backPhotoUrl'] as String?;

    final isBaseline = week == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasData ? AppColors.primaryRed.withOpacity(0.4) : AppColors.border,
          width: hasData ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: hasData ? AppColors.glowRed.withOpacity(0.2) : AppColors.surfaceElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasData ? AppColors.primaryRed : Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isBaseline ? 'WEEK 1 BASELINE' : 'WEEK $week PROTOCOL',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'WEEK $week',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 9.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasData ? dateDisplay : 'Upcoming Protocol Milestone',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasData ? Colors.white : AppColors.textTertiary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.adminTargetClientId == null) ...[
                  IconButton(
                    icon: Icon(hasData ? Icons.edit_outlined : Icons.add_circle_outline, size: 18, color: AppColors.gold),
                    tooltip: hasData ? 'Edit Metrics / Date' : 'Log Milestone',
                    onPressed: () => _openAddMilestoneDialog(week),
                  ),
                ],
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasData) ...[
                  // Badges: Weight, Waist
                  Row(
                    children: [
                      if (milestone['weightKg'] != null)
                        _metricBadge('WEIGHT', '${milestone['weightKg']} kg', AppColors.primaryRed),
                      if (milestone['waistCm'] != null) ...[
                        const SizedBox(width: 8),
                        _metricBadge('WAIST', '${milestone['waistCm']} cm', AppColors.gold),
                      ],
                      const Spacer(),
                      Text(
                        dateDisplay,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                  if (milestone['notes'] != null && milestone['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '“${milestone['notes']}”',
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],

                // 3 Angle Photo Thumbnails
                Row(
                  children: [
                    Expanded(
                      child: _photoAngleThumbnail(
                        weekNumber: week,
                        angle: 'FRONT',
                        photoUrl: frontUrl,
                        milestone: milestone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _photoAngleThumbnail(
                        weekNumber: week,
                        angle: 'SIDE',
                        photoUrl: sideUrl,
                        milestone: milestone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _photoAngleThumbnail(
                        weekNumber: week,
                        angle: 'BACK',
                        photoUrl: backUrl,
                        milestone: milestone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoAngleThumbnail({
    required int weekNumber,
    required String angle,
    required String? photoUrl,
    required Map<String, dynamic> milestone,
  }) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final resolved = _resolvedUrl(photoUrl);
    final isUploadingThis = _isUploading && _uploadingWeek == weekNumber && _uploadingAngle == angle;

    return GestureDetector(
      onTap: () => _showPhotoOptionsSheet(
        weekNumber: weekNumber,
        angle: angle,
        currentPhotoUrl: photoUrl,
        milestone: milestone,
      ),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasPhoto ? AppColors.success.withOpacity(0.6) : AppColors.borderSubtle,
            width: hasPhoto ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isUploadingThis) ...[
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)),
                    SizedBox(height: 6),
                    Text('Saving...', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ] else if (hasPhoto && resolved.isNotEmpty) ...[
              Positioned.fill(
                child: Image.network(
                  resolved,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPhotoErrorPlaceholder(angle),
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)),
                    );
                  },
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.adminTargetClientId == null ? Icons.add_a_photo_outlined : Icons.photo_camera_outlined,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      angle,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    if (widget.adminTargetClientId == null)
                      const Text(
                        '+ UPLOAD',
                        style: TextStyle(color: AppColors.primaryRed, fontSize: 8.5, fontWeight: FontWeight.w900),
                      ),
                  ],
                ),
              ),
            ],
            // Bottom Angle Pill
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.black.withOpacity(0.65),
                child: Text(
                  angle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hasPhoto ? AppColors.success : Colors.white70,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPhotoActionBox({
    required int weekNumber,
    required String angle,
    required Map<String, dynamic> milestone,
  }) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.textTertiary, size: 28),
            const SizedBox(height: 6),
            Text(
              'No $angle Photo',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            if (widget.adminTargetClientId == null) ...[
              const SizedBox(height: 6),
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                onPressed: () => _showPhotoOptionsSheet(
                  weekNumber: weekNumber,
                  angle: angle,
                  currentPhotoUrl: null,
                  milestone: milestone,
                ),
                child: const Text('UPLOAD NOW', style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoErrorPlaceholder(String angle) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined, color: AppColors.primaryRed, size: 26),
            const SizedBox(height: 6),
            const Text('Photo expired or unavailable', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('$angle Angle', style: const TextStyle(color: AppColors.textTertiary, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 1),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
