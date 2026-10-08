import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/config/admin_config.dart';
import 'auth_service.dart';

/// Screen displayed when an athlete user account has status = PENDING.
///
/// Requirement 1 & 6:
/// - Screen title: "Account Pending Verification"
/// - Message: "Your account has been submitted for verification. Please wait for the admin to approve your account."
/// - Blocks all access to workout, dashboard, and protected features.
/// - Includes real-time auto-polling & manual "Check Status" button.
/// - When admin approves the account, automatically routes to normal app.
class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  State<PendingVerificationScreen> createState() => _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isChecking = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Auto-poll verification status every 12 seconds in the background
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _checkStatusSilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatusSilently() async {
    if (!mounted || _isChecking) return;
    try {
      final result = await _authService.checkVerificationStatus();
      if (!mounted) return;
      if (result['isApproved'] == true) {
        _onApprovedTransition();
      } else if (result['isRejected'] == true) {
        Navigator.of(context).pushReplacementNamed('/rejected-account');
      } else if (result['isSuspended'] == true) {
        Navigator.of(context).pushReplacementNamed('/suspended-account');
      }
    } catch (_) {}
  }

  Future<void> _handleManualCheck() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final result = await _authService.checkVerificationStatus();
      if (!mounted) return;

      if (result['isApproved'] == true) {
        _onApprovedTransition();
        return;
      }

      if (result['isRejected'] == true) {
        Navigator.of(context).pushReplacementNamed('/rejected-account');
        return;
      }

      if (result['isSuspended'] == true) {
        Navigator.of(context).pushReplacementNamed('/suspended-account');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.hourglass_top, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your account is still pending verification. Our team reviews accounts promptly.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.amber, width: 1),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reach server: $e'),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _onApprovedTransition() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text(
              'Account Approved!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Your account has been approved by the administrator. Welcome to Alpha X Gym!',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!_authService.onboardingCompleted) {
                Navigator.of(context).pushReplacementNamed('/onboarding');
              } else {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              }
            },
            child: const Text('CONTINUE TO APP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: AppColors.primaryRed, size: 26),
            SizedBox(width: 10),
            Text('Contact Gym Administration', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need immediate verification or have questions regarding your gym membership?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.email_outlined, 'Admin Email', AdminConfig.adminEmail),
            const SizedBox(height: 10),
            _infoRow(Icons.phone_outlined, 'Front Desk', '+1 (555) ALPHA-01'),
            const SizedBox(height: 10),
            _infoRow(Icons.access_time, 'Hours', 'Mon–Sat: 06:00 AM – 10:00 PM'),
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
        Icon(icon, size: 18, color: Colors.amber),
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

                  // Prominent Status Icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withOpacity(0.12),
                      border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        size: 46,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Required Screen Title
                  const Text(
                    'Account Pending Verification',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Required Message
                  const Text(
                    'Your account has been submitted for verification. Please wait for the admin to approve your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Account Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'VERIFICATION STATUS',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_clock, color: Colors.amber, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'PENDING',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.border),
                        _detailRow('Athlete Name', user.currentUserName),
                        const SizedBox(height: 8),
                        _detailRow('Client ID', user.currentClientId.isNotEmpty ? user.currentClientId : 'AXG-PENDING'),
                        const SizedBox(height: 8),
                        _detailRow('Registered Email', user.currentUserEmail),
                        if (user.currentUserPhone != null && user.currentUserPhone!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _detailRow('Phone Number', user.currentUserPhone!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isChecking ? null : _handleManualCheck,
                      child: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: 20, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'CHECK APPROVAL STATUS',
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

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showContactAdminDialog,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.headset_mic_outlined, size: 18, color: colors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'CONTACT ADMIN',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign Out Link
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

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
