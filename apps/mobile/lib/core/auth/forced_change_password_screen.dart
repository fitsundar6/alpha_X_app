import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/alpha_x_button.dart';
import '../widgets/alpha_x_logo.dart';
import '../widgets/server_config_dialog.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Screen displayed when an authenticated athlete user has `mustChangePassword == true`.
///
/// This occurs when an administrator assigns a temporary password to an account
/// (e.g. during remediation or initial provisioning). The user must authenticate
/// and change their password to a permanent one via `/api/v1/auth/change-password`
/// before accessing the Athlete Dashboard or onboarding flow.
class ForcedChangePasswordScreen extends StatefulWidget {
  const ForcedChangePasswordScreen({super.key});

  @override
  State<ForcedChangePasswordScreen> createState() => _ForcedChangePasswordScreenState();
}

class _ForcedChangePasswordScreenState extends State<ForcedChangePasswordScreen> {
  static const Color _goldAccent = Color(0xFFD4A034);

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Safety guard: if already cleared or unauthenticated, route immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_authService.isAuthenticated) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else if (!_authService.mustChangePassword) {
        if (!_authService.onboardingCompleted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
        }
      }
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitPasswordChange() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result['message']?.toString() ?? 'Password updated successfully.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E7E34),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        if (!_authService.onboardingCompleted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage = result['message']?.toString() ??
              'Failed to update password. Please verify your current password.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred while updating your password. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final clientId = _authService.currentClientId;
    final userEmail = _authService.currentUserEmail;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation while forced change is active
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const AlphaXLogo.appBar(size: 28),
          actions: [
            if (!ApiConfig.effectiveIsReleaseMode)
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textTertiary, size: 20),
                tooltip: 'Server Settings',
                onPressed: () => ServerConfigDialog.show(context),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shield Header Badge
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _goldAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: _goldAccent.withOpacity(0.35), width: 1.5),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 32,
                            color: _goldAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'PASSWORD UPDATE REQUIRED',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Explanation Subtitle
                      const Text(
                        'A temporary password was assigned to your account. For your security, you must set a permanent password before continuing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Account Details Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            if (clientId.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.badge_outlined, size: 16, color: _goldAccent),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'ATHLETE ID:',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    clientId,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 16, color: AppColors.textTertiary),
                                const SizedBox(width: 8),
                                const Text(
                                  'ACCOUNT:',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Expanded(
                                  child: Text(
                                    userEmail.isNotEmpty ? userEmail : 'Authenticated Client',
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Fields
                      // 1. Current Password
                      _buildPasswordField(
                        controller: _currentPasswordController,
                        label: 'CURRENT TEMPORARY PASSWORD',
                        hint: 'Enter your current temporary password',
                        obscureText: _obscureCurrent,
                        onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Current password is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. New Password
                      _buildPasswordField(
                        controller: _newPasswordController,
                        label: 'NEW PERMANENT PASSWORD',
                        hint: 'Enter your new permanent password (min 6 chars)',
                        obscureText: _obscureNew,
                        onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'New password is required.';
                          }
                          if (value.trim().length < 6) {
                            return 'New password must be at least 6 characters.';
                          }
                          if (value.trim() == _currentPasswordController.text.trim()) {
                            return 'New password must be different from current password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3. Confirm New Password
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'CONFIRM NEW PASSWORD',
                        hint: 'Re-enter your new permanent password',
                        obscureText: _obscureConfirm,
                        onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please confirm your new password.';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      AlphaXButton(
                        label: 'UPDATE PASSWORD & CONTINUE',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _submitPasswordChange,
                      ),
                      const SizedBox(height: 20),

                      // Sign Out / Cancel Option
                      Center(
                        child: TextButton.icon(
                          onPressed: _isLoading ? null : _handleSignOut,
                          icon: const Icon(Icons.logout, size: 16, color: AppColors.textTertiary),
                          label: const Text(
                            'Sign Out / Login with another account',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _goldAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textTertiary,
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
