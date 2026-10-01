import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/motivational_quote_card.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/weekly_progress_charts.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/coach_review_card.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/coach_review_dialog.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/weekly_comparison_sheet.dart';

class AdminWeeklyProgressScreen extends StatefulWidget {
  final WeeklyProgressRepository repository;
  final String? initialClientId;

  const AdminWeeklyProgressScreen({
    super.key,
    required this.repository,
    this.initialClientId,
  });

  @override
  State<AdminWeeklyProgressScreen> createState() => _AdminWeeklyProgressScreenState();
}

class _AdminWeeklyProgressScreenState extends State<AdminWeeklyProgressScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  Map<String, dynamic>? _selectedClient;

  bool _isLoadingClients = true;
  bool _isLoadingClientData = false;

  List<WeeklyCheckIn> _clientHistory = [];
  WeeklyCheckIn? _selectedCheckIn;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoadingClients = true);
    try {
      final token = AuthService().token;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients');
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = (decoded['data'] ?? decoded) as List<dynamic>? ?? [];
        _allClients = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _filteredClients = List.from(_allClients);

        // Pre-select initial client if provided, else first client
        if (widget.initialClientId != null && widget.initialClientId!.isNotEmpty) {
          final found = _allClients.firstWhere(
            (c) => c['id'] == widget.initialClientId || c['clientId'] == widget.initialClientId,
            orElse: () => _allClients.isNotEmpty ? _allClients.first : {},
          );
          if (found.isNotEmpty) _selectClient(found);
        } else if (_allClients.isNotEmpty) {
          _selectClient(_allClients.first);
        }
      }
    } catch (e) {
      debugPrint('[AdminWeeklyProgressScreen] _loadClients error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingClients = false);
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredClients = List.from(_allClients);
      } else {
        _filteredClients = _allClients.where((c) {
          final name = (c['name'] ?? '').toString().toLowerCase();
          final email = (c['email'] ?? '').toString().toLowerCase();
          return name.contains(q) || email.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _selectClient(Map<String, dynamic> client) async {
    setState(() {
      _selectedClient = client;
      _isLoadingClientData = true;
      _clientHistory = [];
      _selectedCheckIn = null;
    });

    final clientId = (client['id'] ?? client['clientId'] ?? '').toString();
    try {
      final progressData = await widget.repository.fetchAdminClientWeeklyProgress(clientId);
      if (mounted) {
        setState(() {
          _clientHistory = progressData['history'] as List<WeeklyCheckIn>? ?? [];
          _analytics = progressData['analytics'] as Map<String, dynamic>?;
          _selectedCheckIn = progressData['latestCheckIn'] as WeeklyCheckIn? ??
              (_clientHistory.isNotEmpty ? _clientHistory.first : null);
          _isLoadingClientData = false;
        });
      }
    } catch (e) {
      debugPrint('[AdminWeeklyProgressScreen] Error fetching client progress: $e');
      if (mounted) {
        setState(() => _isLoadingClientData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading weekly progress: $e'), backgroundColor: AlphaXColors.error),
        );
      }
    }
  }

  void _openComparisonSheet() {
    if (_clientHistory.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 2 weekly check-ins are required to perform a comparison.'),
          backgroundColor: AlphaXColors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: WeeklyComparisonSheet(history: _clientHistory),
      ),
    );
  }

  void _openCoachReviewDialog(WeeklyCheckIn checkIn) {
    final clientId = (_selectedClient?['id'] ?? _selectedClient?['clientId'] ?? '').toString();

    showDialog<WeeklyCheckIn>(
      context: context,
      builder: (_) => CoachReviewDialog(
        clientId: clientId,
        checkIn: checkIn,
        repository: widget.repository,
        onReviewSaved: (updated) {
          setState(() {
            final idx = _clientHistory.indexWhere((c) => c.id == updated.id);
            if (idx != -1) _clientHistory[idx] = updated;
            if (_selectedCheckIn?.id == updated.id) _selectedCheckIn = updated;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlphaXColors.background,
      appBar: AppBar(
        backgroundColor: AlphaXColors.surface,
        title: const Text(
          'CLIENT WEEKLY PROGRESS',
          style: TextStyle(
            color: AlphaXColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: AlphaXColors.textPrimary),
        actions: [
          if (_clientHistory.length >= 2)
            IconButton(
              icon: const Icon(Icons.compare_arrows_rounded, color: AlphaXColors.gold),
              tooltip: 'Compare Weeks',
              onPressed: _openComparisonSheet,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingClients
            ? const Center(child: CircularProgressIndicator(color: AlphaXColors.redAccent))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth >= 900;
                  if (isWideScreen) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: _buildClientSelectorSidebar(),
                        ),
                        const VerticalDivider(color: AlphaXColors.border, width: 1),
                        Expanded(
                          child: _buildMainProgressContent(),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildMobileClientDropdown(),
                        Expanded(child: _buildMainProgressContent()),
                      ],
                    );
                  }
                },
              ),
      ),
    );
  }

  /// Wide Screen Client Selector Sidebar
  Widget _buildClientSelectorSidebar() {
    return Container(
      color: AlphaXColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search client...',
                hintStyle: const TextStyle(color: AlphaXColors.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: AlphaXColors.textSecondary, size: 18),
                filled: true,
                fillColor: AlphaXColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const Divider(color: AlphaXColors.border, height: 1),
          Expanded(
            child: _filteredClients.isEmpty
                ? const Center(child: Text('No clients found', style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 12)))
                : ListView.separated(
                    itemCount: _filteredClients.length,
                    separatorBuilder: (_, _) => const Divider(color: AlphaXColors.border, height: 1),
                    itemBuilder: (context, idx) {
                      final c = _filteredClients[idx];
                      final isSelected = _selectedClient?['id'] == c['id'];
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: AlphaXColors.redAccent.withValues(alpha: 0.15),
                        title: Text(
                          c['name'] ?? 'Athlete',
                          style: TextStyle(
                            color: isSelected ? AlphaXColors.textPrimary : AlphaXColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          c['email'] ?? '',
                          style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
                        ),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isSelected ? AlphaXColors.redAccent : AlphaXColors.surfaceElevated,
                          child: Text(
                            (c['name'] ?? 'A').toString().substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : AlphaXColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => _selectClient(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Mobile Screen Client Dropdown Header
  Widget _buildMobileClientDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AlphaXColors.surface,
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AlphaXColors.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                value: _selectedClient,
                dropdownColor: AlphaXColors.surfaceElevated,
                hint: const Text('Select Client', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 13)),
                items: _allClients.map((client) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: client,
                    child: Text(
                      client['name'] ?? 'Athlete',
                      style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _selectClient(val);
                },
              ),
            ),
          ),
          if (_clientHistory.length >= 2) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _openComparisonSheet,
              icon: const Icon(Icons.compare_arrows_rounded, color: AlphaXColors.gold, size: 16),
              label: const Text('Compare', style: TextStyle(color: AlphaXColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  /// Main Progress Details Content
  Widget _buildMainProgressContent() {
    if (_isLoadingClientData) {
      return const Center(child: CircularProgressIndicator(color: AlphaXColors.redAccent));
    }

    if (_selectedClient == null) {
      return const Center(
        child: Text('Select a client to inspect weekly progress', style: TextStyle(color: AlphaXColors.textTertiary)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Motivational Fitness Quote inside premium card
          const MotivationalQuoteCard(),
          const SizedBox(height: 16),

          // 2. Client Header Banner with Analytics
          _buildClientHeaderBox(),
          const SizedBox(height: 16),

          if (_clientHistory.isEmpty)
            _buildNoCheckInsNotice()
          else ...[
            // 3. Clickable Timeline of Weeks
            _buildTimelineHeader(),
            const SizedBox(height: 16),

            if (_selectedCheckIn != null) ...[
              // 4. Pain Alert Banner (if pain reported)
              if (_selectedCheckIn!.hasPain) ...[
                _buildPainAlertBox(_selectedCheckIn!),
                const SizedBox(height: 14),
              ],

              // 5. Weight & Waist Progress Line Graphs
              WeightProgressChartCard(checkIns: _clientHistory),
              const SizedBox(height: 12),

              WaistProgressChartCard(checkIns: _clientHistory),
              const SizedBox(height: 12),

              // 6. Workout & Nutrition Consistency Cards
              WorkoutConsistencyCard(checkIn: _selectedCheckIn!),
              const SizedBox(height: 12),

              NutritionConsistencyCard(checkIn: _selectedCheckIn!),
              const SizedBox(height: 12),

              // 7. Sleep & Recovery and Habit Overview
              SleepRecoveryCard(checkIn: _selectedCheckIn!),
              const SizedBox(height: 12),

              WeeklyHabitOverviewCard(checkIn: _selectedCheckIn!),
              const SizedBox(height: 12),

              // 8. Reported Problems & Client Notes
              _buildProblemsAndNotesCard(_selectedCheckIn!),
              const SizedBox(height: 12),

              // 9. Coach Review Box with Add/Edit Action
              CoachReviewCard(
                checkIn: _selectedCheckIn!,
                isAdmin: true,
                onEditReview: () => _openCoachReviewDialog(_selectedCheckIn!),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildClientHeaderBox() {
    final name = _selectedClient?['name'] ?? 'Athlete';
    final email = _selectedClient?['email'] ?? '';
    final totalCompleted = _analytics?['totalCompleted'] ?? _clientHistory.length;
    final avgSleep = _analytics?['avgSleep'] != null
        ? '${(_analytics!['avgSleep'] as num).toStringAsFixed(1)}h'
        : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    email,
                    style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
              if (_clientHistory.length >= 2)
                ElevatedButton.icon(
                  onPressed: _openComparisonSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AlphaXColors.surfaceElevated,
                    foregroundColor: AlphaXColors.gold,
                    side: const BorderSide(color: AlphaXColors.gold, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                  label: const Text('Compare Weeks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  label: 'Completed Check-Ins',
                  value: '$totalCompleted Weeks',
                  icon: Icons.check_circle_outline_rounded,
                  color: AlphaXColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricPill(
                  label: 'Average Sleep',
                  value: avgSleep,
                  icon: Icons.bedtime_outlined,
                  color: const Color(0xFF29B6F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 10)),
                Text(
                  value,
                  style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Clickable Timeline of Weeks
  Widget _buildTimelineHeader() {
    final sorted = List<WeeklyCheckIn>.from(_clientHistory)
      ..sort((a, b) => b.weekNumber.compareTo(a.weekNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PROGRESS TIMELINE',
              style: TextStyle(
                color: AlphaXColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Showing Week ${_selectedCheckIn?.weekNumber ?? 1}',
              style: const TextStyle(color: AlphaXColors.redAccent, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final item = sorted[idx];
              final isSelected = _selectedCheckIn?.id == item.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCheckIn = item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AlphaXColors.redAccent : AlphaXColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AlphaXColors.redAccent : AlphaXColors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Week ${item.weekNumber}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AlphaXColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (item.hasPain) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.circle, color: AlphaXColors.warning, size: 6),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Pain Alert Box for Admin Attention
  Widget _buildPainAlertBox(WeeklyCheckIn c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AlphaXColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: AlphaXColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'ATHLETE REPORTED PAIN (Pain Level ${c.painLevel ?? "?"}/10)',
                style: const TextStyle(
                  color: AlphaXColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (c.painLocation != null)
            Text('Location: ${c.painLocation}', style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (c.painExercise != null && c.painExercise!.isNotEmpty)
            Text('Exercise Involved: ${c.painExercise}', style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12)),
          if (c.painDescription != null && c.painDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Description: "${c.painDescription}"', style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Alpha X non-diagnostic notice: Athlete reports are collected for training volume and exercise modification.',
            style: TextStyle(color: AlphaXColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Problems and Notes Card
  Widget _buildProblemsAndNotesCard(WeeklyCheckIn c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AlphaXColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.comment_bank_rounded, color: AlphaXColors.gold, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'CLIENT NOTES & REPORTED PROBLEMS',
                style: TextStyle(
                  color: AlphaXColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Obstacles / Challenges Reported:', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (c.weeklyProblems.isEmpty)
            const Text('• No obstacles reported for this week.', style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 12))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: c.weeklyProblems.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Text(p, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 11)),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          const Text('Client Message to Coach:', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AlphaXColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AlphaXColors.border),
            ),
            child: Text(
              (c.clientNotes != null && c.clientNotes!.isNotEmpty)
                  ? c.clientNotes!
                  : 'No personal notes provided for this week.',
              style: TextStyle(
                color: (c.clientNotes != null && c.clientNotes!.isNotEmpty)
                    ? AlphaXColors.textPrimary
                    : AlphaXColors.textTertiary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCheckInsNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, color: AlphaXColors.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text(
            '${_selectedClient?['name'] ?? 'Athlete'} has not submitted any weekly check-ins yet.',
            style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Once the athlete completes their Week 1 check-in, graphs, metrics, and coach review will appear automatically.',
            style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
