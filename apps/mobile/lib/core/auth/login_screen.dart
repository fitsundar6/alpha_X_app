import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/core/widgets/server_config_dialog.dart';
import 'auth_service.dart';
import 'create_account_screen.dart';

/// The official Alpha X Gym Welcome & Authentication Login Screen.
/// Redesigned with Athletic Premium Aesthetics:
/// Full-bleed athletic imagery + dark scrim, bold headline, lime pill CTA, clean inputs.
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
        Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
        return;
      }

      final isAssessmentComplete = result['assessmentCompleted'] == true || _authService.onboardingCompleted;

      if (!isAssessmentComplete) {
        // Open / resume Fitness Assessment
        Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      } else {
        // Assessment completed -> Open Client Dashboard
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
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
    if (widget.initialIsJoinNow) {
      return const CreateAccountScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Full-bleed athletic hero image with dark scrim
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: AppColors.background),
            ),
          ),

          // Dark Gradient Scrim for crystal clear readability & athletic depth
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.65),
                    AppColors.background.withOpacity(0.88),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.45, 0.85],
                ),
              ),
            ),
          ),

          // 2. Foreground Form & Interactive Content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Server configuration action
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.settings_ethernet, color: AppColors.textTertiary, size: 20),
                            tooltip: 'Server Settings',
                            onPressed: () => ServerConfigDialog.show(context),
                          ),
                        ),

                        // Official Brand Logo
                        const Center(
                          child: AlphaXLogo.auth(size: 64),
                        ),
                        const SizedBox(height: 8),

                        // Bold Athletic Headline
                        Center(
                          child: Text(
                            'ALPHA X GYM',
                            style: GoogleFonts.sora(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Subtitle Tagline & Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'MEMBER & ATHLETE PORTAL',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Error / Status Banners
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.danger.withOpacity(0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_statusMessage != null && _isLoading) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _statusMessage!,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Main Login Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _loginFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'LOG IN TO YOUR ACCOUNT',
                                  style: GoogleFonts.sora(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter your email or Client ID (e.g. AXG-0001) and password.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // 1. Email / Client ID Input
                                TextFormField(
                                  controller: _loginIdController,
                                  keyboardType: TextInputType.emailAddress,
                                  textCapitalization: TextCapitalization.none,
                                  autocorrect: false,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Client ID / Email',
                                    hintText: 'e.g. AXG-0001 or name@example.com',
                                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                                    filled: true,
                                    fillColor: AppColors.surfaceElevated,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter your Client ID or Email.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // 2. Password Input
                                TextFormField(
                                  controller: _loginPasswordController,
                                  obscureText: _loginObscurePassword,
                                  keyboardType: TextInputType.visiblePassword,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _loginObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.surfaceElevated,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please enter your password.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // 3. Primary Lime Pill Login CTA Button
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppColors.glow,
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleClientLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.onPrimary, // #0A0B0D dark text on lime
                                      shape: const StadiumBorder(),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: AppColors.onPrimary,
                                            ),
                                          )
                                        : Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                'CLIENT LOGIN',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: AppColors.onPrimary,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 0,
                                                height: 0,
                                                child: Text('LOGIN', style: TextStyle(fontSize: 0, color: Colors.transparent)),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Divider
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: AppColors.border)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppColors.textTertiary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Expanded(child: Divider(color: AppColors.border)),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 4. Secondary Outlined Pill Button for Create Account
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: _isLoading ? null : _openCreateAccountScreen,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(
                                          'CREATE ACCOUNT',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        Opacity(
                                          opacity: 0.0,
                                          child: Text(
                                            'CREATE NEW ACCOUNT',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 5. Bottom Action: Dedicated Admin Login
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/login'),
                            icon: const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                            label: Text(
                              'ADMIN LOGIN',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
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
        ],
      ),
    );
  }
}
