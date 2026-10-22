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
import 'client_workout_execution_screen.dart';

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
  @override
  void initState() {
    super.initState();
    widget.workoutRepository.addListener(_onRepoChange);
    widget.workoutRepository.fetchClientWorkouts();
    final clientId = AuthService().currentUserId;
    if (clientId.isNotEmpty) {
      widget.workoutRepository.restoreActiveSessionForClient(clientId);
    }
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
    final hasActive = widget.workoutRepository.hasActiveSavedSession;
    final activeSession = widget.workoutRepository.activeSession;
    final todaySession = widget.workoutRepository.getTodaySessionForClient(clientId)
                      ?? widget.workoutRepository.getRecommendedSessionForClient(clientId);
    final pendingWorkouts = widget.workoutRepository.getPendingWorkoutsForClient(clientId);
    final hasAssignedWorkouts = widget.workoutRepository.hasAssignedWorkoutsForClient(clientId);

    final isRestDay = todaySession == null && !hasActive && (hasAssignedWorkouts || pendingWorkouts.isNotEmpty);
    final hasNoWorkoutsAtAll = todaySession == null && pendingWorkouts.isEmpty && !hasActive && !hasAssignedWorkouts;

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
          // Section 0: Active Session Resume Card (if in progress)
          if (hasActive) ...[
            _buildActiveResumeBanner(activeSession, colors, isDark),
          ],

          // Section 1: Today's Workout OR Rest Day OR Empty State
          if (todaySession != null) ...[
            _sectionTitle("⭐ TODAY'S WORKOUT", colors),
            const SizedBox(height: 10),
            _buildRecommendedCard(todaySession, colors, isDark),
            const SizedBox(height: 24),
          ] else if (isRestDay) ...[
            // REST DAY STATE (Client has an assigned split, but today is a designated recovery day!)
            _buildRestDayState(colors, isDark),
            const SizedBox(height: 24),
          ] else if (hasNoWorkoutsAtAll) ...[
            // ZERO WORKOUTS ASSIGNED STATE (Never fallback to default/generic!)
            _buildNoWorkoutAssignedState(colors, isDark),
            const SizedBox(height: 24),
          ],

          // Section 2: Dedicated Pending Workouts Section
          if (pendingWorkouts.isNotEmpty) ...[
            _sectionTitle('⏳ PENDING WORKOUTS (${pendingWorkouts.length})', colors),
            const SizedBox(height: 8),
            Text(
              'Scheduled workouts not yet completed. Complete them separately without affecting today\'s scheduled workout.',
              style: GoogleFonts.poppins(color: colors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ...pendingWorkouts.map((session) => _buildPendingWorkoutCard(session, colors, isDark)),
            const SizedBox(height: 24),
          ],
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
              style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
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

  Widget _buildActiveResumeBanner(WorkoutSession active, ClientThemeColors colors, bool isDark) {
    final accentLime = isDark ? AppColors.primary : AppColors.lightPrimary;
    final totalSets = active.totalSets;
    final completedSets = active.totalCompletedSets;
    final percent = totalSets > 0 ? ((completedSets / totalSets) * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentLime, width: 2),
        boxShadow: [
          BoxShadow(
            color: accentLime.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentLime.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accentLime.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentLime,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'WORKOUT IN PROGRESS',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: accentLime,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: colors.textTertiary,
                tooltip: 'Discard workout',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final discard = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: colors.surfaceCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: Text(
                        'Discard Workout?',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                      content: Text(
                        'Your logged sets in this active workout will be discarded.',
                        style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Keep', style: GoogleFonts.poppins(color: colors.textSecondary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Discard', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (discard == true) {
                    await widget.workoutRepository.discardActiveSession();
                    if (mounted) setState(() {});
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            active.title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$percent% complete • $completedSets of $totalSets sets finished',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: totalSets > 0 ? (completedSets / totalSets).clamp(0.0, 1.0) : 0.0,
              minHeight: 6,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(accentLime),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentLime,
                foregroundColor: AppColors.onPrimary,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded, color: AppColors.onPrimary, size: 22),
              label: Text(
                'RESUME WORKOUT',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.0,
                  color: AppColors.onPrimary,
                ),
              ),
              onPressed: () {
                AlphaXHaptics.tap();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ClientWorkoutExecutionScreen(
                      workoutRepository: widget.workoutRepository,
                      session: active,
                      sessionId: active.id,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestDayState(ClientThemeColors colors, bool isDark) {
    final accentLime = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status pill badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: accentLime.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accentLime.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bedtime_rounded, size: 14, color: accentLime),
                  const SizedBox(width: 6),
                  Text(
                    'REST & RECOVERY DAY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: accentLime,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Active Recovery & Muscle Repair',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'No workout scheduled for today in your training split. Your muscles rebuild and adapt during rest periods.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Recovery Pillars Cards
            _buildRecoveryPillarRow(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF38BDF8),
              title: 'Hydration Target',
              subtitle: 'Aim for 3.5L of water to aid metabolic recovery',
              colors: colors,
            ),
            const SizedBox(height: 12),
            _buildRecoveryPillarRow(
              icon: Icons.nightlight_round,
              iconColor: const Color(0xFFA78BFA),
              title: 'Sleep & Adaptation',
              subtitle: 'Prioritize 8+ hours of quality sleep tonight',
              colors: colors,
            ),
            const SizedBox(height: 12),
            _buildRecoveryPillarRow(
              icon: Icons.directions_walk_rounded,
              iconColor: const Color(0xFF34D399),
              title: 'Light Movement',
              subtitle: 'Optional 20-30 min walk or gentle mobility work',
              colors: colors,
            ),
            const SizedBox(height: 26),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceElevated,
                  foregroundColor: colors.textPrimary,
                  shape: const StadiumBorder(),
                  side: BorderSide(color: colors.border),
                  elevation: 0,
                ),
                icon: Icon(Icons.history_rounded, size: 18, color: accentLime),
                label: Text(
                  'VIEW WORKOUT HISTORY',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: colors.textPrimary,
                  ),
                ),
                onPressed: () {
                  AlphaXHaptics.tap();
                  _openWorkoutHistory();
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: Icon(Icons.refresh_rounded, size: 16, color: colors.textSecondary),
              label: Text(
                'Check for Updates',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              onPressed: () async {
                AlphaXHaptics.selection();
                await widget.workoutRepository.fetchClientWorkouts(forceRefresh: true);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryPillarRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required ClientThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWorkoutAssignedState(ClientThemeColors colors, bool isDark) {
    final accentLime = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle, width: 2),
              ),
              child: Icon(
                Icons.fitness_center_outlined,
                size: 36,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No workout assigned',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Your trainer hasn't assigned a workout yet.\nOnce assigned, your prescribed routine will appear here automatically.",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentLime,
                  foregroundColor: AppColors.onPrimary,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.onPrimary),
                label: Text(
                  'CONTACT YOUR TRAINER',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: AppColors.onPrimary,
                  ),
                ),
                onPressed: () {
                  AlphaXHaptics.tap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Trainer notified! Your coach will assign your workout program shortly.',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: colors.surfaceCard,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: Icon(Icons.refresh_rounded, size: 16, color: colors.textSecondary),
              label: Text(
                'Check for Updates',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              onPressed: () async {
                AlphaXHaptics.selection();
                await widget.workoutRepository.fetchClientWorkouts(forceRefresh: true);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ClientThemeColors colors) {
    return Text(
      title,
      style: GoogleFonts.poppins(
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
                        style: GoogleFonts.poppins(
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
                    style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.targetMuscleGroup.toUpperCase(),
                  style: GoogleFonts.poppins(
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
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 18),

                // Start or Completed & Locked Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: session.isLocked
                        ? null
                        : [
                            BoxShadow(
                              color: accentLime.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: session.isLocked ? colors.surfaceElevated : accentLime,
                      foregroundColor: session.isLocked ? colors.textSecondary : AppColors.onPrimary, // #0A0B0D dark text on lime
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: () {
                      AlphaXHaptics.tap();
                      if (session.isLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Today\'s workout has been completed and locked. It will automatically unlock on your next scheduled day.',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: colors.surfaceCard,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        return;
                      }
                      _openSessionOverview(session);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          session.isLocked ? Icons.lock_rounded : Icons.play_arrow_rounded,
                          color: session.isLocked ? colors.textSecondary : AppColors.onPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.isLocked ? 'COMPLETED & LOCKED' : 'START WORKOUT',
                          style: GoogleFonts.poppins(
                            color: session.isLocked ? colors.textSecondary : AppColors.onPrimary,
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

  Widget _buildPendingWorkoutCard(WorkoutSession session, ClientThemeColors colors, bool isDark) {
    final totalSets = session.exercises.fold(0, (acc, ex) => acc + ex.sets.length);
    const pendingOrange = Color(0xFFF59E0B);
    final dateDisplay = session.scheduledDate != null
        ? 'Scheduled: ${session.scheduledDate}'
        : 'Missed Workout';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pendingOrange.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: pendingOrange.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendingOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: pendingOrange.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: pendingOrange),
                      const SizedBox(width: 5),
                      Text(
                        'PENDING',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: pendingOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateDisplay,
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                    style: GoogleFonts.poppins(
                      color: pendingOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              session.title,
              style: GoogleFonts.poppins(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.targetMuscleGroup.toUpperCase(),
              style: GoogleFonts.poppins(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _metaChip(Icons.fitness_center_rounded, '${session.exercises.length} Exercises', colors),
                _metaChip(Icons.repeat_rounded, '$totalSets Sets', colors),
                _metaChip(Icons.timer_outlined, '~${session.estimatedDurationMinutes} min', colors),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pendingOrange,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                label: Text(
                  'START PENDING WORKOUT',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: Colors.black,
                  ),
                ),
                onPressed: () {
                  AlphaXHaptics.tap();
                  _openSessionOverview(session);
                },
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
            style: GoogleFonts.poppins(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
