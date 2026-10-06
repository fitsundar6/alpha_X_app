import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/core/widgets/server_config_dialog.dart';
import 'auth_service.dart';
import 'create_account_screen.dart';

/// The official Alpha X Gym Welcome & Authentication Login Screen.
/// Cinematic athletic hero background with clean upper lighting and "ALPHA-X" logo,
/// and a frosted-glass dark theme authentication card positioned in the lower third.
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background image set behind all UI components (z-index: 0 / bottom of Stack)
          // Aligned to top center and scaled (BoxFit.contain) so subject & glowing "ALPHA-X" text are fully visible in the upper section without being zoomed in or cropped
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: FractionalTranslation(
                // Positioned -15% of screen height (adjusted downward by 5% from previous -20%):
                translation: const Offset(0.0, -0.15),
                child: Image.asset(
                  'assets/images/alpha_x_login_bg.jpg',
                  fit: BoxFit.contain,
                  alignment: const Alignment(0.0, -1.0),
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/alpha_x_login_bg.png',
                    fit: BoxFit.contain,
                    alignment: const Alignment(0.0, -1.0),
                    errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),

          // 2. Foreground UI: Top bar + all login inputs pushed all the way to the bottom third
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar: Server Settings (unobtrusive, safe from notches)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings_ethernet, color: AppColors.textTertiary, size: 20),
                        tooltip: 'Server Settings',
                        onPressed: () => ServerConfigDialog.show(context),
                      ),
                    ),
                  ),
                ),

                // Expanded space keeping upper section completely open for the spotlight, "ALPHA-X", and subject
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Error / Status Banners if active
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.danger.withOpacity(0.6)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  if (_statusMessage != null && _isLoading) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _statusMessage!,
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // 4. Subtle transparent dark tint with soft blur (backdrop-filter: blur)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.24), // subtle transparent dark tint
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.18),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.22),
                                              blurRadius: 18,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Form(
                                          key: _loginFormKey,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Compact Header: Logo + ALPHA X GYM + PORTAL
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const AlphaXLogo.badge(size: 18),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'ALPHA X GYM',
                                                      style: GoogleFonts.poppins(
                                                        color: AppColors.textPrimary,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary.withOpacity(0.18),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: AppColors.primary.withOpacity(0.4),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'MEMBER & ATHLETE PORTAL',
                                                        style: GoogleFonts.poppins(
                                                          color: AppColors.primary,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 6),

                                              Center(
                                                child: Text(
                                                  'LOG IN TO YOUR ACCOUNT',
                                                  style: GoogleFonts.poppins(
                                                    color: AppColors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),

                                              // Email / Client ID Input Field
                                              TextFormField(
                                                controller: _loginIdController,
                                                keyboardType: TextInputType.emailAddress,
                                                textCapitalization: TextCapitalization.none,
                                                autocorrect: false,
                                                style: GoogleFonts.poppins(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13,
                                                ),
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  labelText: 'Client ID / Email',
                                                  hintText: 'e.g. AXG-0001 or name@example.com',
                                                  labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                                                  hintStyle: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 10),
                                                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 16),
                                                  filled: true,
                                                  fillColor: Colors.black.withOpacity(0.25),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                                  ),
                                                  errorBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
                                                  ),
                                                  focusedErrorBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                                                  ),
                                                ),
                                                validator: (v) {
                                                  if (v == null || v.trim().isEmpty) return 'Please enter your Client ID or Email.';
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 6),

                                              // Password Input Field
                                              TextFormField(
                                                controller: _loginPasswordController,
                                                obscureText: _loginObscurePassword,
                                                keyboardType: TextInputType.visiblePassword,
                                                style: GoogleFonts.poppins(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13,
                                                ),
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  labelText: 'Password',
                                                  labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                                                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary, size: 16),
                                                  suffixIcon: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    icon: Icon(
                                                      _loginObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                                      color: AppColors.textSecondary,
                                                      size: 16,
                                                    ),
                                                    onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.black.withOpacity(0.25),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                                  ),
                                                  errorBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
                                                  ),
                                                  focusedErrorBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                                                  ),
                                                ),
                                                validator: (v) {
                                                  if (v == null || v.isEmpty) return 'Please enter your password.';
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 10),

                                              // Primary Login CTA Button
                                              Container(
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(999),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: AppColors.glow,
                                                      blurRadius: 14,
                                                      spreadRadius: 1,
                                                      offset: Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  onPressed: _isLoading ? null : _handleClientLogin,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.primary,
                                                    foregroundColor: AppColors.onPrimary,
                                                    shape: const StadiumBorder(),
                                                    elevation: 0,
                                                  ),
                                                  child: _isLoading
                                                      ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2.0,
                                                            color: AppColors.onPrimary,
                                                          ),
                                                        )
                                                      : Stack(
                                                          alignment: Alignment.center,
                                                          children: [
                                                            Text(
                                                              'CLIENT LOGIN',
                                                              style: GoogleFonts.poppins(
                                                                color: AppColors.onPrimary,
                                                                fontWeight: FontWeight.w800,
                                                                fontSize: 12.5,
                                                                letterSpacing: 0.8,
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
                                              const SizedBox(height: 6),

                                              // Divider
                                              Row(
                                                children: [
                                                  Expanded(child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                    child: Text(
                                                      'OR',
                                                      style: GoogleFonts.poppins(
                                                        color: AppColors.textTertiary,
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        letterSpacing: 0.8,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
                                                ],
                                              ),
                                              const SizedBox(height: 6),

                                              // Secondary Outlined Frosted Button for Create Account
                                              SizedBox(
                                                height: 38,
                                                child: OutlinedButton(
                                                  onPressed: _isLoading ? null : _openCreateAccountScreen,
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: AppColors.primary.withOpacity(0.85), width: 1.2),
                                                    shape: const StadiumBorder(),
                                                    backgroundColor: Colors.white.withOpacity(0.04),
                                                  ),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Text(
                                                        'CREATE ACCOUNT',
                                                        style: GoogleFonts.poppins(
                                                          color: AppColors.primary,
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 11.5,
                                                          letterSpacing: 0.8,
                                                        ),
                                                      ),
                                                      Opacity(
                                                        opacity: 0.0,
                                                        child: Text(
                                                          'CREATE NEW ACCOUNT',
                                                          style: GoogleFonts.poppins(
                                                            color: AppColors.primary,
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 11.5,
                                                            letterSpacing: 0.8,
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
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Dedicated Admin Login Action Link
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/login'),
                                      icon: const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                                      label: Text(
                                        'ADMIN LOGIN',
                                        style: GoogleFonts.poppins(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
