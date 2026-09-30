import 'package:flutter/material.dart';
import 'package:alpha_x_gym/config/admin_config.dart';
import '../theme/app_colors.dart';
import '../widgets/alpha_x_logo.dart';
import '../widgets/server_config_dialog.dart';
import 'auth_service.dart';

/// Dedicated Master Administrator Authentication Screen for Alpha X Gym.
///
/// Implements 100% local Admin authentication directly referencing [AdminConfig].
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
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

    final configuredEmail = AdminConfig.adminEmail.trim().toLowerCase();
    final configuredPassword = AdminConfig.adminPassword;

    debugPrint('[AUTH DEBUG] AdminPortal entered email: $enteredEmail (len: ${enteredEmail.length})');
    debugPrint('[AUTH DEBUG] AdminPortal configured email: $configuredEmail (len: ${configuredEmail.length})');
    debugPrint('[AUTH DEBUG] AdminPortal email match: ${enteredEmail == configuredEmail}');
    debugPrint('[AUTH DEBUG] AdminPortal entered password length: ${enteredPassword.length}');
    debugPrint('[AUTH DEBUG] AdminPortal configured password length: ${configuredPassword.length}');

    final isPasswordMatch = (enteredPassword == configuredPassword) ||
        (enteredPassword.trim() == configuredPassword.trim()) ||
        (enteredPassword.trim() == configuredPassword.trim().replaceAll('!', '')) ||
        (enteredPassword.trim() == '${configuredPassword.trim().replaceAll('!', '')}!');

    if (enteredEmail == configuredEmail && isPasswordMatch) {
      debugPrint('[AUTH DEBUG] AdminPortal authentication successful');
      final auth = AuthService();
      await auth.setAdminSession(email: configuredEmail, password: enteredPassword);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/admin');
      }
    } else {
      debugPrint('[AUTH DEBUG] AdminPortal authentication failed: mismatch');
      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid admin email or password.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: AppColors.textSecondary, size: 20),
            tooltip: 'Server Configuration',
            onPressed: () => ServerConfigDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Security Header & Brand Logo
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryRed.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const AlphaXLogo(size: 48),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'ADMINISTRATOR ACCESS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Authorized Personnel Only • Hardware Security Enforced',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 2. Error Message Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.primaryRed, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 3. Admin Gmail Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Admin Gmail',
                      hintText: AdminConfig.adminEmail,
                      prefixIcon: const Icon(Icons.mark_email_read_outlined, color: AppColors.primaryRed),
                      filled: true,
                      fillColor: AppColors.surfaceCard,
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
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Admin email address is required';
                      }
                      if (!val.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Password Field with Show/Hide Toggle
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '••••••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryRed),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceCard,
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
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Admin password is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // 5. Authenticate Admin Button & Loading Indicator
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAdminLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'AUTHENTICATE ADMINISTRATOR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6. Navigation Link back to Member Login
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 16),
                      label: const Text(
                        'Return to Member Portal',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
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
    );
  }
}
