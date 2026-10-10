import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo_animation.dart';
import 'package:alpha_x_gym/core/widgets/server_config_dialog.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_button.dart';
import 'auth_service.dart';
import 'create_account_screen.dart';

/// The official Alpha X Gym Welcome & Authentication Login Screen.
/// Features a cinematic 4.5-second logo reveal on app launch that transitions
/// seamlessly into the frosted-glass authentication card in the lower third.
class LoginScreen extends StatefulWidget {
  final bool initialIsJoinNow;
  final bool? animateLogo;

  /// Session tracking so the 4.5s intro animation only plays on initial launch
  static bool hasPlayedIntro = false;

  const LoginScreen({
    super.key,
    this.initialIsJoinNow = false,
    this.animateLogo,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  // Dark-themed card (#141414) and Gold accent (#D4A034)
  static const Color _cardBackground = Color(0xFF141414);
  static const Color _goldAccent = Color(0xFFD4A034);

  // Login Form Controllers
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();
  bool _loginObscurePassword = true;

  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  late final AnimationController _animController;
  late final Animation<double> _bgFadeAnimation;
  late final Animation<double> _cardFadeAnimation;
  late final Animation<Offset> _cardSlideAnimation;
  late final Animation<double> _topBarFadeAnimation;
  late final Animation<Alignment> _heroAlignmentAnimation;
  late final Animation<double> _heroScaleAnimation;
  late final Animation<double> _heroOpacityAnimation;

  @override
  void initState() {
    super.initState();

    final shouldAnimate = widget.animateLogo ?? (!LoginScreen.hasPlayedIntro);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
      value: shouldAnimate ? 0.0 : 1.0,
    );

    // Phase 5 Transition Curves (3.8s - 4.6s -> 0.826 - 1.000)
    _bgFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.826, 1.000, curve: Curves.easeIn),
    );

    _cardFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.826, 1.000, curve: Curves.easeOutCubic),
    );

    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.826, 1.000, curve: Curves.easeOutCubic),
      ),
    );

    _topBarFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.870, 1.000, curve: Curves.easeOut),
    );

    // Continuous Hero Logo Glide: moves from center (0.0, -0.18) to upper spotlight (0.0, -0.62)
    _heroAlignmentAnimation = AlignmentTween(
      begin: const Alignment(0.0, -0.18),
      end: const Alignment(0.0, -0.62),
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.826, 1.000, curve: Curves.easeInOutCubic),
      ),
    );

    _heroScaleAnimation = Tween<double>(begin: 1.0, end: 0.72).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.826, 1.000, curve: Curves.easeInOutCubic),
      ),
    );

    _heroOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.880, 1.000, curve: Curves.easeOut),
      ),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        LoginScreen.hasPlayedIntro = true;
      }
    });

    if (shouldAnimate) {
      _animController.forward();
    } else {
      LoginScreen.hasPlayedIntro = true;
    }
  }

  /// Fast-forwards gracefully to the settled login UI on user tap
  void _skipIntro() {
    if (_animController.value < 0.826) {
      _animController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      LoginScreen.hasPlayedIntro = true;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
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

      // Forced Password Change Gate (for temporary passwords issued by admin):
      if (result['mustChangePassword'] == true) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/reset-password',
          (route) => false,
          arguments: {
            'mode': 'code',
            'forcedChange': true,
            'identifier': normalizedIdentifier,
          },
        );
        return;
      }

      // User Verification Status Routing:
      final status = (result['status']?.toString() ?? _authService.userStatus).toUpperCase();
      if (status == 'PENDING') {
        Navigator.of(context).pushNamedAndRemoveUntil('/pending-verification', (route) => false);
        return;
      } else if (status == 'REJECTED') {
        Navigator.of(context).pushNamedAndRemoveUntil('/rejected-account', (route) => false);
        return;
      } else if (status == 'SUSPENDED') {
        Navigator.of(context).pushNamedAndRemoveUntil('/suspended-account', (route) => false);
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _skipIntro,
        child: Stack(
          children: [
            // 1. Background image (cross-fades in during transition phase)
            Positioned.fill(
              child: FadeTransition(
                opacity: _bgFadeAnimation,
                child: ColoredBox(
                  color: Colors.black,
                  child: FractionalTranslation(
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
            ),

            // 2. Cinematic Hero Logo Animation (0.0s - 4.6s)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    if (_animController.value >= 1.0) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: _heroAlignmentAnimation.value,
                      child: Transform.scale(
                        scale: _heroScaleAnimation.value,
                        child: Opacity(
                          opacity: _heroOpacityAnimation.value.clamp(0.0, 1.0),
                          child: AlphaXLogoAnimation(
                            controller: _animController,
                            size: 150,
                            allowTapToSkip: false,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. Foreground UI: Top bar + login inputs pushed to lower third
            SafeArea(
              top: true,
              bottom: true,
              maintainBottomViewPadding: true,
              minimum: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Bar: Server Settings (unobtrusive, safe from notches)
                  FadeTransition(
                    opacity: _topBarFadeAnimation,
                    child: Align(
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
                  ),

                  // Expanded space keeping upper section completely open for spotlight & logo
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: FadeTransition(
                              opacity: _cardFadeAnimation,
                              child: SlideTransition(
                                position: _cardSlideAnimation,
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
                                          color: _cardBackground, // #141414 dark-themed card
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.12),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.50),
                                              blurRadius: 24,
                                              offset: const Offset(0, 8),
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
                                                        color: _goldAccent.withOpacity(0.18),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: _goldAccent.withOpacity(0.4),
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
                                                  prefixIcon: const Icon(Icons.badge_outlined, color: _goldAccent, size: 16),
                                                  filled: true,
                                                  fillColor: Colors.black.withOpacity(0.25),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: _goldAccent, width: 1.5),
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
                                                  prefixIcon: const Icon(Icons.lock_outline, color: _goldAccent, size: 16),
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
                                                    borderSide: const BorderSide(color: _goldAccent, width: 1.5),
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
                                              const SizedBox(height: 4),

                                              // Forgot Password Action Link
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: TextButton(
                                                  key: const Key('forgot_password_button'),
                                                  onPressed: () => Navigator.of(context).pushNamed('/forgot-password'),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    'Forgot Password?',
                                                    style: GoogleFonts.poppins(
                                                      color: _goldAccent,
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),

                                               // Reusable Solid Gold Action Button (#D4A034, Rounded Corners, Non-Clipping)
                                               AlphaXActionButton.solid(
                                                 label: 'CLIENT LOGIN',
                                                 isLoading: _isLoading,
                                                 onPressed: _handleClientLogin,
                                                 height: 48,
                                                 borderRadius: BorderRadius.circular(12),
                                                 goldColor: _goldAccent,
                                                 hiddenTestLabels: const ['LOGIN'],
                                               ),
                                               const SizedBox(height: 8),

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
                                               const SizedBox(height: 8),

                                               // Reusable Outlined Action Button (#D4A034, Rounded Corners, Non-Clipping)
                                               AlphaXActionButton.outlined(
                                                 label: 'CREATE ACCOUNT',
                                                 isLoading: _isLoading,
                                                 onPressed: _openCreateAccountScreen,
                                                 height: 48,
                                                 borderRadius: BorderRadius.circular(12),
                                                 goldColor: _goldAccent,
                                                 hiddenTestLabels: const ['CREATE NEW ACCOUNT'],
                                               ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Dedicated Admin Login Action Link (With SafeArea insets to prevent iOS home indicator collision)
                                  const SizedBox(height: 4),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        key: const Key('admin_login_link_button'),
                                        onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/login'),
                                        icon: const Icon(Icons.shield_outlined, size: 14, color: _goldAccent),
                                        label: Text(
                                          'ADMIN LOGIN',
                                          style: GoogleFonts.poppins(
                                            color: _goldAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
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
    ),
  );
}
}
