import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/alpha_x_button.dart';
import '../widgets/alpha_x_logo.dart';
import '../widgets/server_config_dialog.dart';
import 'auth_service.dart';
import '../../config/admin_config.dart';

/// Password Recovery Request Screen for Alpha X Gym.
///
/// Implements Admin-Assisted Password Recovery as the sole recovery method.
/// Informs athletes to obtain a single-use 6-digit reset code from the gym
/// administrator and proceed to the reset password screen.
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _goldAccent = Color(0xFFD4A034);

  String? _identifier;
  Map<String, dynamic> _gymContactInfo = {
    'gymName': 'Alpha X Gym',
    'adminEmail': AdminConfig.adminEmail,
    'deskPhone': '+1 (555) 019-2834',
    'deskHours': 'Mon-Sun 6:00 AM - 10:00 PM',
    'instructions':
        'Visit the front desk or contact your administrator to verify your athlete identity and receive a secure single-use reset code.',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _identifier = widget.initialEmail;
    }
    _fetchGymContactInfo();
  }

  void _fetchGymContactInfo() {
    AuthService().getGymContactInfo().then((info) {
      if (mounted && info.isNotEmpty) {
        setState(() {
          _gymContactInfo = info;
        });
      }
    }).catchError((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] is String && (_identifier == null || _identifier!.isEmpty)) {
      _identifier = args['email'] as String;
    }
  }

  void _navigateToResetPassword() {
    Navigator.of(context).pushNamed(
      '/reset-password',
      arguments: {
        'mode': 'code',
        if (_identifier != null && _identifier!.isNotEmpty) 'identifier': _identifier,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient & Athletic Theme
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
                // Top Navigation Bar
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
                          key: const Key('forgot_password_back_button'),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                          tooltip: 'Return to Login',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'PASSWORD RECOVERY',
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
                          key: const Key('forgot_password_server_config_button'),
                          icon: const Icon(Icons.settings_ethernet, color: AppColors.textTertiary, size: 18),
                          tooltip: 'Server Settings',
                          onPressed: () => ServerConfigDialog.show(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Recovery Card
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Logo Header
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const AlphaXLogo.badge(size: 22),
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
                                  const SizedBox(height: 16),

                                  // Title
                                  Text(
                                    'Password Recovery',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Primary Directive Message
                                  Text(
                                    'Forgot your password? Contact your gym admin to get a 6-digit reset code.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: _goldAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Step-by-Step Instructions Card
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.info_outline, color: _goldAccent, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              'HOW RECOVERY WORKS',
                                              style: GoogleFonts.poppins(
                                                color: _goldAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _buildInstructionStep(
                                          '1',
                                          'Contact the gym admin.',
                                        ),
                                        _buildInstructionStep(
                                          '2',
                                          'Get your 6-digit reset code.',
                                        ),
                                        _buildInstructionStep(
                                          '3',
                                          'Enter your registered email or Client ID, the code, and your new password.',
                                        ),
                                        _buildInstructionStep(
                                          '4',
                                          'Codes expire after 15 minutes and can be used only once.',
                                          isLast: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Gym Contact Details Card (Existing API)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _goldAccent.withOpacity(0.25)),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildContactRow(
                                          Icons.admin_panel_settings_outlined,
                                          'Desk',
                                          'Alpha X Front Desk & Administration',
                                        ),
                                        const SizedBox(height: 6),
                                        _buildContactRow(
                                          Icons.email_outlined,
                                          'Email',
                                          _gymContactInfo['adminEmail']?.toString() ?? AdminConfig.adminEmail,
                                        ),
                                        if (_gymContactInfo['deskHours'] != null) ...[
                                          const SizedBox(height: 6),
                                          _buildContactRow(
                                            Icons.schedule_outlined,
                                            'Hours',
                                            _gymContactInfo['deskHours'].toString(),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        _buildContactRow(
                                          Icons.verified_user_outlined,
                                          'Method',
                                          'In-Person or Direct Verification',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Primary Action: Enter 6-Digit Reset Code
                                  AlphaXActionButton.solid(
                                    key: const Key('enter_admin_code_button'),
                                    label: 'ENTER 6-DIGIT RESET CODE',
                                    onPressed: _navigateToResetPassword,
                                    height: 48,
                                    borderRadius: BorderRadius.circular(12),
                                    goldColor: _goldAccent,
                                  ),
                                  const SizedBox(height: 14),

                                  // Return to Login Link
                                  Center(
                                    child: TextButton(
                                      key: const Key('return_to_login_button'),
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: Text(
                                        'Return to Login',
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

  Widget _buildInstructionStep(String stepNumber, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _goldAccent.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: _goldAccent, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: GoogleFonts.poppins(
                color: _goldAccent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _goldAccent),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
