import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class AdminAttentionCenterView extends StatefulWidget {
  final Function(Map<String, dynamic> client)? onSelectClientProfile;

  const AdminAttentionCenterView({
    super.key,
    this.onSelectClientProfile,
  });

  @override
  State<AdminAttentionCenterView> createState() => _AdminAttentionCenterViewState();
}

class _AdminAttentionCenterViewState extends State<AdminAttentionCenterView> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _items = [];
  Map<String, dynamic> _counts = {};
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  final List<String> _filters = [
    'ALL',
    'PAIN_REPORTED',
    'INACTIVE',
    'MISSED_WORKOUT',
    'MISSING_CHECKIN',
    'MISSING_FOOD',
    'LOW_PROTEIN',
    'MEMBERSHIP_EXPIRING',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAttentionItems();
  }

  Future<void> _fetchAttentionItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = AuthService().token;
      final baseUrl = AppConstants.currentBaseUrl;
      final queryParams = <String, String>{};
      if (_selectedFilter != 'ALL') queryParams['type'] = _selectedFilter;
      if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;

      final uri = Uri.parse('$baseUrl/admin/attention-center').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        if (mounted) {
          setState(() {
            _items = (data['items'] as List?) ?? [];
            _counts = (data['counts'] as Map<String, dynamic>?) ?? {};
          });
        }
      } else {
        if (mounted) setState(() => _error = 'Failed to load attention items (${res.statusCode})');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewItem(String id, String title) async {
    final noteCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        title: Text('REVIEW: $title', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a coach action note to mark this data indicator as reviewed:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'e.g. Advised athlete on recovery protocol...',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('MARK REVIEWED', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final token = AuthService().token;
        final baseUrl = AppConstants.currentBaseUrl;
        final uri = Uri.parse('$baseUrl/admin/attention-items/$id/review');
        await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'coachNotes': noteCtrl.text.trim()}),
        );
        _fetchAttentionItems();
      } catch (_) {}
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Colors.redAccent;
      case 'HIGH':
        return Colors.orangeAccent;
      case 'MEDIUM':
        return AppColors.gold;
      case 'LOW':
      default:
        return Colors.lightBlueAccent;
    }
  }

  String _severityIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PAIN_REPORTED':
        return '🔴';
      case 'INACTIVE':
        return '🔴';
      case 'MISSED_WORKOUT':
        return '🟠';
      case 'MISSING_CHECKIN':
        return '🟠';
      case 'MISSING_FOOD':
        return '🟠';
      case 'LOW_PROTEIN':
        return '🟠';
      case 'MEMBERSHIP_EXPIRING':
        return '🟡';
      default:
        return '🟢';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreviewedCount = _counts['unreviewed'] ?? 0;
    final criticalCount = _counts['critical'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Operational Overview Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: criticalCount > 0 ? Colors.redAccent.withOpacity(0.5) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (criticalCount > 0 ? Colors.redAccent : AppColors.primaryRed).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        criticalCount > 0 ? Icons.warning_amber_rounded : Icons.radar_outlined,
                        color: criticalCount > 0 ? Colors.redAccent : AppColors.primaryRed,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CLIENT ATTENTION CENTER',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                      ),
                      Text(
                        'AUTOMATED DATA-BASED COACHING INDICATORS',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _fetchAttentionItems,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Objective data alerts requiring coach review: missed sessions, pain reports, missing nutrition logs, and membership status.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _summaryPill('UNREVIEWED', '$unreviewedCount', unreviewedCount > 0 ? AppColors.gold : AppColors.textTertiary),
                  const SizedBox(width: 8),
                  _summaryPill('CRITICAL (PAIN)', '$criticalCount', criticalCount > 0 ? Colors.redAccent : AppColors.textTertiary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Search Field
        TextField(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by athlete name or Client ID (AXG-XXXX)...',
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
          onChanged: (val) {
            _searchQuery = val;
            _fetchAttentionItems();
          },
        ),
        const SizedBox(height: 14),

        // 3. Category Filter Chips
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final f = _filters[idx];
              final isSelected = _selectedFilter == f;
              final label = f.replaceAll('_', ' ');

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: AppColors.primaryRed,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppColors.primaryRed : AppColors.border)),
                onSelected: (val) {
                  setState(() => _selectedFilter = f);
                  _fetchAttentionItems();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // 4. Attention Items List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
          )
        else if (_error != null)
          Center(
            child: Column(
              children: [
                Text(_error!, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _fetchAttentionItems, child: const Text('RETRY')),
              ],
            ),
          )
        else if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 40),
                SizedBox(height: 10),
                Text('🟢 ALL ATHLETES CONSISTENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 4),
                Text('No active attention flags detected for the selected criteria.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          )
        else
          ..._items.map((item) {
            final id = item['id']?.toString() ?? '';
            final type = item['attentionType']?.toString() ?? 'SYSTEM';
            final severity = item['severity']?.toString() ?? 'MEDIUM';
            final title = item['title']?.toString() ?? 'Attention Alert';
            final details = item['details']?.toString() ?? '';
            final clientName = item['clientName']?.toString() ?? 'Athlete';
            final clientId = item['clientId']?.toString() ?? '';
            final isReviewed = item['isReviewed'] == true;
            final coachNotes = item['coachNotes']?.toString();
            final color = _severityColor(severity);
            final emoji = _severityIcon(type);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isReviewed ? AppColors.surface.withOpacity(0.6) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isReviewed ? AppColors.borderSubtle : color.withOpacity(0.5),
                  width: isReviewed ? 1.0 : 1.4,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Athlete & Severity
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$clientName ($clientId)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              decoration: isReviewed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Text(
                            severity.toUpperCase(),
                            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title & Description
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                    ),

                    if (coachNotes != null && coachNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Coach Note: $coachNotes',
                                style: const TextStyle(color: AppColors.success, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isReviewed)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: color.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.rate_review_outlined, size: 14),
                            label: const Text('REVIEW & NOTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _reviewItem(id, title),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.lightBlueAccent),
                          label: const Text('CONTACT', style: TextStyle(fontSize: 11, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Direct coach message drafted for $clientName.'),
                                backgroundColor: AppColors.surfaceElevated,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _summaryPill(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
