import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/network/network_exceptions.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

/// Modal dialog allowing athletes and administrators on physical devices (iPhone & Android)
/// to inspect, test, and dynamically configure the backend server API URL.
class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConstants.apiBaseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _testResult = 'Please enter a valid URL';
        _testSuccess = false;
      });
      return;
    }

    final normalized = ApiConfig.normalizeUrl(rawUrl);
    setState(() {
      _isTesting = true;
      _testResult = null;
      _urlController.text = normalized;
    });

    final stopwatch = Stopwatch()..start();
    try {
      // 1. Try health check on normalized API path: /api/v1/health
      Uri healthUri = Uri.parse('$normalized/health');
      http.Response res;
      try {
        res = await http.get(healthUri).timeout(const Duration(seconds: 5));
      } catch (_) {
        // 2. Fallback to origin root /health (e.g. http://192.168.1.5:5000/health)
        final uri = Uri.parse(normalized);
        final portPart = uri.hasPort ? ':${uri.port}' : '';
        final baseOrigin = '${uri.scheme}://${uri.host}$portPart';
        healthUri = Uri.parse('$baseOrigin/health');
        res = await http.get(healthUri).timeout(const Duration(seconds: 5));
      }
      stopwatch.stop();

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final service = decoded['data']?['service'] ?? 'Alpha X Gym Server';
        final env = decoded['data']?['environment'] ?? '';
        setState(() {
          _testSuccess = true;
          _testResult = 'Connected to $service [$env] (${stopwatch.elapsedMilliseconds}ms)';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'Server responded with HTTP ${res.statusCode} at $healthUri';
        });
      }
    } catch (e) {
      stopwatch.stop();
      final err = NetworkExceptions.handle(e, requestUrl: normalized);
      setState(() {
        _testSuccess = false;
        _testResult = err.userMessage;
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _saveAndApply() async {
    final cleanUrl = _urlController.text.trim();
    final normalized = cleanUrl.isNotEmpty ? ApiConfig.normalizeUrl(cleanUrl) : '';
    await AuthService().updateServerUrl(normalized);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            normalized.isNotEmpty
                ? 'Server configured: $normalized'
                : 'Server reset to default (${ApiConfig.baseUrl})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.surfaceElevated,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _applyPreset(String url) {
    setState(() {
      _urlController.text = url;
      _testResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primaryRed.withOpacity(0.4), width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings_ethernet, color: AppColors.primaryRed, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SERVER CONFIGURATION',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'iPhone, Android & Multi-Target Routing',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Backend API Base URL:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: ApiConfig.productionUrl,
                hintStyle: TextStyle(color: AppColors.textTertiary.withOpacity(0.6)),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Preset Buttons
            const Text(
              'Target Presets:',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetChip('Production Cloud (Recommended)', ApiConfig.productionUrl),
                _presetChip('Local Windows (LAN)', ApiConfig.physicalLanUrl),
                _presetChip('Android Emulator', ApiConfig.emulatorUrl),
                _presetChip('Localhost', ApiConfig.localhostUrl),
              ],
            ),
            const SizedBox(height: 14),

            // Physical Device Guidance Card
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_tethering, size: 14, color: AppColors.primaryRed),
                      SizedBox(width: 6),
                      Text(
                        'Physical Device Testing Guide',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Connect your phone and Windows PC to the SAME Wi-Fi.\n'
                    '• Put your Windows PC LAN IP (e.g. 192.168.1.5).\n'
                    '• Windows Firewall must allow inbound TCP port 5000.\n'
                    '• Note: 10.0.2.2 only works inside Android emulators.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Test Connection Button
            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                    )
                  : const Icon(Icons.wifi_find, size: 16, color: AppColors.textPrimary),
              label: Text(
                _isTesting ? 'Testing Connection...' : 'Test Connection',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _testSuccess ? Colors.green.withOpacity(0.12) : AppColors.primaryRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess ? Colors.green.withOpacity(0.5) : AppColors.primaryRed.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        _testSuccess ? Icons.check_circle : Icons.error_outline,
                        color: _testSuccess ? Colors.greenAccent : AppColors.primaryRed,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess ? Colors.greenAccent : AppColors.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
        ),
        TextButton(
          onPressed: () {
            _urlController.text = '';
            _saveAndApply();
          },
          child: const Text('Reset Default', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        ElevatedButton(
          onPressed: _saveAndApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Save & Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _presetChip(String label, String url) {
    final isSelected = _urlController.text.trim() == url.trim();
    return InkWell(
      onTap: () => _applyPreset(url),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed.withOpacity(0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryRed : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
