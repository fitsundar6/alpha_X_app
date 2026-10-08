import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

/// Admin User Verification and Client Approval Management Screen
///
/// Features:
/// 1. Metric Summary Cards: Total, Pending, Approved, Rejected, Suspended.
/// 2. Status Filter Tabs: ALL, PENDING, APPROVED, REJECTED, SUSPENDED.
/// 3. Search Bar: searches by name, email, phone, or Client ID.
/// 4. User Cards: profile photo, name, email, phone, status badge, dates.
/// 5. Confirmation Modals:
///    - Approve: "Approve this user?" -> Cancel / Approve User
///    - Reject: "Reject this user?" with reason dropdown + custom note -> Cancel / Reject User
///    - Suspend / Reactivate actions.
/// 6. Detailed User Profile Sheet with Audit Trail History.
class AdminClientVerificationScreen extends StatefulWidget {
  final bool showAppBar;
  const AdminClientVerificationScreen({super.key, this.showAppBar = true});

  @override
  State<AdminClientVerificationScreen> createState() => _AdminClientVerificationScreenState();
}

class _AdminClientVerificationScreenState extends State<AdminClientVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedTab = 'ALL';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _users = [];
  Map<String, int> _counts = {
    'total': 0,
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'suspended': 0,
  };

  final List<String> _rejectionReasons = [
    'Not a gym member',
    'Invalid account',
    'Duplicate account',
    'Incorrect information',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await _authService.getValidToken();
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/verification/users').replace(
        queryParameters: {
          'tab': _selectedTab,
          if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        },
      );

      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'];
          final List<dynamic> list = data['users'] ?? [];
          final countsData = data['counts'] ?? {};

          if (mounted) {
            setState(() {
              _users = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
              _counts = {
                'total': countsData['total'] ?? 0,
                'pending': countsData['pending'] ?? 0,
                'approved': countsData['approved'] ?? 0,
                'rejected': countsData['rejected'] ?? 0,
                'suspended': countsData['suspended'] ?? 0,
              };
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load verification users (${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error loading users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveUser(Map<String, dynamic> user, {String reason = 'Approved by administrator'}) async {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name']?.toString() ?? 'Athlete';

    try {
      final token = await _authService.getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/verification/$userId/approve');

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('User "$userName" Approved Successfully ✓', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
        _loadUsers(showSpinner: false);
      } else {
        throw Exception('Server rejected approval (Status ${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryRed,
          content: Text('Failed to approve user: $e'),
        ),
      );
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> user, {required String reason}) async {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name']?.toString() ?? 'Athlete';

    try {
      final token = await _authService.getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/verification/$userId/reject');

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryRed,
            content: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('User "$userName" Rejected ($reason)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
        _loadUsers(showSpinner: false);
      } else {
        throw Exception('Server failed to reject (Status ${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryRed,
          content: Text('Failed to reject user: $e'),
        ),
      );
    }
  }

  Future<void> _suspendUser(Map<String, dynamic> user, {required String reason}) async {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name']?.toString() ?? 'Athlete';

    try {
      final token = await _authService.getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/verification/$userId/suspend');

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text('User "$userName" Suspended ($reason)'),
          ),
        );
        _loadUsers(showSpinner: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.primaryRed, content: Text('Error: $e')),
      );
    }
  }

  Future<void> _reactivateUser(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    final userName = user['name']?.toString() ?? 'Athlete';

    try {
      final token = await _authService.getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/verification/$userId/reactivate');

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': 'Reactivated by administrator'}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('User "$userName" Reactivated & Approved ✓'),
          ),
        );
        _loadUsers(showSpinner: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.primaryRed, content: Text('Error: $e')),
      );
    }
  }

  // --- Dialogs ---

  void _showApproveDialog(Map<String, dynamic> user) {
    final userName = user['name']?.toString() ?? 'this user';
    final clientId = user['clientId']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 8),
            Text('Approve this user?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to approve "$userName" ($clientId)?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              'After approval, this athlete will immediately get full access to all protected workout, progress, and gym features.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _approveUser(user);
            },
            child: const Text('Approve User', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> user) {
    final userName = user['name']?.toString() ?? 'this user';
    String selectedReason = _rejectionReasons.first;
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: AppColors.primaryRed, size: 26),
              SizedBox(width: 8),
              Text('Reject this user?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting "$userName" will block access to protected features.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text(
                'Select Rejection Reason:',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: _rejectionReasons
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                  ),
                ),
              ),
              if (selectedReason == 'Other') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: customController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter custom rejection reason...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final finalReason = selectedReason == 'Other' && customController.text.trim().isNotEmpty
                    ? customController.text.trim()
                    : selectedReason;
                Navigator.of(ctx).pop();
                _rejectUser(user, reason: finalReason);
              },
              child: const Text('Reject User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final profile = user['profile'] is Map ? user['profile'] as Map : {};
        final logs = user['verificationLogs'] is List ? (user['verificationLogs'] as List) : [];
        final status = (user['status']?.toString() ?? 'PENDING').toUpperCase();

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _buildAvatar(user, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name']?.toString() ?? 'Athlete',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user['clientId']?.toString() ?? '',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              // Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    _sectionTitle('PERSONAL & CONTACT INFORMATION'),
                    _infoCard([
                      _fieldRow('Email', user['email']?.toString() ?? 'N/A'),
                      _fieldRow('Phone', user['phone']?.toString() ?? 'N/A'),
                      _fieldRow('Registered On', _formatDate(user['createdAt'])),
                      _fieldRow('Last Login', _formatDate(user['lastLoginAt'])),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('FITNESS & ONBOARDING ASSESSMENT'),
                    _infoCard([
                      _fieldRow('Primary Goal', profile['primaryGoal']?.toString() ?? 'Not completed'),
                      _fieldRow('Fitness Level', profile['fitnessLevel']?.toString() ?? 'Beginner'),
                      _fieldRow('Weight', profile['weightKg'] != null ? '${profile['weightKg']} kg' : 'N/A'),
                      _fieldRow('Height', profile['heightCm'] != null ? '${profile['heightCm']} cm' : 'N/A'),
                      _fieldRow('Onboarding Status', profile['onboardingCompleted'] == true ? 'Completed' : 'Pending Step ${profile['onboardingStep'] ?? 0}'),
                    ]),
                    const SizedBox(height: 16),
                    if (user['rejectionReason'] != null && user['rejectionReason'].toString().isNotEmpty) ...[
                      _sectionTitle('CURRENT REJECTION DETAILS'),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reason: ${user['rejectionReason']}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (user['rejectedBy'] != null)
                              Text('Rejected by: ${user['rejectedBy']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            if (user['rejectedAt'] != null)
                              Text('Date: ${_formatDate(user['rejectedAt'])}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _sectionTitle('VERIFICATION AUDIT HISTORY'),
                    if (logs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No status transitions recorded yet.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                      )
                    else
                      ...logs.map((log) => _buildAuditLogCard(log)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Footer Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    if (status == 'PENDING' || status == 'REJECTED')
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showApproveDialog(user);
                          },
                          child: Text(
                            status == 'PENDING' ? 'APPROVE USER' : 'RE-APPROVE USER',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                      ),
                    if (status == 'SUSPENDED')
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _reactivateUser(user);
                          },
                          child: const Text('REACTIVATE USER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                    if (status == 'PENDING') const SizedBox(width: 10),
                    if (status == 'PENDING')
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showRejectDialog(user);
                          },
                          child: const Text('REJECT USER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                    if (status == 'APPROVED')
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _suspendUser(user, reason: 'Suspended by admin');
                          },
                          child: const Text('SUSPEND ACCOUNT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _fieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogCard(dynamic log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildStatusChip(log['previousStatus']?.toString() ?? ''),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 12, color: Colors.white54),
                  ),
                  _buildStatusChip(log['newStatus']?.toString() ?? ''),
                ],
              ),
              Text(
                _formatDate(log['createdAt']),
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (log['reason'] != null && log['reason'].toString().isNotEmpty)
            Text(
              'Reason: "${log['reason']}"',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          if (log['adminEmail'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'By: ${log['adminEmail']}',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        color = const Color(0xFF10B981);
        break;
      case 'REJECTED':
        color = AppColors.primaryRed;
        break;
      case 'SUSPENDED':
        color = Colors.orange;
        break;
      case 'PENDING':
      default:
        color = Colors.amber;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Never';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _buildAvatar(Map<String, dynamic> user, {double size = 44}) {
    final photoUrl = user['photoUrl']?.toString();
    final name = user['name']?.toString() ?? 'A';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    if (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _defaultAvatar(initial, size),
        ),
      );
    }
    return _defaultAvatar(initial, size);
  }

  Widget _defaultAvatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryRed.withOpacity(0.2),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.45,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'APPROVED':
        bg = const Color(0xFF10B981).withOpacity(0.15);
        border = const Color(0xFF10B981);
        text = const Color(0xFF10B981);
        icon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
        bg = AppColors.primaryRed.withOpacity(0.15);
        border = AppColors.primaryRed;
        text = AppColors.primaryRed;
        icon = Icons.cancel_outlined;
        break;
      case 'SUSPENDED':
        bg = Colors.orange.withOpacity(0.15);
        border = Colors.orange;
        text = Colors.orange;
        icon = Icons.pause_circle_outline;
        break;
      case 'PENDING':
      default:
        bg = Colors.amber.withOpacity(0.18);
        border = Colors.amber;
        text = Colors.amber;
        icon = Icons.hourglass_top;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('CLIENT VERIFICATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              backgroundColor: colors.background,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _loadUsers(),
                  tooltip: 'Refresh',
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _loadUsers(),
        color: colors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Summary Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildMetricSummaryCards(),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildSearchBar(),
              ),
            ),

            // Filter Tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildFilterTabs(),
              ),
            ),

            // Users List or Empty / Loading State
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadUsers(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_users.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 48, color: colors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No users match "$_searchQuery"'
                            : 'No $_selectedTab users found.',
                        style: TextStyle(color: colors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildUserCard(_users[i]),
                    childCount: _users.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSummaryCards() {
    return Row(
      children: [
        Expanded(child: _metricCard('TOTAL', _counts['total'] ?? 0, Colors.white, Colors.white24)),
        const SizedBox(width: 8),
        Expanded(child: _metricCard('PENDING', _counts['pending'] ?? 0, Colors.amber, Colors.amber, isProminent: true)),
        const SizedBox(width: 8),
        Expanded(child: _metricCard('APPROVED', _counts['approved'] ?? 0, const Color(0xFF10B981), const Color(0xFF10B981))),
        const SizedBox(width: 8),
        Expanded(child: _metricCard('REJECTED', _counts['rejected'] ?? 0, AppColors.primaryRed, AppColors.primaryRed)),
      ],
    );
  }

  Widget _metricCard(String label, int count, Color textColor, Color borderColor, {bool isProminent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isProminent ? Colors.amber.withOpacity(0.12) : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProminent ? Colors.amber : borderColor.withOpacity(0.3),
          width: isProminent ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isProminent ? Colors.amber : AppColors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search by athlete name, email, phone, or Client ID...',
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: AppColors.textTertiary),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _loadUsers();
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      ),
      onSubmitted: (val) {
        setState(() => _searchQuery = val.trim());
        _loadUsers();
      },
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      {'key': 'ALL', 'label': 'All Users', 'count': _counts['total'] ?? 0},
      {'key': 'PENDING', 'label': 'Pending', 'count': _counts['pending'] ?? 0},
      {'key': 'APPROVED', 'label': 'Approved', 'count': _counts['approved'] ?? 0},
      {'key': 'REJECTED', 'label': 'Rejected', 'count': _counts['rejected'] ?? 0},
      {'key': 'SUSPENDED', 'label': 'Suspended', 'count': _counts['suspended'] ?? 0},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = _selectedTab == t['key'];
          final count = t['count'] as int;
          final isPendingTab = t['key'] == 'PENDING';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isPendingTab ? Colors.amber : (isSelected ? Colors.white24 : AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isPendingTab ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selectedColor: isPendingTab ? const Color(0xFFB45309) : AppColors.primaryRed,
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : AppColors.border,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTab = t['key'] as String);
                  _loadUsers();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final status = (user['status']?.toString() ?? 'PENDING').toUpperCase();
    final isPending = status == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? Colors.amber.withOpacity(0.6) : AppColors.border,
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showUserDetailsSheet(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Name, Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(user),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user['name']?.toString() ?? 'Athlete',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                user['clientId']?.toString() ?? '',
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user['email']?.toString() ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user['phone'] != null && user['phone'].toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user['phone'].toString(),
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),

                // Meta Row: Joined & Last Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Joined: ${_formatDate(user['createdAt'])}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                    Text(
                      'Last Login: ${_formatDate(user['lastLoginAt'])}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ),

                // Rejection Reason Banner if Rejected
                if (status == 'REJECTED' && user['rejectionReason'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryRed.withOpacity(0.2)),
                    ),
                    child: Text(
                      'Reason: ${user['rejectionReason']}',
                      style: const TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],

                // Action Buttons for PENDING users
                if (isPending) ...[
                  const Divider(height: 20, color: AppColors.border),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryRed),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _showRejectDialog(user),
                          child: const Text(
                            'REJECT',
                            style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                          ),
                          onPressed: () => _showApproveDialog(user),
                          child: const Text(
                            'APPROVE',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
