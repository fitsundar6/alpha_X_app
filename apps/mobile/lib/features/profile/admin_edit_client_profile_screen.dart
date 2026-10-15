import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

/// Admin screen to edit a specific client's permitted profile fields.
/// Protected fields (clientId, role, membership status) are hidden and never editable.
class AdminEditClientProfileScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  final WorkoutRepository workoutRepository;

  const AdminEditClientProfileScreen({
    super.key,
    required this.client,
    required this.workoutRepository,
  });

  @override
  State<AdminEditClientProfileScreen> createState() => _AdminEditClientProfileScreenState();
}

class _AdminEditClientProfileScreenState extends State<AdminEditClientProfileScreen> {
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
  final _injuryDescCtrl = TextEditingController();
  final _surgeryDetailsCtrl = TextEditingController();
  final _sleepHoursCtrl = TextEditingController();

  // Dropdowns
  String? _gender;
  String? _fitnessLevel;
  String? _primaryGoal;
  String? _secondaryGoal;
  String? _trainingExperience;
  String? _activityLevel;
  String? _trainingTimePref;
  bool _hasCurrentInjury = false;
  bool _hasPreviousSurgery = false;
  int _trainingDaysPerWeek = 3;

  // Option lists
  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _fitnessLevels = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ELITE'];
  static const _goals = [
    'Weight Loss', 'Muscle Gain', 'General Fitness', 'Endurance',
    'Strength', 'Flexibility', 'Sport Performance', 'Rehabilitation',
  ];
  static const _experienceLevels = ['None', '< 1 year', '1-2 years', '3-5 years', '5+ years'];
  static const _activityLevels = ['SEDENTARY', 'LIGHT', 'MODERATE', 'ACTIVE', 'VERY_ACTIVE'];
  static const _timingOptions = ['Morning', 'Afternoon', 'Evening', 'Flexible'];

  String get _clientId =>
      widget.client['id']?.toString() ?? widget.client['clientId']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _prefillFromClient();
  }

  void _prefillFromClient() {
    final c = widget.client;
    final profile = c['profile'] is Map ? c['profile'] as Map : c;

    _nameCtrl.text = c['name']?.toString() ?? '';
    _phoneCtrl.text = c['phone']?.toString() ?? profile['phone']?.toString() ?? '';
    _photoUrlCtrl.text = (c['photoUrl'] ?? profile['photoUrl'])?.toString() ?? '';
    _ageCtrl.text = (c['age'] ?? profile['age'])?.toString() ?? '';
    _weightCtrl.text = (c['weightKg'] ?? profile['weightKg'])?.toString() ?? '';
    _heightCtrl.text = (c['heightCm'] ?? profile['heightCm'])?.toString() ?? '';
    _injuryDescCtrl.text = (c['injuryDescription'] ?? c['injuryDetails'] ?? profile['injuryDescription'])?.toString() ?? '';
    _surgeryDetailsCtrl.text = (c['surgeryDetails'] ?? profile['surgeryDetails'])?.toString() ?? '';
    _sleepHoursCtrl.text = (c['sleepHours'] ?? profile['sleepHours'])?.toString() ?? '';

    final genderVal = (c['gender'] ?? profile['gender'])?.toString() ?? '';
    _gender = _genders.contains(genderVal) ? genderVal : null;

    final fitVal = ((c['fitnessLevel'] ?? profile['fitnessLevel'])?.toString() ?? '').toUpperCase();
    _fitnessLevel = _fitnessLevels.contains(fitVal) ? fitVal : null;

    final goalVal = (c['primaryGoal'] ?? profile['primaryGoal'])?.toString() ?? '';
    _primaryGoal = _goals.contains(goalVal) ? goalVal : null;

    final secGoal = (c['secondaryGoal'] ?? profile['secondaryGoal'])?.toString() ?? '';
    _secondaryGoal = _goals.contains(secGoal) ? secGoal : null;

    final expVal = (c['trainingExperience'] ?? profile['trainingExperience'])?.toString() ?? '';
    _trainingExperience = _experienceLevels.contains(expVal) ? expVal : null;

    final actVal = ((c['activityLevel'] ?? profile['activityLevel'])?.toString() ?? '').toUpperCase();
    _activityLevel = _activityLevels.contains(actVal) ? actVal : null;

    final timePref = (c['trainingTimePref'] ?? profile['trainingTimePref'])?.toString() ?? '';
    _trainingTimePref = _timingOptions.contains(timePref) ? timePref : null;

    _hasCurrentInjury = c['hasCurrentInjury'] == true || profile['hasCurrentInjury'] == true;
    _hasPreviousSurgery = c['hasPreviousSurgery'] == true || profile['hasPreviousSurgery'] == true;

    final daysRaw = c['trainingDaysPerWeek'] ?? profile['trainingDaysPerWeek'];
    _trainingDaysPerWeek = int.tryParse(daysRaw?.toString() ?? '') ?? 3;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      final payload = <String, dynamic>{};

      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) payload['name'] = name;

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
      if (_secondaryGoal != null) payload['secondaryGoal'] = _secondaryGoal;
      if (_trainingExperience != null) payload['trainingExperience'] = _trainingExperience;
      if (_activityLevel != null) payload['activityLevel'] = _activityLevel;
      if (_trainingTimePref != null) payload['trainingTimePref'] = _trainingTimePref;
      payload['trainingDaysPerWeek'] = _trainingDaysPerWeek;
      payload['hasCurrentInjury'] = _hasCurrentInjury;
      payload['hasPreviousSurgery'] = _hasPreviousSurgery;

      final injDesc = _injuryDescCtrl.text.trim();
      if (injDesc.isNotEmpty) payload['injuryDescription'] = injDesc;

      final surgDetail = _surgeryDetailsCtrl.text.trim();
      if (surgDetail.isNotEmpty) payload['surgeryDetails'] = surgDetail;

      final sleep = _sleepHoursCtrl.text.trim();
      if (sleep.isNotEmpty) payload['sleepHours'] = sleep;

      final success = await widget.workoutRepository.updateClientProfile(_clientId, payload);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Failed to update profile. Please check your connection and try again.';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSaving = false;
      });
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
    _injuryDescCtrl.dispose();
    _surgeryDetailsCtrl.dispose();
    _sleepHoursCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final clientName = widget.client['name']?.toString() ?? 'Client';
    final clientIdDisplay = widget.client['clientId']?.toString() ?? '';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EDIT PROFILE',
              style: GoogleFonts.poppins(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '$clientName · $clientIdDisplay',
              style: GoogleFonts.poppins(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18, color: AppColors.primaryRed),
              label: const Text('SAVE', style: TextStyle(color: AppColors.primaryRed,
                fontWeight: FontWeight.w900, fontSize: 13)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Protected fields info banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Client ID, email, role, and membership status are protected and cannot be changed here.',
                  style: GoogleFonts.poppins(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600),
                )),
              ]),
            ),

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

            // Personal info & Avatar
            _sectionHeader('PERSONAL INFO & AVATAR', Icons.person_outline, colors),
            _card(colors, [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: colors.primary,
                      backgroundImage: _photoUrlCtrl.text.trim().isNotEmpty && _photoUrlCtrl.text.trim().startsWith('http')
                          ? NetworkImage(_photoUrlCtrl.text.trim())
                          : null,
                      child: (_photoUrlCtrl.text.trim().isEmpty || !_photoUrlCtrl.text.trim().startsWith('http'))
                          ? Text(
                              _nameCtrl.text.trim().isNotEmpty
                                  ? _nameCtrl.text.trim().substring(0, 1).toUpperCase()
                                  : 'C',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Client Avatar Preview',
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

            // Physical stats
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

            // Fitness profile
            _sectionHeader('TRAINING GOALS & EXPERIENCE', Icons.emoji_events_outlined, colors),
            _card(colors, [
              _buildDropdown(label: 'Fitness Level', icon: Icons.bar_chart_rounded,
                value: _fitnessLevel, items: _fitnessLevels, colors: colors,
                onChanged: (v) => setState(() => _fitnessLevel = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Primary Goal', icon: Icons.flag_outlined,
                value: _primaryGoal, items: _goals, colors: colors,
                onChanged: (v) => setState(() => _primaryGoal = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Secondary Goal', icon: Icons.flag_outlined,
                value: _secondaryGoal, items: _goals, colors: colors,
                onChanged: (v) => setState(() => _secondaryGoal = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Training Experience', icon: Icons.timeline_outlined,
                value: _trainingExperience, items: _experienceLevels, colors: colors,
                onChanged: (v) => setState(() => _trainingExperience = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Activity Level', icon: Icons.directions_run_outlined,
                value: _activityLevel, items: _activityLevels, colors: colors,
                onChanged: (v) => setState(() => _activityLevel = v)),
              const SizedBox(height: 14),
              _buildDropdown(label: 'Preferred Training Time',
                icon: Icons.access_time_outlined, value: _trainingTimePref,
                items: _timingOptions, colors: colors,
                onChanged: (v) => setState(() => _trainingTimePref = v)),
              const SizedBox(height: 16),
              // Training days slider
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: colors.textSecondary),
                const SizedBox(width: 8),
                Text('Training Days / Week: ', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                Text('$_trainingDaysPerWeek', style: TextStyle(
                  color: colors.primaryRed, fontWeight: FontWeight.w900, fontSize: 15)),
              ]),
              Slider(
                value: _trainingDaysPerWeek.toDouble(),
                min: 1, max: 7, divisions: 6,
                activeColor: colors.primaryRed,
                inactiveColor: colors.border,
                label: '$_trainingDaysPerWeek days',
                onChanged: (v) => setState(() => _trainingDaysPerWeek = v.round()),
              ),
            ]),
            const SizedBox(height: 16),

            // Health info
            _sectionHeader('HEALTH & INJURY SAFETY', Icons.health_and_safety_outlined, colors),
            _card(colors, [
              _buildSwitch(
                label: 'Has Current Injury / Pain',
                value: _hasCurrentInjury,
                colors: colors,
                onChanged: (v) => setState(() => _hasCurrentInjury = v),
              ),
              if (_hasCurrentInjury) ...[
                const SizedBox(height: 12),
                _buildField(controller: _injuryDescCtrl, label: 'Injury Description',
                  icon: Icons.medical_information_outlined, colors: colors, maxLines: 3),
              ],
              const SizedBox(height: 12),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 12),
              _buildSwitch(
                label: 'Has Previous Surgery',
                value: _hasPreviousSurgery,
                colors: colors,
                onChanged: (v) => setState(() => _hasPreviousSurgery = v),
              ),
              if (_hasPreviousSurgery) ...[
                const SizedBox(height: 12),
                _buildField(controller: _surgeryDetailsCtrl, label: 'Surgery Details',
                  icon: Icons.content_cut_outlined, colors: colors, maxLines: 3),
              ],
              const SizedBox(height: 14),
              _buildField(controller: _sleepHoursCtrl, label: 'Sleep Hours (e.g. 7–8 hours)',
                icon: Icons.bedtime_outlined, colors: colors),
            ]),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
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
                  _isSaving ? 'SAVING...' : 'SAVE CLIENT PROFILE',
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
        Icon(icon, size: 16, color: AppColors.primaryRed),
        const SizedBox(width: 7),
        Text(title, style: GoogleFonts.poppins(
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
    int maxLines = 1,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
        prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: colors.textSecondary) : null,
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
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
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
      ),
      items: items.map((s) => DropdownMenuItem(
        value: s,
        child: Text(s, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSwitch({
    required String label,
    required bool value,
    required ClientThemeColors colors,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(
          color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryRed,
        ),
      ],
    );
  }
}

