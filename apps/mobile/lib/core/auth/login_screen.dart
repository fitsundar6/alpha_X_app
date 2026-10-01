import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/core/widgets/server_config_dialog.dart';
import 'auth_service.dart';
import 'create_account_screen.dart';

/// The official Alpha X Gym Welcome & Authentication Login Screen.
///
/// Shows ONLY:
/// 1. Email / Client ID input
/// 2. Password input (hidden by default with show/hide toggle)
/// 3. Login button
/// 4. Create New Account button (opens separate [CreateAccountScreen])
class LoginScreen extends StatefulWidget {
  final bool initialIsJoinNow;

  const LoginScreen({
    super.key,
    this.initialIsJoinNow = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  // Login Form Controllers
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();
  bool _loginObscurePassword = true;

  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  /// Handles Client Login with Client ID (AXG-XXXX) or Email + Password
  Future<void> _handleClientLogin() async {
    FocusScope.of(context).unfocus();
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Verifying credentials with Alpha X Gym...';
    });

    try {
      final idOrEmail = _loginIdController.text.trim();
      final password = _loginPasswordController.text;

      // Safely normalize email if user typed an email address
      final normalizedIdentifier = idOrEmail.contains('@') ? idOrEmail.toLowerCase() : idOrEmail;

      final result = await _authService.loginWithCredentials(
        identifier: normalizedIdentifier,
        password: password,
      );

      if (!mounted) return;

      final role = result['role']?.toString();
      if (role == 'ADMIN') {
        Navigator.of(context).pushReplacementNamed('/admin');
        return;
      }

      final isAssessmentComplete = result['assessmentCompleted'] == true || _authService.onboardingCompleted;

      if (!isAssessmentComplete) {
        // Open / resume Fitness Assessment
        Navigator.of(context).pushReplacementNamed('/onboarding');
      } else {
        // Assessment completed -> Open Client Dashboard
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _openCreateAccountScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateAccountScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If opened with initialIsJoinNow: true (e.g. from tests or Join Now buttons), render CreateAccountScreen
    if (widget.initialIsJoinNow) {
      return const CreateAccountScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action: Server Settings for physical mobile testing
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.settings_ethernet, color: AppColors.textTertiary, size: 20),
                    tooltip: 'Server Settings',
                    onPressed: () => ServerConfigDialog.show(context),
                  ),
                ),

                // 1. Alpha X Gym Brand Logo & Crest
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
                    child: const AlphaXLogo(size: 44),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'ALPHA X GYM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),

                // Pill Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'MEMBER & ATHLETE PORTAL',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Error / Status Banners
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (_errorMessage!.toLowerCase().contains('connection') ||
                            _errorMessage!.toLowerCase().contains('server') ||
                            _errorMessage!.toLowerCase().contains('reach') ||
                            _errorMessage!.toLowerCase().contains('socket') ||
                            _errorMessage!.toLowerCase().contains('timeout')) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => ServerConfigDialog.show(context),
                              icon: const Icon(Icons.settings_ethernet, size: 14, color: AppColors.primaryRed),
                              label: const Text(
                                'Configure Server IP',
                                style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_statusMessage != null && _isLoading) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _statusMessage!,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Login Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _loginFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'LOG IN TO YOUR ACCOUNT',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter your email or Client ID (e.g. AXG-0001) and password.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 18),

                        // 1. Email / Client ID Field
                        TextFormField(
                          controller: _loginIdController,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Client ID / Email',
                            hintText: 'e.g. AXG-0001 or name@example.com',
                            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primaryRed, size: 20),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your Client ID or Email.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 2. Password Field
                        TextFormField(
                          controller: _loginPasswordController,
                          obscureText: _loginObscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryRed, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _loginObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter your password.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // 3. Login Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleClientLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'LOGIN',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppColors.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                'OR',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Expanded(child: Divider(color: AppColors.border)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // 4. Create New Account Button
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _openCreateAccountScreen,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'CREATE NEW ACCOUNT',
                              style: TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
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

                // 5. Bottom Actions: Guest Exploration & Dedicated Admin Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
                      child: const Text(
                        'Continue as Guest',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/login'),
                      icon: const Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryRed),
                      label: const Text(
                        'ADMIN LOGIN',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
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
    ),
  ),
);
}
}
