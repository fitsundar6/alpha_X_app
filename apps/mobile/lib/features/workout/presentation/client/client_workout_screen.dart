import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'client_session_overview_screen.dart';
import 'client_workout_history_screen.dart';

/// Athletic Premium Workouts Hub
/// Screen 3: Horizontal filter chips, workout cards (image + tags + lime Start).
class ClientWorkoutScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final bool showAppBar;

  const ClientWorkoutScreen({
    super.key,
    required this.workoutRepository,
    this.showAppBar = true,
  });

  @override
  State<ClientWorkoutScreen> createState() => _ClientWorkoutScreenState();
}

class _ClientWorkoutScreenState extends State<ClientWorkoutScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Strength',
    'Hypertrophy',
    'Conditioning',
    'Mobility',
    'Upper Body',
    'Lower Body',
  ];

  @override
  void initState() {
    super.initState();
    widget.workoutRepository.addListener(_onRepoChange);
    widget.workoutRepository.fetchClientWorkouts();
  }

  @override
  void dispose() {
    widget.workoutRepository.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  void _openSessionOverview(WorkoutSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ClientSessionOverviewScreen(
          session: session,
          workoutRepository: widget.workoutRepository,
        ),
      ),
    );
  }

  void _openWorkoutHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ClientWorkoutHistoryScreen(
          workoutRepository: widget.workoutRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final isDark = colors.isDark;
    final clientId = AuthService().currentUserId;
    final recommended = widget.workoutRepository.getRecommendedSessionForClient(clientId);
    final available = widget.workoutRepository.getAuthorizedSessionsForClient(clientId);

    final filteredSessions = _selectedCategory == 'All'
        ? available
        : available.where((s) {
            final cat = _selectedCategory.toLowerCase();
            return s.workoutType.toLowerCase().contains(cat) ||
                s.targetMuscleGroup.toLowerCase().contains(cat) ||
                s.title.toLowerCase().contains(cat);
          }).toList();

    final content = RefreshIndicator(
      color: isDark ? AppColors.primary : AppColors.lightPrimary,
      backgroundColor: colors.surfaceCard,
      onRefresh: () async {
        await widget.workoutRepository.fetchClientWorkouts(forceRefresh: true);
      },
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
          // Section 1: Recommended Session Hero Card
          if (recommended != null) ...[
            _sectionTitle('⭐ RECOMMENDED FOR YOU', colors),
            const SizedBox(height: 10),
            _buildRecommendedCard(recommended, colors, isDark),
            const SizedBox(height: 24),
          ],

          // Section 2: Horizontal Filter Chips
          _sectionTitle('PRESCRIBED PROGRAMS', colors),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AlphaXPressable(
                    onTap: () {
                      AlphaXHaptics.selection();
                      setState(() => _selectedCategory = cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppColors.primary : AppColors.lightPrimary)
                            : colors.surfaceCard,
                        borderRadius: BorderRadius.circular(999), // Pill
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? AppColors.primary : AppColors.lightPrimary)
                              : colors.border,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (isDark ? AppColors.primary : AppColors.lightPrimary).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.onPrimary // Dark text on lime
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Prescribed workouts tailored to your training phase. Only active authorized sessions are displayed.',
            style: GoogleFonts.plusJakartaSans(color: colors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 14),

          if (filteredSessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Text(
                  available.isEmpty
                      ? 'No workout sessions currently assigned. Contact gym admin.'
                      : 'No workouts matching "$_selectedCategory". Tap "All" to view all assigned sessions.',
                  style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...filteredSessions.map((session) => _buildWorkoutCard(session, colors, isDark)),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AlphaXLogo.appBar(size: 24),
            const SizedBox(width: 8),
            Text(
              'WORKOUT',
              style: GoogleFonts.sora(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openWorkoutHistory,
            icon: Icon(Icons.history, color: isDark ? AppColors.primary : AppColors.lightPrimary, size: 18),
            label: Text(
              'History',
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? AppColors.primary : AppColors.lightPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _sectionTitle(String title, ClientThemeColors colors) {
    return Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: colors.textSecondary,
      ),
    );
  }

  Widget _buildRecommendedCard(WorkoutSession session, ClientThemeColors colors, bool isDark) {
    final totalSets = session.exercises.fold(0, (acc, ex) => acc + ex.sets.length);
    final accentLime = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentLime, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: accentLime.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image & Star Header
          Stack(
            children: [
              Image.network(
                'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&q=80',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 80, color: colors.surfaceElevated),
              ),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      (isDark ? AppColors.surfaceCard : Colors.white).withOpacity(0.95),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.gold.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'RECOMMENDED',
                        style: GoogleFonts.sora(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '~${session.estimatedDurationMinutes} MIN',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.targetMuscleGroup.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: accentLime,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _metaChip(Icons.fitness_center_rounded, '${session.exercises.length} Exercises', colors),
                    _metaChip(Icons.repeat_rounded, '$totalSets Sets', colors),
                    _metaChip(Icons.speed_rounded, session.difficulty, colors),
                  ],
                ),
                if (session.description != null && session.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    session.description!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 18),

                // Lime Pill Start Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: accentLime.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentLime,
                      foregroundColor: AppColors.onPrimary, // #0A0B0D dark text on lime
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: () {
                      AlphaXHaptics.tap();
                      _openSessionOverview(session);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: AppColors.onPrimary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'START WORKOUT',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

  Widget _buildWorkoutCard(WorkoutSession session, ClientThemeColors colors, bool isDark) {
    final accentLime = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: GoogleFonts.sora(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.targetMuscleGroup,
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    session.difficulty.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: accentLime,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${session.exercises.length} Exercises',
                  style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12),
                ),
                Text(' • ', style: TextStyle(color: colors.textTertiary)),
                Text(
                  '~${session.estimatedDurationMinutes} min',
                  style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12),
                ),
                Text(' • ', style: TextStyle(color: colors.textTertiary)),
                Text(
                  session.workoutType,
                  style: GoogleFonts.plusJakartaSans(color: accentLime, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: accentLime.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentLime,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    AlphaXHaptics.tap();
                    _openSessionOverview(session);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: AppColors.onPrimary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Start',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.onPrimary,
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
    );
  }

  Widget _metaChip(IconData icon, String label, ClientThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
