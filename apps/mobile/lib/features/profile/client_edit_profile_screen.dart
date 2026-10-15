import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

/// Allows clients to edit their own permitted profile fields.
/// Forbidden fields: clientId, role, membership status, admin permissions.
class ClientEditProfileScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;

  const ClientEditProfileScreen({super.key, required this.workoutRepository});

  @override
  State<ClientEditProfileScreen> createState() => _ClientEditProfileScreenState();
}

class _ClientEditProfileScreenState extends State<ClientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _errorMessage;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  // Dropdown selections
  String? _gender;
  String? _fitnessLevel;
  String? _primaryGoal;
  String? _activityLevel;
  String? _trainingTimePref;

  // Option lists
  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _fitnessLevels = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ELITE'];
  static const _goals = [
    'Weight Loss', 'Muscle Gain', 'General Fitness', 'Endurance',
    'Strength', 'Flexibility', 'Sport Performance', 'Rehabilitation',
  ];
  static const _activityLevels = ['SEDENTARY', 'LIGHT', 'MODERATE', 'ACTIVE', 'VERY_ACTIVE'];
  static const _timingOptions = ['Morning', 'Afternoon', 'Evening', 'Flexible'];

  @override
  void initState() {
    super.initState();
    _prefillFromAuth();
  }

  void _prefillFromAuth() {
    final auth = AuthService();
    final profile = auth.clientProfile;

    _nameCtrl.text = auth.currentUserName;
    _phoneCtrl.text = auth.currentUserPhone ?? profile['phone']?.toString() ?? '';
    _photoUrlCtrl.text = auth.currentUserPhotoUrl ?? profile['photoUrl']?.toString() ?? '';
    _ageCtrl.text = profile['age']?.toString() ?? '';
    _weightCtrl.text = profile['weightKg']?.toString() ?? '';
    _heightCtrl.text = profile['heightCm']?.toString() ?? '';

    final genderVal = profile['gender']?.toString() ?? '';
    _gender = _genders.contains(genderVal) ? genderVal : null;

    final fitVal = (profile['fitnessLevel']?.toString() ?? '').toUpperCase();
    _fitnessLevel = _fitnessLevels.contains(fitVal) ? fitVal : null;

    final goalVal = profile['primaryGoal']?.toString() ?? '';
    _primaryGoal = _goals.contains(goalVal) ? goalVal : null;

    final actVal = (profile['activityLevel']?.toString() ?? '').toUpperCase();
    _activityLevel = _activityLevels.contains(actVal) ? actVal : null;

    final timePref = profile['trainingTimePref']?.toString() ?? '';
    _trainingTimePref = _timingOptions.contains(timePref) ? timePref : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      final auth = AuthService();
      final token = await auth.getValidToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 1. Update name if changed
      final newName = _nameCtrl.text.trim();
      if (newName.isNotEmpty && newName != auth.currentUserName) {
        final nameOk = await widget.workoutRepository.updateOwnName(newName);
        if (!nameOk && mounted) {
          setState(() { _errorMessage = 'Could not update name. Please try again.'; _isSaving = false; });
          return;
        }
      }

      // 2. Update profile fields
      final payload = <String, dynamic>{};
      final phone = _phoneCtrl.text.trim();
      if (phone.isNotEmpty) payload['phone'] = phone;
      final photoUrl = _photoUrlCtrl.text.trim();
      if (photoUrl.isNotEmpty) payload['photoUrl'] = photoUrl;
      final age = _ageCtrl.text.trim();
      if (age.isNotEmpty) payload['age'] = int.parse(age);
      final weight = _weightCtrl.text.trim();
      if (weight.isNotEmpty) payload['weightKg'] = double.parse(weight);
      final height = _heightCtrl.text.trim();
      if (height.isNotEmpty) payload['heightCm'] = double.parse(height);
      if (_gender != null) payload['gender'] = _gender;
      if (_fitnessLevel != null) payload['fitnessLevel'] = _fitnessLevel;
      if (_primaryGoal != null) payload['primaryGoal'] = _primaryGoal;
      if (_activityLevel != null) payload['activityLevel'] = _activityLevel;
      if (_trainingTimePref != null) payload['trainingTimePref'] = _trainingTimePref;

      if (payload.isNotEmpty) {
        final resp = await http.put(
          Uri.parse('${AppConstants.apiBaseUrl}/client/me/profile'),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 12));

        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final profileMap = body['data']?['profile'];
          if (profileMap is Map) {
            auth.updateLocalProfile(Map<String, dynamic>.from(profileMap));
          }
        } else {
          String msg = 'Save failed (${resp.statusCode}). Please retry.';
          try {
            final err = jsonDecode(resp.body);
            if (err['error']?['message'] != null) msg = err['error']['message'].toString();
          } catch (_) {}
          setState(() { _errorMessage = msg; _isSaving = false; });
          return;
        }
      }

      setState(() { _isSaving = false; });
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Color(0xFF22C55E)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() { _errorMessage = 'Something went wrong. Please try again.'; _isSaving = false; });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _photoUrlCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final photo = _photoUrlCtrl.text.trim();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          'EDIT MY PROFILE',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: colors.primaryRed),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),

            _sectionHeader('PERSONAL INFO & AVATAR', Icons.person_outline, colors),
            _card(colors, [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: colors.primaryRed,
                      backgroundImage: photo.isNotEmpty && photo.startsWith('http')
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty || !photo.startsWith('http')
                          ? Text(
                              _nameCtrl.text.trim().isNotEmpty
                                  ? _nameCtrl.text.trim().substring(0, 1).toUpperCase()
                                  : 'A',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Live Avatar Preview',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _photoUrlCtrl,
                label: 'Profile Photo URL',
                icon: Icons.image_outlined,
                colors: colors,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.badge_outlined,
                colors: colors,
                onChanged: (_) => setState(() {}),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Name must be at least 2 characters' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                colors: colors,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _buildDropdown(
                label: 'Gender',
                icon: Icons.wc_outlined,
                value: _gender,
                items: _genders,
                colors: colors,
                onChanged: (v) => setState(() => _gender = v),
              ),
            ]),
            const SizedBox(height: 16),

            _sectionHeader('PHYSICAL STATS', Icons.monitor_weight_outlined, colors),
            _card(colors, [
              Row(children: [
                Expanded(child: _buildField(
                  controller: _ageCtrl, label: 'Age (years)',
                  icon: Icons.cake_outlined, colors: colors,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 10 || n > 120) return 'Invalid age';
                    return null;
                  })),
                const SizedBox(width: 12),
                Expanded(child: _buildField(
                  controller: _weightCtrl, label: 'Weight (kg)',
                  icon: Icons.fitness_center_outlined, colors: colors,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 20 || n > 350) return 'Invalid weight';
                    return null;
                  })),
              ]),
              const SizedBox(height: 14),
              _buildField(controller: _heightCtrl, label: 'Height (cm)',
                icon: Icons.height_outlined, colors: colors,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim());
                  if (n == null || n < 50 || n > 280) return 'Invalid height';
                  return null;
                }),
            ]),
            const SizedBox(height: 16),

            _sectionHeader('FITNESS PROFILE', Icons.emoji_events_outlined, colors),
            _card(colors, [
              _buildDropdown(label: 'Fitness Level', icon: Icons.bar_chart_rounded,
                value: _fitnessLevel, items: _fitnessLevels, colors: colors,
                onChanged: (v) => setState(() => _fitnessLevel = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Primary Goal', icon: Icons.flag_outlined,
                value: _primaryGoal, items: _goals, colors: colors,
                onChanged: (v) => setState(() => _primaryGoal = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Activity Level', icon: Icons.directions_run_outlined,
                value: _activityLevel, items: _activityLevels, colors: colors,
                onChanged: (v) => setState(() => _activityLevel = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Preferred Training Time',
                icon: Icons.access_time_outlined, value: _trainingTimePref,
                items: _timingOptions, colors: colors,
                onChanged: (v) => setState(() => _trainingTimePref = v)),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  _isSaving ? 'SAVING...' : 'SAVE PROFILE',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, ClientThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: colors.primaryRed),
        const SizedBox(width: 7),
        Text(title, style: TextStyle(
          color: colors.textSecondary, fontSize: 11,
          fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      ]),
    );
  }

  Widget _card(ClientThemeColors colors, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: colors.surfaceCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ClientThemeColors colors,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: colors.textSecondary),
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primaryRed, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ClientThemeColors colors,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: colors.surfaceCard,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: colors.textSecondary),
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primaryRed, width: 1.5)),
      ),
      items: items.map((s) => DropdownMenuItem(
        value: s,
        child: Text(s, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

