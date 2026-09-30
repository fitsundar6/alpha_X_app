import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/core/widgets/server_config_dialog.dart';
import 'auth_service.dart';

/// The official Alpha X Gym Welcome & Authentication Screen.
///
/// Features:
/// 1. CLIENT LOGIN: Client ID (e.g. AXG-0001) / Username / Email + Password.
/// 2. CLIENT ACCOUNT CREATION: Full Name, Email, Phone, Password, Confirm Password.
///    - Generates unique permanent Client ID (AXG-XXXX).
///    - Prominently displays the generated Client ID and reminds client to keep it safe.
/// 3. FITNESS ASSESSMENT ROUTING:
///    - If assessmentCompleted == false -> Opens / Resumes Assessment.
///    - If assessmentCompleted == true -> Opens Client Dashboard.
/// 4. MASTER ADMIN ACCESS: Dedicated portal link to working [AdminLoginScreen].
class LoginScreen extends StatefulWidget {
  final bool initialIsJoinNow;

  const LoginScreen({
    super.key,
    this.initialIsJoinNow = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  // Tab controller for [ CLIENT LOGIN ] vs [ CREATE ACCOUNT ]
  late TabController _tabController;

  // Login Form Controllers
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();
  bool _loginObscurePassword = true;

  // Registration Form Controllers
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regFormKey = GlobalKey<FormState>();
  bool _regObscurePassword = true;
  bool _regObscureConfirmPassword = true;

  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIsJoinNow ? 1 : 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  /// Handles Client Login with Client ID (AXG-XXXX) or Email + Password
  Future<void> _handleClientLogin() async {
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

  /// Handles Client Account Creation
  Future<void> _handleClientRegister() async {
    if (!_regFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Creating your Alpha X Gym account & assigning Client ID...';
    });

    try {
      final name = _regNameController.text.trim();
      final email = _regEmailController.text.trim().toLowerCase();
      final phone = _regPhoneController.text.trim();
      final password = _regPasswordController.text;
      final confirmPassword = _regConfirmPasswordController.text;

      final result = await _authService.registerClientAccount(
        name: name,
        email: email,
        phone: phone,
        password: password,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;

      final generatedClientId = result['clientId']?.toString() ?? _authService.currentClientId;

      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });

      // Show prominent Client ID announcement dialog
      _showClientIdCreatedDialog(generatedClientId);
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

  /// Displays clear celebratory dialog showing the generated Client ID
  void _showClientIdCreatedDialog(String clientId) {
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
                child: const Icon(Icons.check_circle_outline, color: AppColors.primaryRed, size: 36),
              ),
              const SizedBox(height: 12),
              const Text(
                'ACCOUNT CREATED!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Alpha X Gym. Your permanent Client ID has been generated:',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 16),
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
                        'Keep this ID safe! You will use this Client ID and your password to log in anytime.',
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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

                // 3. Tab Bar: [ CLIENT LOGIN ] & [ CREATE ACCOUNT ]
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primaryRed,
                    indicatorWeight: 3,
                    labelColor: AppColors.primaryRed,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
                    tabs: const [
                      Tab(text: 'CLIENT LOGIN'),
                      Tab(text: 'CREATE ACCOUNT'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Tab Views
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _tabController.index == 0
                        ? _buildLoginForm()
                        : _buildRegisterForm(),
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
    );
  }

  /// Tab 0: Client Login Form (Client ID + Password)
  Widget _buildLoginForm() {
    return Form(
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
            'Enter your permanent Client ID (e.g. AXG-0001) or email and password.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),

          // Client ID / Username / Email Field
          // Note: Client ID is treated as STRING/TEXT (NOT number-only keyboard!)
          TextFormField(
            controller: _loginIdController,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
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

          // Password Field
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

          // Login Button
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
        ],
      ),
    );
  }

  /// Tab 1: "Create Your Alpha X Gym Account" Form
  Widget _buildRegisterForm() {
    return Form(
      key: _regFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CREATE YOUR ALPHA X GYM ACCOUNT',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your details below. A unique Client ID will be automatically generated for you.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),

          // 1. Full Name (Letters/Text)
          TextFormField(
            controller: _regNameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'e.g. Alex Hunter',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryRed, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Full Name cannot be empty.';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 2. Email Address
          TextFormField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'name@example.com',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryRed, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required.';
              if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email address.';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 3. Phone Number (Stored as String to preserve country code & leading zeros)
          TextFormField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1 (555) 000-0000',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primaryRed, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone number is required.';
              if (v.trim().length < 6) return 'Please enter a valid phone number.';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 4. Password Field
          TextFormField(
            controller: _regPasswordController,
            obscureText: _regObscurePassword,
            keyboardType: TextInputType.visiblePassword,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryRed, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _regObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _regObscurePassword = !_regObscurePassword),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.length < 6) return 'Password must be at least 6 characters.';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 5. Confirm Password Field
          TextFormField(
            controller: _regConfirmPasswordController,
            obscureText: _regObscureConfirmPassword,
            keyboardType: TextInputType.visiblePassword,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.lock_clock_outlined, color: AppColors.primaryRed, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _regObscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _regObscureConfirmPassword = !_regObscureConfirmPassword),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password.';
              if (v != _regPasswordController.text) return 'Passwords do not match.';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Create Account Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleClientClientRegisterFromTab,
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
                      'CREATE ACCOUNT',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleClientClientRegisterFromTab() {
    _handleClientRegister();
  }
}
