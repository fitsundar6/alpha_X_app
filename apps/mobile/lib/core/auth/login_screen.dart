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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Full-screen athletic background image covering entire display behind safe areas & notches
          Positioned.fill(
            child: Image.asset(
              'assets/images/alpha_x_login_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/alpha_x_login_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => Container(color: AppColors.background),
              ),
            ),
          ),

          // 2. Smooth ambient vignette for lower third blending (top half remains 100% crystal clear)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // 3. Foreground Interactive Content adjusted for Safe Areas & Notches
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Bar: Server configuration action (unobtrusive, safe from notches)
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.40),
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

                            // Top half kept clean so lighting & "ALPHA-X" typography remain completely visible
                            const Spacer(),

                            // Animated entrance for interactive form
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Error / Status Banners if active
                                    if (_errorMessage != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.danger.withOpacity(0.6)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 13,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
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
                                              style: GoogleFonts.poppins(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Frosted-Glass Dark Theme Container in the lower third
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(26),
                                      child: BackdropFilter(
                                        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xCC161820),
                                                Color(0xAA0B0C10),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(26),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.14),
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.55),
                                                blurRadius: 30,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                          child: Form(
                                            key: _loginFormKey,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                // Official Brand Logo (compact badge)
                                                const Center(
                                                  child: AlphaXLogo.badge(size: 30),
                                                ),
                                                const SizedBox(height: 6),

                                                // Bold Headline
                                                Center(
                                                  child: Text(
                                                    'ALPHA X GYM',
                                                    style: GoogleFonts.poppins(
                                                      color: AppColors.textPrimary,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 1.4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),

                                                // Subtitle Tagline & Badge
                                                Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: AppColors.primary.withOpacity(0.4),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'MEMBER & ATHLETE PORTAL',
                                                      style: GoogleFonts.poppins(
                                                        color: AppColors.primary,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 14),

                                                Text(
                                                  'LOG IN TO YOUR ACCOUNT',
                                                  style: GoogleFonts.poppins(
                                                    color: AppColors.textPrimary,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Enter your email or Client ID (e.g. AXG-0001) and password.',
                                                  style: GoogleFonts.poppins(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),

                                                // 1. Email / Client ID Input Field
                                                TextFormField(
                                                  controller: _loginIdController,
                                                  keyboardType: TextInputType.emailAddress,
                                                  textCapitalization: TextCapitalization.none,
                                                  autocorrect: false,
                                                  style: GoogleFonts.poppins(
                                                    color: AppColors.textPrimary,
                                                    fontSize: 14,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Client ID / Email',
                                                    hintText: 'e.g. AXG-0001 or name@example.com',
                                                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                                                    filled: true,
                                                    fillColor: Colors.white.withOpacity(0.06),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                                    ),
                                                    errorBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
                                                    ),
                                                    focusedErrorBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                                                    ),
                                                  ),
                                                  validator: (v) {
                                                    if (v == null || v.trim().isEmpty) return 'Please enter your Client ID or Email.';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 12),

                                                // 2. Password Input Field
                                                TextFormField(
                                                  controller: _loginPasswordController,
                                                  obscureText: _loginObscurePassword,
                                                  keyboardType: TextInputType.visiblePassword,
                                                  style: GoogleFonts.poppins(
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
                                                    fillColor: Colors.white.withOpacity(0.06),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                                    ),
                                                    errorBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
                                                    ),
                                                    focusedErrorBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                                                    ),
                                                  ),
                                                  validator: (v) {
                                                    if (v == null || v.isEmpty) return 'Please enter your password.';
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 16),

                                                // 3. Primary Gold/Lime Pill Login CTA Button
                                                Container(
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(999),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: AppColors.glow,
                                                        blurRadius: 18,
                                                        spreadRadius: 1,
                                                        offset: Offset(0, 4),
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
                                                                style: GoogleFonts.poppins(
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
                                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                                      child: Text(
                                                        'OR',
                                                        style: GoogleFonts.poppins(
                                                          color: AppColors.textTertiary,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          letterSpacing: 0.8,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),

                                                // 4. Secondary Outlined Frosted Pill Button for Create Account
                                                SizedBox(
                                                  height: 48,
                                                  child: OutlinedButton(
                                                    onPressed: _isLoading ? null : _openCreateAccountScreen,
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: AppColors.primary, width: 1.5),
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
                                                            fontSize: 13,
                                                            letterSpacing: 1.0,
                                                          ),
                                                        ),
                                                        Opacity(
                                                          opacity: 0.0,
                                                          child: Text(
                                                            'CREATE NEW ACCOUNT',
                                                            style: GoogleFonts.poppins(
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
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 5. Dedicated Admin Login Action Link
                            Center(
                              child: TextButton.icon(
                                onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/login'),
                                icon: const Icon(Icons.shield_outlined, size: 15, color: AppColors.primary),
                                label: Text(
                                  'ADMIN LOGIN',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
