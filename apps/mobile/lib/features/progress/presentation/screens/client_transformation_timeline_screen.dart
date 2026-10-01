import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _milestones = [];

  final List<int> _supportedWeeks = [1, 4, 8, 12, 16];

  @override
  void initState() {
    super.initState();
    if (widget.initialMilestones != null) {
      _milestones = widget.initialMilestones!;
      _isLoading = false;
    } else {
      _fetchMilestones();
    }
  }

  Future<void> _fetchMilestones() async {
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

  void _openAddMilestoneDialog(int weekNumber) {
    final weightCtrl = TextEditingController();
    final waistCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    // Prepopulate if milestone exists
    final existing = _milestones.firstWhere((m) => m['weekNumber'] == weekNumber, orElse: () => {});
    if (existing.isNotEmpty) {
      if (existing['weightKg'] != null) weightCtrl.text = existing['weightKg'].toString();
      if (existing['waistCm'] != null) waistCtrl.text = existing['waistCm'].toString();
      if (existing['notes'] != null) notesCtrl.text = existing['notes'].toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'WEEK $weekNumber MILESTONE',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
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
                hintText: 'Energy, physique changes, strength progression...',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ),
          ],
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
                weekNumber,
                double.tryParse(weightCtrl.text),
                double.tryParse(waistCtrl.text),
                notesCtrl.text.trim(),
              );
            },
            child: const Text('SAVE MILESTONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMilestone(int weekNumber, double? weight, double? waist, String notes) async {
    try {
      final token = AuthService().token;
      final baseUrl = AppConstants.currentBaseUrl;
      final uri = Uri.parse('$baseUrl/client/me/transformation-timeline');

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
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        _fetchMilestones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Week $weekNumber milestone recorded successfully.'),
              backgroundColor: AppColors.surfaceElevated,
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.athleteName != null
        ? '${widget.athleteName!.toUpperCase()} • TRANSFORMATION'
        : 'TRANSFORMATION TIMELINE';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchMilestones,
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
                      Text(_error!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchMilestones, child: const Text('RETRY')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header Guidance Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timeline_rounded, color: AppColors.primaryRed, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'PROGRESSIVE OVERLOAD & PHYSIQUE PROGRESSION',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Track factual visual and anthropometric milestones across Week 1 (Baseline), Week 4, Week 8, and Week 12. Photos and measurements remain strictly private to you and your authorized coach.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Milestone Timeline Cards
                    ..._supportedWeeks.map((week) {
                      final milestone = _milestones.firstWhere((m) => m['weekNumber'] == week, orElse: () => {});
                      final hasData = milestone.isNotEmpty;

                      DateTime date = DateTime.now();
                      if (hasData && milestone['date'] != null) {
                        date = DateTime.tryParse(milestone['date'].toString()) ?? DateTime.now();
                      }
                      final dateDisplay = DateFormat('dd MMM yyyy').format(date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasData ? AppColors.primaryRed.withOpacity(0.5) : AppColors.border,
                            width: hasData ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: hasData ? AppColors.glowRed.withOpacity(0.3) : AppColors.surfaceElevated,
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
                                      'WEEK $week',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    hasData ? dateDisplay : 'Upcoming Protocol Milestone',
                                    style: TextStyle(
                                      color: hasData ? Colors.white : AppColors.textTertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.adminTargetClientId == null)
                                    IconButton(
                                      icon: Icon(hasData ? Icons.edit_outlined : Icons.add_circle_outline, size: 18, color: AppColors.gold),
                                      tooltip: hasData ? 'Edit Milestone' : 'Record Milestone',
                                      onPressed: () => _openAddMilestoneDialog(week),
                                    ),
                                ],
                              ),
                            ),

                            // Body
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: hasData
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (milestone['weightKg'] != null)
                                              _metricBadge('WEIGHT', '${milestone['weightKg']} kg', AppColors.primaryRed),
                                            if (milestone['waistCm'] != null) ...[
                                              const SizedBox(width: 10),
                                              _metricBadge('WAIST', '${milestone['waistCm']} cm', AppColors.gold),
                                            ],
                                          ],
                                        ),
                                        if (milestone['notes'] != null && milestone['notes'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Notes: ${milestone['notes']}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        // 3 Photo Angle Placeholders / Real viewer
                                        Row(
                                          children: [
                                            Expanded(child: _photoAngleBox('FRONT', milestone['frontPhotoUrl'])),
                                            const SizedBox(width: 8),
                                            Expanded(child: _photoAngleBox('SIDE', milestone['sidePhotoUrl'])),
                                            const SizedBox(width: 8),
                                            Expanded(child: _photoAngleBox('BACK', milestone['backPhotoUrl'])),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lock_clock_outlined, color: AppColors.textTertiary, size: 16),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'No entries logged yet for this milestone.',
                                            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                                          ),
                                          const Spacer(),
                                          if (widget.adminTargetClientId == null)
                                            TextButton(
                                              onPressed: () => _openAddMilestoneDialog(week),
                                              child: const Text('LOG NOW', style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  Widget _metricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _photoAngleBox(String angle, String? photoUrl) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: photoUrl != null ? AppColors.success : AppColors.textTertiary, size: 20),
            const SizedBox(height: 4),
            Text(
              angle,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
