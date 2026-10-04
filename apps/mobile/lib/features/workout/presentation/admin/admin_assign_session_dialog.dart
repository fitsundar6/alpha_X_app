import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

class AdminAssignSessionDialog extends StatefulWidget {
  final WorkoutSession session;
  final WorkoutRepository workoutRepository;

  const AdminAssignSessionDialog({
    super.key,
    required this.session,
    required this.workoutRepository,
  });

  @override
  State<AdminAssignSessionDialog> createState() => _AdminAssignSessionDialogState();
}

class _AdminAssignSessionDialogState extends State<AdminAssignSessionDialog> {
  String _assignmentType = 'ALL'; // 'ALL', 'SELECTED', 'INDIVIDUAL'
  final Set<String> _selectedClientIds = {};
  String? _individualClientId;
  bool _isRecommended = false;

  @override
  void initState() {
    super.initState();
    // Check current assignment state
    final assignments = widget.workoutRepository.assignments
        .where((a) => a.sessionId == widget.session.id)
        .toList();

    if (assignments.isNotEmpty) {
      if (assignments.any((a) => a.clientId == null)) {
        _assignmentType = 'ALL';
        _isRecommended = assignments.firstWhere((a) => a.clientId == null).isRecommended;
      } else if (assignments.length == 1) {
        _assignmentType = 'INDIVIDUAL';
        _individualClientId = assignments.first.clientId;
        _isRecommended = assignments.first.isRecommended;
      } else {
        _assignmentType = 'SELECTED';
        _selectedClientIds.addAll(assignments.map((a) => a.clientId!).where((id) => id.isNotEmpty));
        _isRecommended = assignments.any((a) => a.isRecommended);
      }
    } else {
      _isRecommended = widget.session.isRecommended;
    }
  }

  bool _isSaving = false;

  Future<void> _saveAssignment() async {
    if (_isSaving) return;

    if (_assignmentType == 'INDIVIDUAL' && (_individualClientId == null || _individualClientId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an individual client.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_assignmentType == 'SELECTED' && _selectedClientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one client.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.workoutRepository.assignSession(
      sessionId: widget.session.id,
      assignmentType: _assignmentType,
      clientIds: _selectedClientIds.toList(),
      individualClientId: _individualClientId,
      isRecommended: _isRecommended,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Assigned "${widget.session.title}" (${_assignmentType == "ALL" ? "All Clients" : _assignmentType == "INDIVIDUAL" ? "Individual" : "${_selectedClientIds.length} Clients"})${_isRecommended ? " as Recommended ⭐" : ""} (Saved to Database)'
              : 'Assigned locally (Server sync pending)',
        ),
        backgroundColor: success ? AppColors.primaryRed : AppColors.gold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = widget.workoutRepository.clientsList;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSIGN WORKOUT SESSION',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.session.title,
            style: const TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Target:',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),

              // Option 1: All Clients
              RadioListTile<String>(
                title: const Text('All Clients', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Available to all active gym members', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                value: 'ALL',
                groupValue: _assignmentType,
                activeColor: AppColors.primaryRed,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _assignmentType = val!),
              ),

              // Option 2: Selected Clients
              RadioListTile<String>(
                title: const Text('Selected Clients', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Choose specific multiple clients', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                value: 'SELECTED',
                groupValue: _assignmentType,
                activeColor: AppColors.primaryRed,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _assignmentType = val!),
              ),

              if (_assignmentType == 'SELECTED') ...[
                Container(
                  margin: const EdgeInsets.only(left: 12, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: clients.map((c) {
                      final cId = c['id']!;
                      final isSelected = _selectedClientIds.contains(cId);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(c['name']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        subtitle: Text(c['email']!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                        value: isSelected,
                        activeColor: AppColors.primaryRed,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedClientIds.add(cId);
                            } else {
                              _selectedClientIds.remove(cId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Option 3: Individual Client
              RadioListTile<String>(
                title: const Text('Individual Client', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Assign to one specific athlete', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                value: 'INDIVIDUAL',
                groupValue: _assignmentType,
                activeColor: AppColors.primaryRed,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _assignmentType = val!),
              ),

              if (_assignmentType == 'INDIVIDUAL') ...[
                Container(
                  margin: const EdgeInsets.only(left: 12, bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceElevated,
                      hint: const Text('Select Client', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      value: _individualClientId,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      items: clients.map((c) {
                        return DropdownMenuItem(
                          value: c['id'],
                          child: Text('${c["name"]} (${c["email"]})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _individualClientId = val),
                    ),
                  ),
                ),
              ],

              const Divider(color: AppColors.border, height: 24),

              // Recommended toggle
              SwitchListTile(
                title: const Row(
                  children: [
                    Icon(Icons.star, color: AppColors.gold, size: 18),
                    SizedBox(width: 8),
                    Text('Set as Recommended', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                subtitle: const Text(
                  'Shows pinned as top ⭐ Recommended session on the client workout screen',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
                value: _isRecommended,
                activeColor: AppColors.primaryRed,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _isRecommended = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving ? null : _saveAssignment,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
