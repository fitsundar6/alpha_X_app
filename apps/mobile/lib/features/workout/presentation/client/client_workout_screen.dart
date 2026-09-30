import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'client_session_overview_screen.dart';
import 'client_workout_history_screen.dart';

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
    final clientId = AuthService().currentUserId;
    final recommended = widget.workoutRepository.getRecommendedSessionForClient(clientId);
    final available = widget.workoutRepository.getAuthorizedSessionsForClient(clientId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  AlphaXLogo.appBar(size: 24),
                  SizedBox(width: 8),
                  Text(
                    'WORKOUT',
                    style: TextStyle(
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
                  icon: const Icon(Icons.history, color: AppColors.primaryRed, size: 18),
                  label: const Text(
                    'History',
                    style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Recommended Session (if configured by Admin)
          if (recommended != null) ...[
            _sectionTitle('⭐ RECOMMENDED FOR YOU'),
            const SizedBox(height: 10),
            _buildRecommendedCard(recommended),
            const SizedBox(height: 24),
          ],

          // Section 2: Available Prescribed Sessions
          _sectionTitle('AVAILABLE PRESCRIBED SESSIONS (${available.length})'),
          const SizedBox(height: 4),
          const Text(
            'Prescribed workouts tailored to your training phase. Only active authorized sessions are displayed.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 12),

          if (available.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'No workout sessions currently assigned. Contact gym admin.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...available.map((session) => _buildAvailableSessionCard(session)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildRecommendedCard(WorkoutSession session) {
    final totalSets = session.exercises.fold(0, (acc, ex) => acc + ex.sets.length);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryRed, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Star Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: AppColors.gold, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'RECOMMENDED SESSION',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '~${session.estimatedDurationMinutes} minutes',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.targetMuscleGroup,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metaChip(Icons.fitness_center, '${session.exercises.length} Exercises'),
                    const SizedBox(width: 8),
                    _metaChip(Icons.repeat, '$totalSets Sets'),
                    const SizedBox(width: 8),
                    _metaChip(Icons.speed, session.difficulty),
                  ],
                ),
                if (session.description != null && session.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    session.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    onPressed: () => _openSessionOverview(session),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'START WORKOUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 15,
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

  Widget _buildAvailableSessionCard(WorkoutSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                session.difficulty,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              session.targetMuscleGroup,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${session.exercises.length} Exercises',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                Text(
                  '~${session.estimatedDurationMinutes} min',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                Text(
                  session.workoutType,
                  style: const TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceElevated,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _openSessionOverview(session),
          child: const Text('View & Start', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
