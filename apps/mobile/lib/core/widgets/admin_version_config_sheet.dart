import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/core/models/app_version_info.dart';
import 'package:alpha_x_gym/core/services/app_version_service.dart';

/// Admin Control Sheet to view, edit, and broadcast application release versions,
/// toggle mandatory force updates, and update release notes in real time.
class AdminVersionConfigSheet extends StatefulWidget {
  final AppVersionInfo? initialInfo;

  const AdminVersionConfigSheet({super.key, this.initialInfo});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AdminVersionConfigSheet(),
    );
  }

  @override
  State<AdminVersionConfigSheet> createState() => _AdminVersionConfigSheetState();
}

class _AdminVersionConfigSheetState extends State<AdminVersionConfigSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _latestVersionController;
  late final TextEditingController _minVersionController;
  late final TextEditingController _releaseNotesController;
  late final TextEditingController _downloadUrlController;
  late final TextEditingController _playStoreUrlController;
  late final TextEditingController _appStoreUrlController;

  bool _forceUpdate = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _latestVersionController = TextEditingController();
    _minVersionController = TextEditingController();
    _releaseNotesController = TextEditingController();
    _downloadUrlController = TextEditingController();
    _playStoreUrlController = TextEditingController();
    _appStoreUrlController = TextEditingController();

    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    final info = widget.initialInfo ?? await AppVersionService.instance.fetchVersionInfo();

    if (mounted) {
      if (info != null) {
        _latestVersionController.text = info.latestVersion;
        _minVersionController.text = info.minimumRequiredVersion;
        _forceUpdate = info.forceUpdate;
        _releaseNotesController.text = info.releaseNotes;
        _downloadUrlController.text = info.downloadUrl;
        _playStoreUrlController.text = info.playStoreUrl;
        _appStoreUrlController.text = info.appStoreUrl;
      } else {
        _latestVersionController.text = '1.0.1';
        _minVersionController.text = '1.0.0';
        _forceUpdate = false;
        _releaseNotesController.text =
            'Alpha X v1.0.1: Real-time workout assignment synchronization, instant diet plan updates, meal photo upload optimizations, and UI performance enhancements.';
        _downloadUrlController.text = 'https://alphaxgym.com/download';
        _playStoreUrlController.text =
            'https://play.google.com/store/apps/details?id=com.alphaxgym.app';
        _appStoreUrlController.text = 'https://apps.apple.com/app/id6400000000';
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _latestVersionController.dispose();
    _minVersionController.dispose();
    _releaseNotesController.dispose();
    _downloadUrlController.dispose();
    _playStoreUrlController.dispose();
    _appStoreUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final success = await AppVersionService.instance.publishVersionUpdate(
        latestVersion: _latestVersionController.text.trim(),
        minimumRequiredVersion: _minVersionController.text.trim(),
        forceUpdate: _forceUpdate,
        releaseNotes: _releaseNotesController.text.trim(),
        downloadUrl: _downloadUrlController.text.trim(),
        playStoreUrl: _playStoreUrlController.text.trim(),
        appStoreUrl: _appStoreUrlController.text.trim(),
      );

      if (mounted) {
        if (success) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Version configuration successfully published to backend!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage = 'Failed to publish version update. Ensure you have admin privileges.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving configuration: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
      decoration: const BoxDecoration(
        color: Color(0xFF11141C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF262C3D), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AlphaXColors.primaryGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AlphaXColors.primaryGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APP VERSION MANAGER',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Control in-app update prompts for Athletes and Admins',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1F2536), height: 1),

          // Body
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AlphaXColors.primaryGold),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFFFCA5A5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Versions Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _latestVersionController,
                                  label: 'LATEST VERSION',
                                  hint: '1.0.1',
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildTextField(
                                  controller: _minVersionController,
                                  label: 'MIN REQUIRED VERSION',
                                  hint: '1.0.0',
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Force Update Toggle Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _forceUpdate
                                  ? const Color(0xFFEF4444).withOpacity(0.08)
                                  : const Color(0xFF171B26),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _forceUpdate
                                    ? const Color(0xFFEF4444).withOpacity(0.5)
                                    : const Color(0xFF262C3D),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _forceUpdate
                                      ? Icons.warning_rounded
                                      : Icons.verified_user_rounded,
                                  color: _forceUpdate
                                      ? const Color(0xFFEF4444)
                                      : AlphaXColors.primaryGold,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MANDATORY FORCE UPDATE',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: _forceUpdate
                                              ? const Color(0xFFFCA5A5)
                                              : Colors.white,
                                        ),
                                      ),
                                      Text(
                                        _forceUpdate
                                            ? 'All users below latest version will be blocked from using the app until updated.'
                                            : 'Users receive an optional dismissible upgrade prompt.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _forceUpdate,
                                  activeColor: const Color(0xFFEF4444),
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _forceUpdate = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Release Notes
                          _buildTextField(
                            controller: _releaseNotesController,
                            label: 'RELEASE NOTES & HIGHLIGHTS',
                            hint: 'What changed in this update...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),

                          // Download URLs
                          _buildTextField(
                            controller: _playStoreUrlController,
                            label: 'GOOGLE PLAY STORE URL',
                            hint: 'https://play.google.com/store/apps/details?id=...',
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _appStoreUrlController,
                            label: 'APPLE APP STORE URL',
                            hint: 'https://apps.apple.com/app/id...',
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _downloadUrlController,
                            label: 'WEB / APK DIRECT DOWNLOAD URL',
                            hint: 'https://alphaxgym.com/download',
                          ),
                          const SizedBox(height: 24),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AlphaXColors.primaryGold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 6,
                              ),
                              onPressed: _isSaving ? null : _saveConfig,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.cloud_upload_rounded, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'PUBLISH TO ALL USERS',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.0,
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
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4B5563)),
            filled: true,
            fillColor: const Color(0xFF171B26),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF262C3D)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF262C3D)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AlphaXColors.primaryGold, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
