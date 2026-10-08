import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/config/admin_config.dart';
import 'auth_service.dart';

/// Screen displayed when an athlete user account has status = REJECTED.
///
/// Requirement 7:
/// - Screen title: "Account Not Approved"
/// - Message: "Your account has not been approved by the administrator."
/// - If a rejection reason exists: "Reason: [rejection reason]"
/// - "Contact Admin" button.
/// - Does NOT show the normal app dashboard.
class RejectedAccountScreen extends StatefulWidget {
  const RejectedAccountScreen({super.key});

  @override
  State<RejectedAccountScreen> createState() => _RejectedAccountScreenState();
}

class _RejectedAccountScreenState extends State<RejectedAccountScreen> {
  final AuthService _authService = AuthService();
  bool _isRechecking = false;

  Future<void> _handleRecheck() async {
    if (_isRechecking) return;
    setState(() => _isRechecking = true);

    try {
      final result = await _authService.checkVerificationStatus();
      if (!mounted) return;

      if (result['isApproved'] == true) {
        if (!_authService.onboardingCompleted) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        } else {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['rejectionReason'] != null
                ? 'Status: Rejected (${result['rejectionReason']})'
                : 'Your account remains unapproved by administration.',
          ),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isRechecking = false);
      }
    }
  }

  void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.contact_support, color: AppColors.primaryRed, size: 26),
            SizedBox(width: 10),
            Text('Contact Administration', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you believe this rejection is an error or would like to submit proof of gym membership:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.email_outlined, 'Admin Email', AdminConfig.adminEmail),
            const SizedBox(height: 10),
            _infoRow(Icons.phone_outlined, 'Help Desk', '+1 (555) ALPHA-01'),
            const SizedBox(height: 10),
            _infoRow(Icons.location_on_outlined, 'Front Desk', 'Alpha X Gym Main Facility'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryRed),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final user = _authService;
    final reason = user.rejectionReason;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AlphaXLogo(size: 64),
                  const SizedBox(height: 24),

                  // Rejection Shield Icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryRed.withOpacity(0.12),
                      border: Border.all(color: AppColors.primaryRed.withOpacity(0.5), width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 48,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Required Screen Title
                  const Text(
                    'Account Not Approved',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Required Screen Message
                  const Text(
                    'Your account has not been approved by the administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Required Rejection Reason Display
                  if (reason != null && reason.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryRed.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primaryRed, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'REASON FOR DECISION',
                                style: TextStyle(
                                  color: AppColors.primaryRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Account Details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Athlete', user.currentUserName),
                        const SizedBox(height: 8),
                        _detailRow('Client ID', user.currentClientId.isNotEmpty ? user.currentClientId : 'N/A'),
                        const SizedBox(height: 8),
                        _detailRow('Account Status', 'REJECTED', isStatus: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Required "Contact Admin" button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _showContactAdminDialog,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.headset_mic, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'CONTACT ADMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Re-check Status button (in case admin changes decision)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isRechecking ? null : _handleRecheck,
                      child: _isRechecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'CHECK IF STATUS CHANGED',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign Out
                  TextButton(
                    onPressed: () async {
                      await _authService.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                    child: const Text(
                      'Sign Out / Login with another account',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: isStatus ? AppColors.primaryRed : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
