import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/core/models/app_version_info.dart';
import 'package:alpha_x_gym/core/services/app_version_service.dart';

/// Ultra-premium Alpha X in-app update prompt dialog.
/// Supports both mandatory/blocking updates and optional/recommended updates.
class AppUpdateDialog extends StatelessWidget {
  final AppVersionInfo info;
  final String currentVersion;
  final bool isForced;
  final VoidCallback? onDismiss;

  const AppUpdateDialog({
    super.key,
    required this.info,
    required this.currentVersion,
    this.isForced = false,
    this.onDismiss,
  });

  /// Displays the update dialog.
  /// When [isForced] is true, the dialog is completely non-dismissible.
  static Future<void> show(
    BuildContext context, {
    required AppVersionInfo info,
    required String currentVersion,
    bool isForced = false,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isForced,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => AppUpdateDialog(
        info: info,
        currentVersion: currentVersion,
        isForced: isForced,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDownloadUrl = info.resolveDownloadUrl();

    final dialogContent = Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF11141C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isForced
                ? const Color(0xFFEF4444).withOpacity(0.4)
                : AlphaXColors.primaryGold.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isForced
                  ? const Color(0xFFEF4444).withOpacity(0.2)
                  : AlphaXColors.primaryGold.withOpacity(0.18),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top glowing accent line
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: isForced
                      ? const LinearGradient(
                          colors: [Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFFB91C1C)],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFFB8860B),
                            AlphaXColors.primaryGold,
                            Color(0xFFFFDF73),
                            AlphaXColors.primaryGold,
                          ],
                        ),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Badge Icon
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isForced
                            ? const Color(0xFFEF4444).withOpacity(0.12)
                            : AlphaXColors.primaryGold.withOpacity(0.12),
                        border: Border.all(
                          color: isForced
                              ? const Color(0xFFEF4444).withOpacity(0.4)
                              : AlphaXColors.primaryGold.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isForced
                              ? Icons.security_update_warning_rounded
                              : Icons.upgrade_rounded,
                          size: 36,
                          color: isForced
                              ? const Color(0xFFF87171)
                              : AlphaXColors.primaryGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    Text(
                      isForced ? 'UPDATE REQUIRED' : 'UPDATE AVAILABLE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      isForced
                          ? 'A critical update is required to continue training and synchronizing with Alpha X Gym.'
                          : 'A new version of Alpha X Gym is ready with performance upgrades and enhancements.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Version comparison banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171B26),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'CURRENT',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'v$currentVersion',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isForced
                                  ? const Color(0xFFEF4444).withOpacity(0.15)
                                  : AlphaXColors.primaryGold.withOpacity(0.15),
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: isForced
                                  ? const Color(0xFFEF4444)
                                  : AlphaXColors.primaryGold,
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                'LATEST',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: isForced
                                      ? const Color(0xFFEF4444)
                                      : AlphaXColors.primaryGold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'v${info.latestVersion}',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isForced
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFFFDF73),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (info.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "WHAT'S NEW",
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 120),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            info.releaseNotes,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFFD1D5DB),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Primary Action: UPDATE NOW
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isForced
                              ? const Color(0xFFDC2626)
                              : AlphaXColors.primaryGold,
                          foregroundColor: isForced ? Colors.white : Colors.black,
                          elevation: 8,
                          shadowColor: isForced
                              ? const Color(0xFFDC2626).withOpacity(0.5)
                              : AlphaXColors.primaryGold.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await AppVersionService.instance.launchUpdate(effectiveDownloadUrl);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'UPDATE NOW',
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Optional Later Button (Dismissible only when update is not forced)
                    if (!isForced) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9CA3AF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            AppVersionService.instance.dismissUpdate(info.latestVersion);
                            if (Navigator.of(context, rootNavigator: true).canPop()) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }
                            onDismiss?.call();
                          },
                          child: Text(
                            'LATER',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );

    // If update is mandatory, wrap with non-poppable PopScope
    if (isForced) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            HapticFeedback.heavyImpact();
          }
        },
        child: dialogContent,
      );
    }

    return dialogContent;
  }
}

/// Compact dashboard banner for notifying users about optional updates without blocking workflow
class AppUpdateBanner extends StatelessWidget {
  final AppVersionInfo info;
  final String currentVersion;
  final VoidCallback onDismiss;

  const AppUpdateBanner({
    super.key,
    required this.info,
    required this.currentVersion,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDownloadUrl = info.resolveDownloadUrl();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F2432),
            const Color(0xFF141822),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AlphaXColors.primaryGold.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AlphaXColors.primaryGold.withOpacity(0.15),
            ),
            child: const Icon(
              Icons.upgrade_rounded,
              color: AlphaXColors.primaryGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'NEW VERSION AVAILABLE',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AlphaXColors.primaryGold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AlphaXColors.primaryGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v${info.latestVersion}',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to upgrade for latest fixes and performance.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AlphaXColors.primaryGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await AppVersionService.instance.launchUpdate(effectiveDownloadUrl);
            },
            child: Text(
              'UPDATE',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
