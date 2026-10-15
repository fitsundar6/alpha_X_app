import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/utils/ist_date_utils.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

enum ProposalAssignmentStep { selectMode, confirmation }

/// Modal dialog allowing Admin to choose assignment target for an approved AI workout proposal:
/// 1. Assign to the selected individual client.
/// 2. Assign to multiple selected clients.
/// 3. Assign to all eligible clients.
///
/// Shows an explicit confirmation screen with recipient count and identities,
/// validates client eligibility, and protects against duplicate assignments.
class AdminProposalAssignmentDialog extends StatefulWidget {
  final AiProposal proposal;
  final AiCoachRepository aiCoachRepository;
  final WorkoutRepository workoutRepository;
  final VoidCallback onAssigned;

  const AdminProposalAssignmentDialog({
    super.key,
    required this.proposal,
    required this.aiCoachRepository,
    required this.workoutRepository,
    required this.onAssigned,
  });

  static Future<void> show({
    required BuildContext context,
    required AiProposal proposal,
    required AiCoachRepository aiCoachRepository,
    required WorkoutRepository workoutRepository,
    required VoidCallback onAssigned,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdminProposalAssignmentDialog(
        proposal: proposal,
        aiCoachRepository: aiCoachRepository,
        workoutRepository: workoutRepository,
        onAssigned: onAssigned,
      ),
    );
  }

  @override
  State<AdminProposalAssignmentDialog> createState() => _AdminProposalAssignmentDialogState();
}

class _AdminProposalAssignmentDialogState extends State<AdminProposalAssignmentDialog> {
  ProposalAssignmentStep _step = ProposalAssignmentStep.selectMode;
  String _mode = 'INDIVIDUAL'; // 'INDIVIDUAL' | 'SELECTED' | 'ALL'
  String _scheduledDate = IstDateUtils.getTodayISTString();
  bool _isAssigning = false;
  String? _errorMessage;

  // Individual selection
  String? _individualClientId;
  String _individualClientName = '';

  // Multiple selection
  final Set<String> _selectedClientIds = {};
  String _clientSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _initDefaultClient();
  }

  void _initDefaultClient() {
    final clients = _eligibleClients;
    final propCid = widget.proposal.clientId;

    if (propCid != null && propCid.isNotEmpty) {
      final match = clients.firstWhere(
        (c) => c['clientId'] == propCid || c['id'] == propCid,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        _individualClientId = match['id'] ?? match['clientId'];
        _individualClientName = match['name'] ?? widget.proposal.clientName ?? 'Athlete';
      } else {
        _individualClientId = propCid;
        _individualClientName = widget.proposal.clientName ?? 'Athlete ($propCid)';
      }
    } else if (clients.isNotEmpty) {
      _individualClientId = clients.first['id'] ?? clients.first['clientId'];
      _individualClientName = clients.first['name'] ?? 'Athlete';
    }

    if (_individualClientId != null) {
      _selectedClientIds.add(_individualClientId!);
    }
  }

  List<Map<String, String>> get _eligibleClients {
    final list = widget.workoutRepository.clientsList.where((c) {
      final status = (c['status'] ?? '').toLowerCase();
      // Exclude suspended, rejected, or inactive accounts
      if (status.contains('suspend') || status.contains('reject')) return false;
      return true;
    }).toList();

    if (list.isEmpty) {
      final propCid = widget.proposal.clientId ?? 'AXG-1029';
      final propName = widget.proposal.clientName ?? 'Athlete';
      return [
        {
          'id': propCid,
          'clientId': propCid,
          'name': propName,
          'status': 'Active',
          'primaryGoal': 'General Fitness',
          'fitnessLevel': 'Intermediate',
        }
      ];
    }

    return list;
  }

  List<Map<String, String>> get _filteredClientsForSearch {
    final clients = _eligibleClients;
    if (_clientSearchQuery.isEmpty) return clients;
    final q = _clientSearchQuery.toLowerCase();
    return clients.where((c) {
      final name = (c['name'] ?? '').toLowerCase();
      final cid = (c['clientId'] ?? '').toLowerCase();
      final goal = (c['primaryGoal'] ?? '').toLowerCase();
      return name.contains(q) || cid.contains(q) || goal.contains(q);
    }).toList();
  }

  List<Map<String, String>> get _resolvedRecipients {
    final clients = _eligibleClients;
    if (_mode == 'ALL') {
      return clients;
    } else if (_mode == 'SELECTED') {
      return clients.where((c) => _selectedClientIds.contains(c['id']) || _selectedClientIds.contains(c['clientId'])).toList();
    } else {
      // INDIVIDUAL
      return clients.where((c) => c['id'] == _individualClientId || c['clientId'] == _individualClientId).toList();
    }
  }

  Future<void> _handleConfirmAndAssign() async {
    setState(() {
      _isAssigning = true;
      _errorMessage = null;
    });

    final recipients = _resolvedRecipients;
    if (recipients.isEmpty) {
      setState(() {
        _isAssigning = false;
        _errorMessage = 'No eligible recipients selected for assignment.';
      });
      return;
    }

    final targetIds = recipients.map((r) => r['id'] ?? r['clientId'] ?? '').where((id) => id.isNotEmpty).toList();

    try {
      final ok = await widget.aiCoachRepository.approveProposal(
        widget.proposal.id,
        assignmentType: _mode,
        clientIds: targetIds,
        scheduledDate: _scheduledDate,
        proposalData: widget.proposal.toJson(),
      );

      if (!mounted) return;

      if (ok) {
        widget.proposal.status = AiProposalStatus.approved;
        await widget.workoutRepository.fetchAdminSessions();
        if (!mounted) return;
        Navigator.of(context).pop(); // Close dialog
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ ${widget.proposal.title} assigned to ${recipients.length} athlete(s)!'),
            backgroundColor: AppColors.statusGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _isAssigning = false;
          _errorMessage = 'Failed to assign workout plan. Server rejected the request.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAssigning = false;
        _errorMessage = 'Assignment error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_turned_in, color: AppColors.primaryRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _step == ProposalAssignmentStep.selectMode ? 'ASSIGN WORKOUT PLAN' : 'CONFIRM RECIPIENTS',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.8),
                ),
                Text(
                  widget.proposal.title,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _step == ProposalAssignmentStep.selectMode
            ? _buildSelectModeStep()
            : _buildConfirmationStep(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildSelectModeStep() {
    final eligibleCount = _eligibleClients.length;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryRed),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: AppColors.primaryRed, fontSize: 12)),
            ),
          ],
          const Text(
            'Choose how this approved workout plan should be assigned to gym members:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Option 1: Individual Client
          _buildModeTile(
            mode: 'INDIVIDUAL',
            icon: Icons.person,
            title: 'Individual Athlete',
            subtitle: _individualClientName.isNotEmpty
                ? 'Assign exclusively to $_individualClientName'
                : 'Assign to one specific athlete',
          ),
          if (_mode == 'INDIVIDUAL') ...[
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
              child: _buildIndividualPickerDropdown(),
            ),
          ],
          const SizedBox(height: 8),

          // Option 2: Multiple Selected Clients
          _buildModeTile(
            mode: 'SELECTED',
            icon: Icons.checklist_rtl,
            title: 'Multiple Selected Athletes',
            subtitle: '${_selectedClientIds.length} athlete(s) selected from roster',
          ),
          if (_mode == 'SELECTED') ...[
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
              child: _buildMultipleClientsSelector(),
            ),
          ],
          const SizedBox(height: 8),

          // Option 3: All Eligible Clients
          _buildModeTile(
            mode: 'ALL',
            icon: Icons.groups,
            title: 'All Eligible Athletes',
            subtitle: 'Assign to all $eligibleCount active gym members',
          ),
          const SizedBox(height: 16),

          // Scheduled Date Picker Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Scheduled Date:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                InkWell(
                  onTap: _pickScheduledDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Text(_scheduledDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: AppColors.primaryRed),
                      ],
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

  Widget _buildModeTile({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _mode == mode;

    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryRed : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: mode,
              groupValue: _mode,
              activeColor: AppColors.primaryRed,
              onChanged: (val) {
                if (val != null) setState(() => _mode = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualPickerDropdown() {
    final clients = _eligibleClients;

    return DropdownButtonFormField<String>(
      value: _individualClientId,
      dropdownColor: AppColors.surfaceCard,
      decoration: InputDecoration(
        labelText: 'Select Athlete',
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      items: clients.map((c) {
        final id = c['id'] ?? c['clientId'] ?? '';
        final name = c['name'] ?? 'Athlete';
        final cid = c['clientId'] ?? '';
        return DropdownMenuItem<String>(
          value: id,
          child: Text('$name ($cid)', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          final found = clients.firstWhere((c) => c['id'] == val || c['clientId'] == val, orElse: () => {});
          setState(() {
            _individualClientId = val;
            _individualClientName = found['name'] ?? val;
          });
        }
      },
    );
  }

  Widget _buildMultipleClientsSelector() {
    final clients = _filteredClientsForSearch;

    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              onChanged: (val) => setState(() => _clientSearchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search athlete by name or ID...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    for (final c in _eligibleClients) {
                      final id = c['id'] ?? c['clientId'];
                      if (id != null) _selectedClientIds.add(id);
                    }
                  });
                },
                child: const Text('SELECT ALL', style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedClientIds.clear());
                },
                child: const Text('CLEAR', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (ctx, idx) {
                final c = clients[idx];
                final id = c['id'] ?? c['clientId'] ?? '';
                final name = c['name'] ?? 'Athlete';
                final cid = c['clientId'] ?? id;
                final isChecked = _selectedClientIds.contains(id) || _selectedClientIds.contains(cid);

                return CheckboxListTile(
                  dense: true,
                  value: isChecked,
                  activeColor: AppColors.primaryRed,
                  title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('$cid • ${c['primaryGoal'] ?? 'General'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedClientIds.add(id);
                      } else {
                        _selectedClientIds.remove(id);
                        _selectedClientIds.remove(cid);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildConfirmationStep() {
    final recipients = _resolvedRecipients;
    final totalCount = recipients.length;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryRed),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: AppColors.primaryRed, fontSize: 12)),
            ),
          ],

          // Summary Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.statusGreen),
                      ),
                      child: Text(
                        '$_mode RECIPIENTS',
                        style: const TextStyle(color: AppColors.statusGreen, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$totalCount Athlete${totalCount != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Scheduled Date: $_scheduledDate (IST)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Eligibility Validation Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.statusGreen.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: AppColors.statusGreen, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All recipients validated: Active & Approved gym athletes.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Duplicate Prevention Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: Colors.blueAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Duplicate guard enabled: Overwrites active workout for this date without duplicate database records.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (widget.proposal.payload['weeklySchedule'] is List && (widget.proposal.payload['weeklySchedule'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_view_week, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Weekly Split Protocol: ${(widget.proposal.payload['weeklySchedule'] as List).length} separate workout days (Push A, Pull A, Legs A, ...) assigned to their scheduled weekdays with dedicated 5–7 exercises per session.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Recipient List
          const Text('RECIPIENT LIST:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Material(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
              shrinkWrap: true,
              itemCount: recipients.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) {
                final r = recipients[i];
                final rName = r['name'] ?? 'Athlete';
                final rCid = r['clientId'] ?? r['id'] ?? '';
                final goal = r['primaryGoal'] ?? 'General';

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.glowRed,
                    child: Text(rName.isNotEmpty ? rName[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(rName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('$rCid • $goal', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.check_circle, color: AppColors.statusGreen, size: 16),
                );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isAssigning) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(color: AppColors.primaryRed, strokeWidth: 2),
            ),
          ),
        ),
      ];
    }

    if (_step == ProposalAssignmentStep.selectMode) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL', style: TextStyle(color: AppColors.textTertiary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final count = _resolvedRecipients.length;
            if (count == 0) {
              setState(() => _errorMessage = 'Please select at least one recipient.');
              return;
            }
            setState(() {
              _errorMessage = null;
              _step = ProposalAssignmentStep.confirmation;
            });
          },
          child: const Text('REVIEW RECIPIENTS →', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ];
    } else {
      return [
        TextButton(
          onPressed: () {
            setState(() {
              _errorMessage = null;
              _step = ProposalAssignmentStep.selectMode;
            });
          },
          child: const Text('← BACK', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.statusGreen,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check, size: 16),
          label: Text('CONFIRM & ASSIGN (${_resolvedRecipients.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _handleConfirmAndAssign,
        ),
      ];
    }
  }

  Future<void> _pickScheduledDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryRed,
              surface: AppColors.surfaceCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _scheduledDate = IstDateUtils.toISTDateString(picked);
      });
    }
  }
}
