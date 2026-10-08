import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'exercise_media.dart';
import 'exercise_instructions.dart';
import 'trainer_note_card.dart';

/// Premium Exercise Detail modal sheet matching the reference screenshots.
/// Features top header with close button, muscle illustration/media preview,
/// and four tabs: Guide | History | Records | Charts.
class ClientExerciseDetailSheet extends StatefulWidget {
  final WorkoutExercise workoutExercise;
  final Exercise? catalogExercise;
  final WorkoutRepository workoutRepository;
  final String? clientId;
  final String actionButtonLabel;
  final VoidCallback? onPrimaryAction;
  final int initialTabIndex;

  const ClientExerciseDetailSheet({
    super.key,
    required this.workoutExercise,
    this.catalogExercise,
    required this.workoutRepository,
    this.clientId,
    this.actionButtonLabel = 'START SET',
    this.onPrimaryAction,
    this.initialTabIndex = 1, // Defaults to History tab as in reference screenshot
  });

  static void show(
    BuildContext context, {
    required WorkoutExercise workoutExercise,
    Exercise? catalogExercise,
    required WorkoutRepository workoutRepository,
    String? clientId,
    String actionButtonLabel = 'START SET',
    VoidCallback? onPrimaryAction,
    int initialTabIndex = 1,
  }) {
    final resolvedCatalog = catalogExercise ??
        ExerciseRepository().getExerciseById(workoutExercise.exerciseId);
    final colors = ClientThemeColors.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.50,
        expand: false,
        builder: (_, scrollController) => ClientExerciseDetailSheet(
          workoutExercise: workoutExercise,
          catalogExercise: resolvedCatalog,
          workoutRepository: workoutRepository,
          clientId: clientId,
          actionButtonLabel: actionButtonLabel,
          onPrimaryAction: onPrimaryAction,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  @override
  State<ClientExerciseDetailSheet> createState() => _ClientExerciseDetailSheetState();
}

class _ClientExerciseDetailSheetState extends State<ClientExerciseDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[(date.weekday - 1) % 7];
    final month = months[(date.month - 1) % 12];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final isDark = colors.isDark;
    final effectiveClientId = widget.clientId ?? AuthService().currentUserId;

    final history = widget.workoutRepository.getClientExerciseHistory(
      clientId: effectiveClientId,
      exerciseId: widget.workoutExercise.exerciseId,
    );

    final resolvedCatalog = widget.catalogExercise ??
        ExerciseRepository().getExerciseById(widget.workoutExercise.exerciseId);

    final primaryMuscle = widget.workoutExercise.primaryMusclesDisplay.isNotEmpty
        ? widget.workoutExercise.primaryMusclesDisplay
        : (resolvedCatalog?.primaryMusclesDisplay ?? 'Primary Target');

    final secondaryMuscle = widget.workoutExercise.secondaryMusclesDisplay.isNotEmpty
        ? widget.workoutExercise.secondaryMusclesDisplay
        : (resolvedCatalog?.secondaryMusclesDisplay ?? '');

    final targetReps = widget.workoutExercise.sets.firstOrNull?.targetRepsDisplay ?? '8–12 reps';
    final targetRpe = widget.workoutExercise.sets.firstOrNull?.targetRpe ?? 8.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Close '✕' button and Exercise Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 24),
                  color: colors.textPrimary,
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.workoutExercise.exerciseName,
                    style: GoogleFonts.poppins(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Top Muscle Illustration / Exercise Media preview
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161616) : const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Center(
                  child: ExerciseMedia(
                    exerciseId: widget.workoutExercise.exerciseId,
                    gifUrl: resolvedCatalog?.gifDemonstrationUrl ?? '',
                    videoUrl: resolvedCatalog?.videoUrl ?? '',
                    thumbnailUrl: resolvedCatalog?.thumbnailUrl ?? '',
                    imageUrl: resolvedCatalog?.imageUrl ?? '',
                    animationUrl: resolvedCatalog?.animationUrl ?? '',
                    exerciseName: widget.workoutExercise.exerciseName,
                    category: widget.workoutExercise.category,
                    movementPattern: resolvedCatalog?.movementPattern ?? '',
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      primaryMuscle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar: Guide | History | Records | Charts
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: colors.primaryRed,
              indicatorWeight: 3,
              labelColor: colors.textPrimary,
              unselectedLabelColor: colors.textTertiary,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Guide'),
                Tab(text: 'History'),
                Tab(text: 'Records'),
                Tab(text: 'Charts'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. GUIDE TAB
                _buildGuideTab(colors, resolvedCatalog, primaryMuscle, secondaryMuscle),

                // 2. HISTORY TAB (Matches reference screenshot IMG_3855)
                _buildHistoryTab(colors, history, targetReps, targetRpe),

                // 3. RECORDS TAB
                _buildRecordsTab(colors, history),

                // 4. CHARTS TAB
                _buildChartsTab(colors, history),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTab(
    ClientThemeColors colors,
    Exercise? catalog,
    String primaryMuscle,
    String secondaryMuscle,
  ) {
    final setupSteps = catalog?.setupInstructions ?? const <String>[];
    final execSteps = catalog?.executionSteps ?? const <String>[];
    final cues = catalog?.coachingCues ?? const <String>[];
    final note = widget.workoutExercise.trainerNote.trim().isNotEmpty
        ? widget.workoutExercise.trainerNote
        : (catalog?.defaultTrainerNote ?? '');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (note.isNotEmpty) ...[
          TrainerNoteCard(note: note),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TARGET MUSCLES',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.primaryRed),
                  const SizedBox(width: 6),
                  Text('Primary: ', style: TextStyle(color: colors.textTertiary, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(primaryMuscle, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              if (secondaryMuscle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: colors.textTertiary),
                    const SizedBox(width: 6),
                    Text('Secondary: ', style: TextStyle(color: colors.textTertiary, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(secondaryMuscle, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        ExerciseInstructions(
          setupInstructions: setupSteps,
          executionSteps: execSteps,
          coachingCues: cues,
          initialExpanded: true,
        ),
      ],
    );
  }

  Widget _buildHistoryTab(
    ClientThemeColors colors,
    List<ExercisePerformanceHistoryItem> history,
    String fallbackTargetReps,
    double fallbackTargetRpe,
  ) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 48, color: colors.textTertiary),
              const SizedBox(height: 14),
              Text(
                'No previous data',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You haven\'t logged any completed workouts for this exercise yet. Your sets logged today will automatically appear here next time!',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final formattedDate = _formatDate(item.completedAt);
        final title = item.sessionTitle.isNotEmpty ? item.sessionTitle : widget.workoutExercise.exerciseName;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(colors.isDark ? 0.3 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              // Table header: Sets | Completed | Target
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text('Sets', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text('Completed', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text('Target', style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border.withOpacity(0.5)),
              // Table rows
              ...item.sets.asMap().entries.map((entry) {
                final setIdx = entry.key + 1;
                final s = entry.value;
                final weightStr = s.actualWeight != null && s.actualWeight! > 0
                    ? (s.actualWeight! % 1 == 0 ? s.actualWeight!.toInt().toString() : s.actualWeight!.toStringAsFixed(1))
                    : (s.targetWeight > 0 ? (s.targetWeight % 1 == 0 ? s.targetWeight.toInt().toString() : s.targetWeight.toStringAsFixed(1)) : '0');
                final repsStr = s.actualReps?.toString() ?? s.targetRepsMin.toString();
                final rpeStr = s.actualRpe != null ? ' @ RPE ${s.actualRpe}' : (s.actualRir != null ? ' @ ${s.actualRir} RIR' : '');
                final targetStr = '${s.targetRepsDisplay} @ RPE ${s.targetRpe ?? fallbackTargetRpe}';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '$setIdx',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '$weightStr kg × $repsStr$rpeStr',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          targetStr,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordsTab(ClientThemeColors colors, List<ExercisePerformanceHistoryItem> history) {
    double maxWeight = 0.0;
    int maxReps = 0;
    double maxVolume = 0.0;

    for (final item in history) {
      for (final s in item.sets) {
        final w = s.actualWeight ?? s.targetWeight;
        final r = s.actualReps ?? s.targetRepsMin;
        if (w > maxWeight) maxWeight = w;
        if (r > maxReps) maxReps = r;
        if ((w * r) > maxVolume) maxVolume = (w * r);
      }
    }

    final estimated1RM = maxWeight > 0 && maxReps > 0
        ? (maxWeight * (1 + (maxReps / 30.0))).toStringAsFixed(1)
        : '-';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRecordCard(
          colors,
          title: 'HEAVIEST WEIGHT',
          value: maxWeight > 0 ? '${maxWeight % 1 == 0 ? maxWeight.toInt() : maxWeight.toStringAsFixed(1)} kg' : 'No records yet',
          subtitle: 'Personal max load lifted',
          icon: Icons.fitness_center_rounded,
        ),
        const SizedBox(height: 12),
        _buildRecordCard(
          colors,
          title: 'ESTIMATED 1RM',
          value: estimated1RM != '-' ? '$estimated1RM kg' : 'No records yet',
          subtitle: 'Calculated one rep maximum based on load and repetitions',
          icon: Icons.trending_up_rounded,
        ),
        const SizedBox(height: 12),
        _buildRecordCard(
          colors,
          title: 'BEST SET VOLUME',
          value: maxVolume > 0 ? '${maxVolume.round()} kg' : 'No records yet',
          subtitle: 'Highest single set work (load × repetitions)',
          icon: Icons.pie_chart_outline_rounded,
        ),
      ],
    );
  }

  Widget _buildRecordCard(
    ClientThemeColors colors, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primaryRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.primaryRed, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.textTertiary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
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

  Widget _buildChartsTab(ClientThemeColors colors, List<ExercisePerformanceHistoryItem> history) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          'No chart data available.\nComplete workouts to view progress trends.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final chronological = List.of(history.reversed);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'LOAD PROGRESSION ACROSS SESSIONS',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        ...chronological.map((item) {
          final topSet = item.sets.isNotEmpty
              ? item.sets.reduce((curr, next) => (curr.actualWeight ?? 0) > (next.actualWeight ?? 0) ? curr : next)
              : null;
          final topWeight = topSet?.actualWeight ?? 0.0;
          final reps = topSet?.actualReps ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(item.completedAt),
                        style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.sessionTitle,
                        style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primaryRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$topWeight kg × $reps',
                    style: TextStyle(color: colors.primaryRed, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
