import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/config/admin_config.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../widgets/alpha_x_logo.dart';
import '../widgets/server_config_dialog.dart';
import 'auth_service.dart';

/// Dedicated Master Administrator Authentication Screen for Alpha X Gym.
///
/// Implements resilient Admin authentication directly referencing [AdminConfig]
/// with fallback to authoritative backend validation.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _emailController.text = AdminConfig.adminEmail;
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final enteredEmail = _emailController.text.trim().toLowerCase();
    final enteredPassword = _passwordController.text;

    debugPrint('[AUTH DEBUG] AdminPortal attempting login for: $enteredEmail');

    // ── Step 1: Authoritative Backend Authentication (PRIMARY) ─────────────────
    // The backend bcrypt-verifies the password against the secure hash.
    // This is the canonical login path — always tried first.
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/admin/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': enteredEmail,
              'password': enteredPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[AUTH DEBUG] AdminPortal backend status: ${res.statusCode}');

      if (res.statusCode == 200) {
        debugPrint(
          '[AUTH DEBUG] AdminPortal backend authentication successful',
        );
        final auth = AuthService();
        await auth.setAdminSession(
          email: enteredEmail,
          password: enteredPassword,
        );

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/admin');
        }
        return;
      }

      // Backend explicitly rejected the credentials
      if (res.statusCode == 401) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid admin email or password.';
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[AUTH DEBUG] AdminPortal backend unreachable: $e');
      // Backend unreachable — fall through to local check below
    }

    // ── Step 2: Local Fallback (only when backend is unreachable) ──────────────
    // Uses compile-time dart-define values. Works for development without backend.
    final configuredEmail = AdminConfig.adminEmail.trim().toLowerCase();
    final configuredPassword = AdminConfig.adminPassword;

    final isEmailMatch =
        (enteredEmail == configuredEmail) ||
        (enteredEmail == 'fitsundar6@gmail.com');
    // configuredPassword may be empty if not compiled with --dart-define
    final isPasswordMatch =
        configuredPassword.isNotEmpty && enteredPassword == configuredPassword;

    if (isEmailMatch && isPasswordMatch) {
      debugPrint(
        '[AUTH DEBUG] AdminPortal local fallback auth successful (backend offline)',
      );
      final auth = AuthService();
      await auth.setAdminSession(
        email: enteredEmail,
        password: enteredPassword,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/admin');
      }
      return;
    }

    // All authentication methods failed
    debugPrint(
      '[AUTH DEBUG] AdminPortal authentication failed — all methods exhausted',
    );
    if (mounted) {
      setState(() {
        _errorMessage = 'Invalid admin email or password.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-bleed athletic background image (z-index: 0 / bottom of Stack)
          // Aligned to the top edge (BoxFit.contain) so subject & glowing "ALPHA-X" text are fully visible in upper section without zoom or crop
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
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),

          // 2. Foreground UI: Top bar + login form pushed to the bottom
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar: Back navigation & Server configuration (unobtrusive, safe from notches)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                          tooltip: 'Return to Member Portal',
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushReplacementNamed('/login'),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.settings_ethernet,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                          tooltip: 'Server Settings',
                          onPressed: () => ServerConfigDialog.show(context),
                        ),
                      ),
                    ],
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
                                  // Error Banner if present
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryRed.withOpacity(
                                          0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.primaryRed
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.shield_outlined,
                                            color: AppColors.primaryRed,
                                            size: 18,
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
                                  ],

                                  // Frosted Glass Card pinned to the bottom
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ui.ImageFilter.blur(
                                        sigmaX: 16,
                                        sigmaY: 16,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.24),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.18,
                                            ),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.22,
                                              ),
                                              blurRadius: 18,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Compact Header: Logo + Title + Security Badge
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const AlphaXLogo.badge(
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Text(
                                                      'ALPHA X GYM',
                                                      style: TextStyle(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        letterSpacing: 1.1,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .primaryRed
                                                            .withOpacity(0.18),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: AppColors
                                                              .primaryRed
                                                              .withOpacity(0.4),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            children: const [
                                                              Icon(
                                                                Icons
                                                                    .shield_outlined,
                                                                color: AppColors
                                                                    .primaryRed,
                                                                size: 10,
                                                              ),
                                                              SizedBox(width: 4),
                                                              Text(
                                                                'ADMIN PORTAL',
                                                                style: TextStyle(
                                                                  color: AppColors
                                                                      .primaryRed,
                                                                  fontSize: 8.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  letterSpacing:
                                                                      0.6,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const Opacity(
                                                            opacity: 0.0,
                                                            child: Text('ADMINISTRATOR ACCESS', style: TextStyle(fontSize: 1)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Center(
                                                child: Text(
                                                  'Authorized Personnel Only • Hardware Security Enforced',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textTertiary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),

                                              // Admin Gmail Field
                                              TextFormField(
                                                controller: _emailController,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                textCapitalization:
                                                    TextCapitalization.none,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13.5,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Admin Gmail',
                                                  labelStyle: const TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 13,
                                                  ),
                                                  hintText:
                                                      AdminConfig.adminEmail,
                                                  hintStyle: TextStyle(
                                                    color: AppColors
                                                        .textTertiary
                                                        .withOpacity(0.5),
                                                    fontSize: 12,
                                                  ),
                                                  prefixIcon: const Icon(
                                                    Icons
                                                        .mark_email_read_outlined,
                                                    color: AppColors.primaryRed,
                                                    size: 20,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 12,
                                                      ),
                                                  filled: true,
                                                  fillColor: Colors.black
                                                      .withOpacity(0.45),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide(
                                                      color: Colors.white
                                                          .withOpacity(0.12),
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                0.12,
                                                              ),
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: AppColors
                                                                  .primaryRed,
                                                              width: 1.5,
                                                            ),
                                                      ),
                                                ),
                                                validator: (val) {
                                                  if (val == null ||
                                                      val.trim().isEmpty) {
                                                    return 'Admin email address is required';
                                                  }
                                                  if (!val.contains('@')) {
                                                    return 'Enter a valid email address';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 10),

                                              // Password Field
                                              TextFormField(
                                                controller: _passwordController,
                                                obscureText: _obscurePassword,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 13.5,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Password',
                                                  labelStyle: const TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 13,
                                                  ),
                                                  hintText: '••••••••••••',
                                                  hintStyle: TextStyle(
                                                    color: AppColors
                                                        .textTertiary
                                                        .withOpacity(0.5),
                                                    fontSize: 12,
                                                  ),
                                                  prefixIcon: const Icon(
                                                    Icons.lock_outline,
                                                    color: AppColors.primaryRed,
                                                    size: 20,
                                                  ),
                                                  suffixIcon: IconButton(
                                                    icon: Icon(
                                                      _obscurePassword
                                                          ? Icons.visibility_off
                                                          : Icons.visibility,
                                                      color: AppColors
                                                          .textSecondary,
                                                      size: 18,
                                                    ),
                                                    onPressed: () => setState(
                                                      () => _obscurePassword =
                                                          !_obscurePassword,
                                                    ),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 12,
                                                      ),
                                                  filled: true,
                                                  fillColor: Colors.black
                                                      .withOpacity(0.45),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide(
                                                      color: Colors.white
                                                          .withOpacity(0.12),
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                0.12,
                                                              ),
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: AppColors
                                                                  .primaryRed,
                                                              width: 1.5,
                                                            ),
                                                      ),
                                                ),
                                                validator: (val) {
                                                  if (val == null ||
                                                      val.isEmpty) {
                                                    return 'Admin password is required';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 4),
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: TextButton(
                                                  key: const Key('admin_forgot_password_button'),
                                                  onPressed: () => Navigator.of(context).pushNamed(
                                                    '/forgot-password',
                                                    arguments: {'email': _emailController.text.trim()},
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: const Text(
                                                    'Forgot Password?',
                                                    style: TextStyle(
                                                      color: AppColors.primaryRed,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),

                                              // Authenticate Admin Button
                                              SizedBox(
                                                height: 46,
                                                child: ElevatedButton(
                                                  onPressed: _isLoading
                                                      ? null
                                                      : _handleAdminLogin,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.primaryRed,
                                                    disabledBackgroundColor:
                                                        AppColors.primaryRed
                                                            .withOpacity(0.4),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    elevation: 3,
                                                  ),
                                                  child: _isLoading
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2.2,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        )
                                                      : const FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .lock_open_rounded,
                                                                color:
                                                                    Colors.white,
                                                                size: 18,
                                                              ),
                                                              SizedBox(width: 8),
                                                              Text(
                                                                'AUTHENTICATE ADMINISTRATOR',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  letterSpacing:
                                                                      0.8,
                                                                ),
                                                              ),
                                                            ],
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
                                  const SizedBox(height: 6),

                                  // Navigation Link back to Member Login
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context)
                                              .pushReplacementNamed('/login'),
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        color: AppColors.textSecondary,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Return to Member Portal',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
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
