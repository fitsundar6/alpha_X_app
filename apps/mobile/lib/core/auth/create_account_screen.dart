import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'auth_service.dart';

/// The official Alpha X Gym dedicated Client Account Creation / Registration Screen.
///
/// Contains ONLY:
/// 1. Client Name (Full Name)
/// 2. Gmail / Email (Auto-trimmed, lowercased, non-capitalized, validated)
/// 3. Phone Number (Phone keyboard, formatted & validated)
/// 4. Create Password (Hidden by default, eye toggle)
/// 5. Confirm Password (Hidden by default, eye toggle)
///
/// Followed by:
/// - [ CREATE ACCOUNT ] button
/// - [ Already have an account? Login ] link
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Clean & user-friendly error formatting
  String _formatError(dynamic e) {
    final raw = e.toString().replaceAll('Exception: ', '').trim();
    if (raw.toLowerCase().contains('email already') || raw.toLowerCase().contains('already exists')) {
      return 'This email is already registered. Please login.';
    }
    if (raw.toLowerCase().contains('phone') && (raw.toLowerCase().contains('already') || raw.toLowerCase().contains('exists'))) {
      return 'This phone number is already registered.';
    }
    if (raw.toLowerCase().contains('passwords do not match')) {
      return 'Passwords do not match.';
    }
    if (raw.toLowerCase().contains('connection') ||
        raw.toLowerCase().contains('reach') ||
        raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('timeout')) {
      return 'Unable to reach Alpha X server. Please try again.';
    }
    return raw;
  }

  Future<void> _handleCreateAccount() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final cleanPassword = _passwordController.text;
    final cleanConfirm = _confirmPasswordController.text;

    if (cleanPassword != cleanConfirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final phone = _phoneController.text.trim();

      final result = await _authService.registerClientAccount(
        name: name,
        email: email,
        phone: phone,
        password: cleanPassword,
        confirmPassword: cleanConfirm,
      );

      if (!mounted) return;

      final generatedClientId = result['clientId']?.toString() ?? _authService.currentClientId;

      setState(() {
        _isLoading = false;
      });

      // Show immediate notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B5E20),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account Created Successfully ✓ (ID: $generatedClientId)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );

      // Show celebration dialog and proceed to assessment
      _showSuccessDialog(generatedClientId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _formatError(e);
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String clientId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primaryRed.withOpacity(0.5), width: 1.5),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.primaryRed, size: 40),
              ),
              const SizedBox(height: 12),
              const Text(
                'Account Created Successfully ✓',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Alpha X. Your permanent athlete Client ID is:',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryRed, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR ALPHA X CLIENT ID',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      clientId,
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keep this ID safe! You can use this Client ID or your email to log in anytime.',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacementNamed('/onboarding');
                },
                child: const Text(
                  'PROCEED TO FITNESS ASSESSMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      prefixIcon: Icon(prefixIcon, color: AppColors.primaryRed, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top: Alpha X Gym Logo & Brand Heading
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryRed.withOpacity(0.35), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.18),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const AlphaXLogo(size: 40),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'ALPHA X',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 6),

                // Screen Title
                const Text(
                  'Create Your Alpha X Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.error_outline, color: AppColors.primaryRed, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Client Name (Full Name)
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _buildInputDecoration(
                            label: 'Client Name',
                            hint: 'Enter your full name',
                            prefixIcon: Icons.person_outline,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 2. Gmail / Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _buildInputDecoration(
                            label: 'Gmail / Email',
                            hint: 'Enter your email',
                            prefixIcon: Icons.email_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a valid email';
                            }
                            final clean = v.trim().toLowerCase();
                            final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!emailRegExp.hasMatch(clean)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 3. Phone Number
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _buildInputDecoration(
                            label: 'Phone Number',
                            hint: 'Enter your phone number',
                            prefixIcon: Icons.phone_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 7 || digits.length > 15) {
                              return 'Please enter your phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 4. Create Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _buildInputDecoration(
                            label: 'Create Password',
                            hint: 'Create password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password must meet the required security rules';
                            }
                            if (v.length < 6) {
                              return 'Password must meet the required security rules';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 5. Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: _buildInputDecoration(
                            label: 'Confirm Password',
                            hint: 'Re-enter password',
                            prefixIcon: Icons.lock_clock_outlined,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Passwords do not match.';
                            }
                            if (v != _passwordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // CREATE ACCOUNT Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleCreateAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'CREATE ACCOUNT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Already have an account? Login
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
