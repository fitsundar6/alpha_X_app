import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/alpha_x_button.dart';
import '../widgets/alpha_x_logo.dart';
import '../widgets/server_config_dialog.dart';
import 'auth_service.dart';

/// Password Reset Screen for Alpha X Gym.
///
/// Verifies short-lived, single-use password recovery tokens and allows
/// athletes or administrators to set and confirm a new secure password.
class ResetPasswordScreen extends StatefulWidget {
  final String? initialToken;

  const ResetPasswordScreen({super.key, this.initialToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const Color _goldAccent = Color(0xFFD4A034);

  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isVerifyingToken = false;
  bool _tokenValidated = false;
  bool _isCodeMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSuccess = false;

  String? _targetEmail;
  String? _targetRole;
  String? _errorMessage;
  String? _tokenErrorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _tokenController.text = widget.initialToken!;
      if (RegExp(r'^\d{6}$').hasMatch(widget.initialToken!.trim())) {
        _isCodeMode = true;
      } else {
        _verifyToken(widget.initialToken!);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args['mode'] == 'code') {
        _isCodeMode = true;
      }
      if (args['identifier'] is String && _identifierController.text.isEmpty) {
        _identifierController.text = args['identifier'] as String;
      }
      if (args['token'] is String && _tokenController.text.isEmpty) {
        final token = args['token'] as String;
        _tokenController.text = token;
        if (RegExp(r'^\d{6}$').hasMatch(token.trim())) {
          _isCodeMode = true;
        } else {
          _verifyToken(token);
        }
      }
    } else if (args is String && args.isNotEmpty && _tokenController.text.isEmpty) {
      _tokenController.text = args;
      if (RegExp(r'^\d{6}$').hasMatch(args.trim())) {
        _isCodeMode = true;
      } else {
        _verifyToken(args);
      }
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    setState(() {
      _isVerifyingToken = true;
      _tokenErrorMessage = null;
      _errorMessage = null;
    });

    final res = await AuthService().verifyResetToken(cleanToken);

    if (!mounted) return;

    if (res['valid'] == true) {
      setState(() {
        _isVerifyingToken = false;
        _tokenValidated = true;
        _targetEmail = res['email'] as String?;
        _targetRole = res['role'] as String?;
      });
    } else {
      setState(() {
        _isVerifyingToken = false;
        _tokenValidated = false;
        _tokenErrorMessage = res['message'] as String? ??
            'This password reset link is invalid or has expired.';
      });
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _tokenController.text.trim();
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters.';
      });
      return;
    }

    if (_isCodeMode || RegExp(r'^\d{6}$').hasMatch(token)) {
      final identifier = _identifierController.text.trim();
      if (identifier.isEmpty) {
        setState(() {
          _errorMessage = 'Registered Email or Client ID is required.';
        });
        return;
      }
      if (token.isEmpty) {
        setState(() {
          _errorMessage = '6-digit admin reset code is required.';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final res = await AuthService().resetPasswordWithCode(
        identifier: identifier,
        code: token,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message'] as String? ??
              'Failed to reset password. Please check your reset code.';
        });
      }
      return;
    }

    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Reset token is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService().resetPassword(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message'] as String? ??
            'Failed to reset password. Please ensure the token is still valid.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0xFF1E1708),
                    Color(0xFF0D0D0D),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: IconButton(
                          key: const Key('reset_password_back_button'),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                          tooltip: 'Return to Login',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SET NEW PASSWORD',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: IconButton(
                          key: const Key('reset_password_server_config_button'),
                          icon: const Icon(Icons.settings_ethernet, color: AppColors.textTertiary, size: 18),
                          tooltip: 'Server Settings',
                          onPressed: () => ServerConfigDialog.show(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Card
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _goldAccent.withOpacity(0.3),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                              child: _isSuccess
                                  ? _buildSuccessView()
                                  : (_isVerifyingToken
                                      ? _buildVerifyingView()
                                      : _buildResetFormView()),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildVerifyingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: _goldAccent, strokeWidth: 2.5),
        const SizedBox(height: 20),
        Text(
          'Verifying Reset Link...',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ensuring token authenticity and security.',
          style: GoogleFonts.poppins(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResetFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo & Branding
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AlphaXLogo.badge(size: 20),
                const SizedBox(width: 8),
                Text(
                  'ALPHA X GYM',
                  style: GoogleFonts.poppins(
                    color: _goldAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Create New Password',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),

          if (_targetEmail != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _goldAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _goldAccent.withOpacity(0.3)),
                ),
                child: Text(
                  'Account: $_targetEmail',
                  style: GoogleFonts.poppins(
                    color: _goldAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              'Your new password must be at least 6 characters long.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Token Error Banner (if token verification failed)
          if (_tokenErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _tokenErrorMessage!,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('request_new_link_button'),
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/forgot-password');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Request a new password reset link →',
                      style: GoogleFonts.poppins(
                        color: _goldAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error Banner if present
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Token or 6-Digit Code inputs
          if (_isCodeMode) ...[
            TextFormField(
              key: const Key('reset_identifier_field'),
              controller: _identifierController,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Registered Email or Client ID (AXG-XXXX)',
                labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                hintText: 'e.g. AXG-0001 or athlete@example.com',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                prefixIcon: const Icon(Icons.badge_outlined, color: _goldAccent, size: 18),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _goldAccent, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your registered Email or Client ID.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reset_password_token_field'),
              controller: _tokenController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 3, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: '6-Digit Admin Reset Code',
                labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                hintText: '123456',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, letterSpacing: 2),
                prefixIcon: const Icon(Icons.pin_outlined, color: _goldAccent, size: 18),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _goldAccent, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter the 6-digit code from your administrator.';
                }
                if (v.trim().length != 6) {
                  return 'Verification code must be exactly 6 digits.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('switch_to_token_mode_button'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                onPressed: () => setState(() => _isCodeMode = false),
                child: Text(
                  'Switch to Reset Token Link mode →',
                  style: GoogleFonts.poppins(color: _goldAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else if (!_tokenValidated && _tokenController.text.isEmpty) ...[
            TextFormField(
              key: const Key('reset_password_token_field'),
              controller: _tokenController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Reset Token or 6-Digit Code',
                labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                hintText: 'Paste token or enter 6-digit code',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                prefixIcon: const Icon(Icons.vpn_key_outlined, color: _goldAccent, size: 18),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _goldAccent, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter or paste your reset token.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('switch_to_code_mode_button'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                onPressed: () => setState(() => _isCodeMode = true),
                child: Text(
                  'Have a 6-digit admin code? Switch to Code Mode →',
                  style: GoogleFonts.poppins(color: _goldAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // New Password Field
          TextFormField(
            key: const Key('reset_new_password_field'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'New Password',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              hintText: '••••••••••••',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12.5),
              prefixIcon: const Icon(Icons.lock_outline, color: _goldAccent, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _goldAccent, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a new password.';
              if (v.length < 6) return 'Password must be at least 6 characters.';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Confirm New Password Field
          TextFormField(
            key: const Key('reset_confirm_password_field'),
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              hintText: '••••••••••••',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12.5),
              prefixIcon: const Icon(Icons.lock_reset_outlined, color: _goldAccent, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _goldAccent, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your new password.';
              if (v != _passwordController.text) return 'Passwords do not match.';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Submit Reset Button
          AlphaXActionButton.solid(
            key: const Key('reset_password_submit_button'),
            label: 'SAVE NEW PASSWORD',
            isLoading: _isLoading,
            onPressed: _handleResetPassword,
            height: 48,
            borderRadius: BorderRadius.circular(12),
            goldColor: _goldAccent,
          ),
          const SizedBox(height: 12),

          // Cancel / Back link
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel & Return to Login',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success Trophy/Shield Icon
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _goldAccent.withOpacity(0.18),
              border: Border.all(color: _goldAccent, width: 2),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: _goldAccent,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'Password Reset Successful',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),

        Text(
          'Your new password has been securely saved. You can now log into Alpha X Gym using your updated credentials.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        AlphaXActionButton.solid(
          key: const Key('continue_to_login_button'),
          label: 'LOG IN WITH NEW PASSWORD',
          onPressed: () {
            if (_targetRole == 'ADMIN') {
              Navigator.of(context).pushNamedAndRemoveUntil('/admin/login', (r) => false);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
            }
          },
          height: 48,
          borderRadius: BorderRadius.circular(12),
          goldColor: _goldAccent,
        ),
      ],
    );
  }
}
