import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_session_overview_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_history_screen.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/activity/presentation/screens/activity_dashboard_screen.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/screens/macro_planner_screen.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/daily_macro_summary.dart';
import 'package:alpha_x_gym/features/exercise/presentation/client/client_exercise_library_tab.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/widgets/add_food_bottom_sheet.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';

class ClientMainDashboardScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final ActivityRepository activityRepository;
  final MacroRepository macroRepository;

  const ClientMainDashboardScreen({
    super.key,
    required this.workoutRepository,
    required this.activityRepository,
    required this.macroRepository,
  });

  @override
  State<ClientMainDashboardScreen> createState() => _ClientMainDashboardScreenState();
}

class _ClientMainDashboardScreenState extends State<ClientMainDashboardScreen> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.workoutRepository.addListener(_onRepoChange);
    widget.activityRepository.addListener(_onRepoChange);
    widget.macroRepository.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    widget.workoutRepository.removeListener(_onRepoChange);
    widget.activityRepository.removeListener(_onRepoChange);
    widget.macroRepository.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const AlphaXLogo.appBar(size: 28),
            const SizedBox(width: 10),
            const Text(
              'ALPHA X GYM',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.textSecondary, size: 22),
            tooltip: 'Workout History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => ClientWorkoutHistoryScreen(workoutRepository: widget.workoutRepository),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildClientDrawer(),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildClientHomeScreen(),
          ClientWorkoutScreen(
            workoutRepository: widget.workoutRepository,
            showAppBar: false,
          ),
          const ClientExerciseLibraryTab(),
          MacroPlannerScreen(
            repository: widget.macroRepository,
            showAppBar: false,
          ),
          ActivityDashboardScreen(
            activityRepository: widget.activityRepository,
            showAppBar: false,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          color: AppColors.surface,
        ),
        child: NavigationBar(
          selectedIndex: _currentTabIndex.clamp(0, 4),
          onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.glowRed,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primaryRed),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center, color: AppColors.primaryRed),
              label: 'Workout',
            ),
            NavigationDestination(
              icon: Icon(Icons.format_list_bulleted_rounded),
              selectedIcon: Icon(Icons.format_list_bulleted, color: AppColors.primaryRed),
              label: 'Exercises',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart, color: AppColors.primaryRed),
              label: 'Nutrition',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_walk_outlined),
              selectedIcon: Icon(Icons.directions_walk, color: AppColors.primaryRed),
              label: 'Steps',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryRed,
                      child: Text(
                        AuthService().currentUserName.isNotEmpty ? AuthService().currentUserName.substring(0, 1) : 'A',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                    const AlphaXLogo(size: 30),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AuthService().currentUserName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.glowRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ELITE',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AuthService().currentUserEmail,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _drawerItem(0, 'Home', Icons.home_outlined),
          _drawerItem(1, 'Workout', Icons.fitness_center_outlined),
          _drawerItem(2, 'Exercise Library', Icons.format_list_bulleted_rounded),
          _drawerItem(3, 'Nutrition & Macros', Icons.pie_chart_outline),
          _drawerItem(4, 'Steps & Activity', Icons.directions_walk_outlined),
          const Divider(color: AppColors.border),
          _drawerSubPageItem('Food Library', Icons.restaurant_menu_outlined, () {
            Navigator.of(context).pop();
            AddFoodBottomSheet.show(
              context,
              repository: widget.macroRepository,
              mealType: MealType.snack,
              dateString: widget.macroRepository.getTodayDateString(),
            );
          }),
          _drawerSubPageItem('Attendance Pass', Icons.qr_code_scanner_outlined, () {
            Navigator.of(context).pop();
            _openAttendanceSubPage(context);
          }),
          _drawerSubPageItem('100-Day Challenge', Icons.local_fire_department_outlined, () {
            Navigator.of(context).pop();
            _openChallengeSubPage(context);
          }),
          _drawerSubPageItem('Body Progress & Weight', Icons.auto_graph_outlined, () {
            Navigator.of(context).pop();
            _openProgressSubPage(context);
          }),
          _drawerSubPageItem('Athlete Profile', Icons.person_outline, () {
            Navigator.of(context).pop();
            _openProfileSubPage(context);
          }),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.textSecondary),
            title: const Text('Sign Out', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.of(context).pop();
              AuthService().logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(int index, String title, IconData icon) {
    final isSelected = _currentTabIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? AppColors.primaryRed.withOpacity(0.12) : Colors.transparent,
        leading: Icon(icon, color: isSelected ? AppColors.primaryRed : AppColors.textSecondary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primaryRed : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _currentTabIndex = index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _drawerSubPageItem(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon, color: AppColors.textSecondary, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textTertiary),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }

  // --- TAB 0: 🏠 HOME DASHBOARD COMMAND CENTER ---
  Widget _buildClientHomeScreen() {
    final clientId = AuthService().currentUserId;
    final recommended = widget.workoutRepository.getTodaySessionForClient(clientId) ??
        widget.workoutRepository.getRecommendedSessionForClient(clientId);
    final history = widget.workoutRepository.clientHistory;
    final userFullName = AuthService().currentUserName;
    final firstName = userFullName.isNotEmpty ? userFullName.split(' ').first : 'Athlete';

    // Synchronize daily nutrition data directly from the single source of truth
    final todayStr = widget.macroRepository.getTodayDateString();
    final dailySummary = widget.macroRepository.getDailyMacroSummary(todayStr);

    final currentHour = DateTime.now().hour;
    final greetingText = currentHour < 12
        ? 'Good morning'
        : (currentHour < 17 ? 'Good afternoon' : 'Good evening');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. User Header & Profile Avatar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AlphaXColors.redAccent, width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AlphaXColors.surfaceElevated,
                          child: Text(
                            firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              color: AlphaXColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AlphaXColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: AlphaXColors.background, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greetingText, $firstName',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AlphaXColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Text(
                          "Train Strong • Move Better",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AlphaXColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                const AlphaXLogo.badge(size: 20),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceCard,
                    borderRadius: AlphaXRadius.roundedXs,
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 14, color: AlphaXColors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        '12 DAYS',
                        style: TextStyle(
                          color: AlphaXColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Prominent Client Profile Card (Prompt Requirement 21)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AlphaXColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AlphaXColors.redAccent.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: AlphaXColors.redAccent.withOpacity(0.08),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${AuthService().currentUserName}',
                          style: const TextStyle(
                            color: AlphaXColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Client ID: ',
                              style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AlphaXColors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AlphaXColors.redAccent, width: 0.8),
                              ),
                              child: Text(
                                AuthService().currentClientId,
                                style: const TextStyle(
                                  color: AlphaXColors.redAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AlphaXColors.border, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GOAL', style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                        const SizedBox(height: 2),
                        Text(
                          (AuthService().clientProfile['primaryGoal'] ?? 'General Fitness').toString(),
                          style: const TextStyle(color: AlphaXColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 26, color: AlphaXColors.border),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FITNESS LEVEL', style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                        const SizedBox(height: 2),
                        Text(
                          (AuthService().clientProfile['fitnessLevel'] ?? 'Intermediate').toString().toUpperCase(),
                          style: const TextStyle(color: AlphaXColors.redAccent, fontWeight: FontWeight.w800, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Navigation to Core Sections
        const AlphaXSectionHeader(title: 'MY ATHLETE PORTAL'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _clientSectionChip('MY WORKOUT', Icons.fitness_center, () => setState(() => _currentTabIndex = 1)),
            _clientSectionChip('EXERCISE LIBRARY', Icons.format_list_bulleted_rounded, () => setState(() => _currentTabIndex = 2)),
            _clientSectionChip('NUTRITION & MACROS', Icons.restaurant_menu, () => setState(() => _currentTabIndex = 3)),
            _clientSectionChip('DAILY STEPS', Icons.directions_walk, () => setState(() => _currentTabIndex = 4)),
            _clientSectionChip('MY ATTENDANCE', Icons.qr_code_scanner, () => _openAttendanceSubPage(context)),
            _clientSectionChip('MY CHALLENGE', Icons.local_fire_department, () => _openChallengeSubPage(context)),
            _clientSectionChip('MY PROGRESS', Icons.auto_graph, () => _openProgressSubPage(context)),
            _clientSectionChip('MY PROFILE', Icons.person, () => _openProfileSubPage(context)),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Large Hero Section (Cinematic gym photography blending into black background)
        AlphaXHero(
          imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=1200&q=80',
          tag: "TODAY'S WORKOUT",
          title: 'READY TO TRAIN?',
          subtitle: recommended != null
              ? 'Today\'s workout: ${recommended.title} • ${recommended.targetMuscleGroup}'
              : 'Push • Chest • Shoulders • Triceps',
          height: 280,
          action: AlphaXButton(
            label: 'START WORKOUT',
            icon: Icons.play_arrow_rounded,
            height: 48,
            onPressed: () {
              if (recommended != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ClientSessionOverviewScreen(
                      session: recommended,
                      workoutRepository: widget.workoutRepository,
                    ),
                  ),
                );
              } else {
                setState(() => _currentTabIndex = 1);
              }
            },
          ),
        ),
        const SizedBox(height: 20),

        // 3. Today's Metrics (Clean 2x2 Grid of real tracked metrics)
        const AlphaXSectionHeader(title: 'TODAY'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            AlphaXStatCard(
              icon: Icons.directions_walk_rounded,
              label: 'Steps',
              value: widget.activityRepository.todayRecord.formattedSteps,
              subtext: '/ ${widget.activityRepository.todayRecord.formattedGoal} goal',
              accentColor: AlphaXColors.redAccent,
              onTap: () => setState(() => _currentTabIndex = 4),
            ),
            AlphaXStatCard(
              icon: Icons.fitness_center_rounded,
              label: 'Workout',
              value: history.isNotEmpty ? 'Logged' : 'Ready',
              subtext: recommended != null ? recommended.title : (history.isNotEmpty ? '${history.length} completed' : 'Tap to start'),
              accentColor: history.isNotEmpty ? AlphaXColors.success : AlphaXColors.redAccent,
              onTap: () => setState(() => _currentTabIndex = 1),
            ),
            AlphaXStatCard(
              icon: Icons.local_fire_department_rounded,
              label: 'Calories',
              value: dailySummary.consumedCalories.round().toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]},',
              ),
              subtext: '/ ${dailySummary.targetCalories.round().toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]},',
              )} kcal',
              accentColor: AlphaXColors.redAccent,
              onTap: () => setState(() => _currentTabIndex = 3),
            ),
            AlphaXStatCard(
              icon: Icons.bolt_rounded,
              label: 'Protein',
              value: '${FoodLogEntry.formatMacro(dailySummary.consumedProtein)} g',
              subtext: '/ ${dailySummary.targetProtein.round()} g target',
              accentColor: AlphaXColors.redAccent,
              onTap: () => setState(() => _currentTabIndex = 3),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Section 11 & 12 & 23: DEDICATED TODAY'S NUTRITION SUMMARY CARD
        _buildTodayNutritionCard(dailySummary),
        const SizedBox(height: 20),

        // 4. Transformation Consistency Snapshot
        const AlphaXSectionHeader(title: 'YOUR TRANSFORMATION'),
        AlphaXCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _transformationMiniStat(
                    'PROFILE WEIGHT',
                    AuthService().clientProfile['weightKg'] != null && (AuthService().clientProfile['weightKg'] as num) > 0
                        ? '${AuthService().clientProfile['weightKg']} KG'
                        : '-- KG',
                  ),
                  Container(height: 36, width: 1, color: AlphaXColors.border),
                  _transformationMiniStat(
                    'GOAL',
                    (AuthService().clientProfile['primaryGoal'] ?? 'General Fitness').toString().toUpperCase(),
                    isAccent: true,
                  ),
                  Container(height: 36, width: 1, color: AlphaXColors.border),
                  _transformationMiniStat('SESSIONS', '${history.length} Done'),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AlphaXColors.border, height: 1),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Icon(Icons.trending_down_rounded, size: 16, color: AlphaXColors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'Consistency > daily fluctuations',
                    style: TextStyle(
                      color: AlphaXColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5. Recent Workouts Preview
        AlphaXSectionHeader(
          title: 'RECENT SESSIONS',
          actionLabel: 'View All',
          onActionTap: () => setState(() => _currentTabIndex = 1),
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No workout sessions recorded yet. Start your first session above.',
              style: TextStyle(color: AlphaXColors.textTertiary, fontSize: 13),
            ),
          )
        else
          ...history.take(2).map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AlphaXColors.surfaceCard,
                borderRadius: AlphaXRadius.roundedSm,
                border: Border.all(color: AlphaXColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AlphaXColors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: AlphaXColors.redAccent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.sessionTitle,
                      style: const TextStyle(
                        color: AlphaXColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${r.durationDisplay} • ${r.totalVolume.toInt()} kg',
                    style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _transformationMiniStat(String label, String value, {bool isAccent = false, String? delta}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AlphaXColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isAccent ? AlphaXColors.redAccent : AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AlphaXColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AlphaXColors.success.withValues(alpha: 0.3)),
            ),
            child: Text(
              delta,
              style: const TextStyle(
                color: AlphaXColors.success,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Section 11, 12, 23: Dedicated compact Today's Nutrition card for the client dashboard
  Widget _buildTodayNutritionCard(DailyMacroSummary dailySummary) {
    final calConsumed = dailySummary.consumedCalories.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final calTarget = dailySummary.targetCalories.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final protConsumed = FoodLogEntry.formatMacro(dailySummary.consumedProtein);
    final protTarget = dailySummary.targetProtein.round().toString();
    final carbsConsumed = FoodLogEntry.formatMacro(dailySummary.consumedCarbs);
    final carbsTarget = dailySummary.targetCarbs.round().toString();
    final fatConsumed = FoodLogEntry.formatMacro(dailySummary.consumedFat);
    final fatTarget = dailySummary.targetFat.round().toString();

    final isCalOver = dailySummary.isCaloriesOver;

    return AlphaXCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => setState(() => _currentTabIndex = 3),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with title and "Open Macros >"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.pie_chart_rounded, size: 16, color: AlphaXColors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      "TODAY'S NUTRITION",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: AlphaXColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Text(
                      'MACROS',
                      style: TextStyle(
                        color: AlphaXColors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: AlphaXColors.redAccent),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Calorie Completion Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: dailySummary.calorieProgress,
                minHeight: 3.5,
                backgroundColor: AlphaXColors.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation<Color>(AlphaXColors.redAccent),
              ),
            ),

            const SizedBox(height: 14),

            // 4 Macro Rows with Clean Icons (Section 12)
            Row(
              children: [
                Expanded(
                  child: _nutritionSummaryItem(
                    emoji: '🔥',
                    label: 'Calories',
                    value: '$calConsumed / $calTarget',
                    unit: 'kcal',
                    color: AlphaXColors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _nutritionSummaryItem(
                    emoji: '💪',
                    label: 'Protein',
                    value: '$protConsumed / $protTarget',
                    unit: 'g',
                    color: AlphaXColors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _nutritionSummaryItem(
                    emoji: '🍚',
                    label: 'Carbs',
                    value: '$carbsConsumed / $carbsTarget',
                    unit: 'g',
                    color: AlphaXColors.info,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _nutritionSummaryItem(
                    emoji: '🥑',
                    label: 'Fat',
                    value: '$fatConsumed / $fatTarget',
                    unit: 'g',
                    color: AlphaXColors.gold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: AlphaXColors.borderSubtle, height: 1),
            const SizedBox(height: 10),

            // REMAINING Summary (Section 11)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCalOver ? AlphaXColors.redSubtle : AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isCalOver ? AlphaXColors.redAccent : AlphaXColors.border),
                  ),
                  child: Text(
                    isCalOver ? 'OVER' : 'REMAINING',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: isCalOver ? AlphaXColors.redAccent : AlphaXColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCalOver
                        ? '+${dailySummary.overCalories.round()} kcal • ${FoodLogEntry.formatMacro(dailySummary.overProtein)}g P • ${FoodLogEntry.formatMacro(dailySummary.overCarbs)}g C • ${FoodLogEntry.formatMacro(dailySummary.overFat)}g F over'
                        : '${dailySummary.safeRemainingCalories.round()} kcal • ${FoodLogEntry.formatMacro(dailySummary.safeRemainingProtein)}g Protein • ${FoodLogEntry.formatMacro(dailySummary.safeRemainingCarbs)}g Carbs • ${FoodLogEntry.formatMacro(dailySummary.safeRemainingFat)}g Fat',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCalOver ? AlphaXColors.redAccent : AlphaXColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutritionSummaryItem({
    required String emoji,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AlphaXColors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AlphaXColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // NAVIGATION OPENERS FOR DRAWER SUB-PAGES
  // ==========================================

  void _openAttendanceSubPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ClientAttendanceSubScreen(workoutRepository: widget.workoutRepository),
      ),
    );
  }

  void _openChallengeSubPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ClientChallengeSubScreen(
          workoutRepository: widget.workoutRepository,
          onNavigateToWorkout: () => setState(() => _currentTabIndex = 1),
        ),
      ),
    );
  }

  void _openProgressSubPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ClientProgressSubScreen(workoutRepository: widget.workoutRepository),
      ),
    );
  }

  void _openProfileSubPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ClientProfileSubScreen(workoutRepository: widget.workoutRepository),
      ),
    );
  }

  Widget _clientSectionChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AlphaXColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AlphaXColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AlphaXColors.redAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AlphaXColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. ATTENDANCE SUB-SCREEN (REAL DATA & QR)
// ==========================================

class _ClientAttendanceSubScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;

  const _ClientAttendanceSubScreen({required this.workoutRepository});

  @override
  State<_ClientAttendanceSubScreen> createState() => _ClientAttendanceSubScreenState();
}

class _ClientAttendanceSubScreenState extends State<_ClientAttendanceSubScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    final records = await widget.workoutRepository.fetchClientAttendance();
    if (mounted) {
      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonthRecords = _attendanceRecords.where((r) {
      final raw = r['checkInTime'] ?? r['date'] ?? r['createdAt'];
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw.toString());
      return dt != null && dt.month == now.month && dt.year == now.year;
    }).length;

    String lastVisitStr = 'None';
    if (_attendanceRecords.isNotEmpty) {
      final raw = _attendanceRecords.first['checkInTime'] ?? _attendanceRecords.first['date'] ?? _attendanceRecords.first['createdAt'];
      if (raw != null) {
        final dt = DateTime.tryParse(raw.toString());
        if (dt != null) {
          lastVisitStr = '${dt.day}/${dt.month}/${dt.year}';
        }
      }
    }

    return Scaffold(
      backgroundColor: AlphaXColors.background,
      appBar: AppBar(
        backgroundColor: AlphaXColors.background,
        elevation: 0,
        title: const Text(
          'ATTENDANCE PASS',
          style: TextStyle(
            color: AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AlphaXColors.textSecondary),
            onPressed: _loadAttendance,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAttendance,
        color: AlphaXColors.redAccent,
        backgroundColor: AlphaXColors.surfaceCard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Check-in QR pass
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AlphaXColors.surfaceCard,
                borderRadius: AlphaXRadius.roundedXl,
                border: Border.all(color: AlphaXColors.redAccent.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AlphaXColors.redAccent.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const AlphaXLogo(size: 38),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AlphaXColors.redAccent.withOpacity(0.4), width: 2),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, size: 130, color: Colors.black),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ALPHA X ACCESS PASS',
                    style: TextStyle(
                      color: AlphaXColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Client ID: ${AuthService().currentUserId}',
                    style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AlphaXColors.surfaceElevated,
                      borderRadius: AlphaXRadius.roundedXs,
                    ),
                    child: const Text(
                      'Present this QR at turnstiles & terminal scanners for verification',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Real Attendance Metrics
            AlphaXCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statColumn('TOTAL VISITS', '${_attendanceRecords.length}', isHighlight: true),
                  Container(height: 36, width: 1, color: AlphaXColors.border),
                  _statColumn('THIS MONTH', '$thisMonthRecords'),
                  Container(height: 36, width: 1, color: AlphaXColors.border),
                  _statColumn('LAST VISIT', lastVisitStr),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Logs Header
            const AlphaXSectionHeader(title: 'VERIFIED ATTENDANCE HISTORY'),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AlphaXColors.redAccent),
                ),
              )
            else if (_attendanceRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AlphaXColors.surfaceCard,
                  borderRadius: AlphaXRadius.roundedMd,
                  border: Border.all(color: AlphaXColors.border),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.event_busy_rounded, size: 44, color: AlphaXColors.textTertiary),
                    SizedBox(height: 12),
                    Text(
                      'No attendance records yet.',
                      style: TextStyle(color: AlphaXColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your gym visits will automatically appear here once scanned at the gym terminal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ..._attendanceRecords.map((entry) {
                final rawTime = entry['checkInTime'] ?? entry['date'] ?? entry['createdAt'] ?? '';
                final parsed = DateTime.tryParse(rawTime.toString());
                final formatted = parsed != null
                    ? '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} at ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}'
                    : rawTime.toString();
                final terminal = entry['terminalId'] ?? entry['location'] ?? 'Alpha X Main Gym';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceCard,
                    borderRadius: AlphaXRadius.roundedSm,
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatted,
                              style: const TextStyle(
                                color: AlphaXColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$terminal • Verified Check-In',
                              style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AlphaXColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? AlphaXColors.redAccent : AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. CHALLENGE SUB-SCREEN (REAL 100-DAY DATA)
// ==========================================

class _ClientChallengeSubScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final VoidCallback onNavigateToWorkout;

  const _ClientChallengeSubScreen({
    required this.workoutRepository,
    required this.onNavigateToWorkout,
  });

  @override
  State<_ClientChallengeSubScreen> createState() => _ClientChallengeSubScreenState();
}

class _ClientChallengeSubScreenState extends State<_ClientChallengeSubScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _challengeData;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    setState(() => _isLoading = true);
    final data = await widget.workoutRepository.fetchClientChallenge();
    if (mounted) {
      setState(() {
        _challengeData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlphaXColors.background,
      appBar: AppBar(
        backgroundColor: AlphaXColors.background,
        elevation: 0,
        title: const Text(
          '100-DAY CHALLENGE',
          style: TextStyle(
            color: AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AlphaXColors.textSecondary),
            onPressed: _loadChallenge,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadChallenge,
        color: AlphaXColors.redAccent,
        backgroundColor: AlphaXColors.surfaceCard,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AlphaXColors.redAccent))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final hasChallenge = _challengeData != null && _challengeData!['enrolled'] == true;

    if (!hasChallenge) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AlphaXColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AlphaXColors.border),
              ),
              child: const Icon(Icons.local_fire_department_outlined, size: 54, color: AlphaXColors.textTertiary),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'No active challenge',
              style: TextStyle(
                color: AlphaXColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You are not currently enrolled in an active 100-Day Challenge sprint. Speak to your coach or gym administration to start your official transformation journey.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 32),
          AlphaXButton(
            label: 'VIEW TODAY\'S WORKOUT',
            icon: Icons.fitness_center_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              widget.onNavigateToWorkout();
            },
          ),
        ],
      );
    }

    final challengeTitle = _challengeData!['challengeTitle'] ?? '100-Day Alpha X Challenge';
    final currentDay = _challengeData!['currentDay'] ?? 1;
    final targetDays = _challengeData!['targetDays'] ?? 100;
    final progressFraction = (currentDay / targetDays).clamp(0.0, 1.0);
    final percentInt = (progressFraction * 100).toInt();
    final startDateStr = _challengeData!['startDate']?.toString().split('T').first ?? 'Active';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AlphaXHero(
          imageUrl: 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=1200&q=80',
          tag: 'OFFICIAL CHALLENGE',
          title: challengeTitle.toString().toUpperCase(),
          subtitle: 'Day $currentDay / $targetDays • $percentInt% Complete\nStarted: $startDateStr',
          height: 280,
          action: AlphaXButton(
            label: 'START TODAY\'S WORKOUT',
            icon: Icons.play_arrow_rounded,
            height: 46,
            onPressed: () {
              Navigator.of(context).pop();
              widget.onNavigateToWorkout();
            },
          ),
        ),
        const SizedBox(height: 20),
        const AlphaXSectionHeader(title: 'CHALLENGE PROGRESS'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AlphaXColors.surfaceCard,
            borderRadius: AlphaXRadius.roundedMd,
            border: Border.all(color: AlphaXColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.local_fire_department_rounded, color: AlphaXColors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '100-Day Transformation Goal',
                        style: TextStyle(
                          color: AlphaXColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$percentInt%',
                    style: const TextStyle(
                      color: AlphaXColors.redAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AlphaXLinearProgress(progress: progressFraction, progressColor: AlphaXColors.redAccent),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Day $currentDay of $targetDays', style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12)),
                  Text('${targetDays - currentDay} days remaining', style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. PROGRESS SUB-SCREEN (REAL DATA & CHECK-INS)
// ==========================================

class _ClientProgressSubScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;

  const _ClientProgressSubScreen({required this.workoutRepository});

  @override
  State<_ClientProgressSubScreen> createState() => _ClientProgressSubScreenState();
}

class _ClientProgressSubScreenState extends State<_ClientProgressSubScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _progressRecords = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    final records = await widget.workoutRepository.fetchClientProgress();
    if (mounted) {
      setState(() {
        _progressRecords = records;
        _isLoading = false;
      });
    }
  }

  void _showAddProgressDialog() {
    final weightController = TextEditingController();
    final waistController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AlphaXColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: AlphaXRadius.roundedMd),
        title: const Text(
          'LOG BODY CHECK-IN',
          style: TextStyle(
            color: AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.8,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Body Weight (kg) *',
                  labelStyle: TextStyle(color: AlphaXColors.textSecondary),
                  prefixIcon: Icon(Icons.monitor_weight_outlined, color: AlphaXColors.redAccent),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AlphaXColors.border)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AlphaXColors.redAccent)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waistController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Waist Circumference (cm, optional)',
                  labelStyle: TextStyle(color: AlphaXColors.textSecondary),
                  prefixIcon: Icon(Icons.straighten_rounded, color: AlphaXColors.textTertiary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AlphaXColors.border)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AlphaXColors.redAccent)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: TextStyle(color: AlphaXColors.textSecondary),
                  prefixIcon: Icon(Icons.notes_rounded, color: AlphaXColors.textTertiary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AlphaXColors.border)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AlphaXColors.redAccent)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: AlphaXColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AlphaXColors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final w = double.tryParse(weightController.text.trim());
              if (w == null || w <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid weight in kg.')),
                );
                return;
              }
              final waist = double.tryParse(waistController.text.trim());
              final notes = notesController.text.trim().isNotEmpty ? notesController.text.trim() : null;

              Navigator.of(ctx).pop();
              final success = await widget.workoutRepository.logClientProgress(
                weightKg: w,
                waistCm: waist,
                notes: notes,
              );

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Check-in logged successfully!')),
                  );
                  _loadProgress();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not log check-in. Please try again.')),
                  );
                }
              }
            },
            child: const Text('SAVE CHECK-IN', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine real metrics
    String startWeightStr = 'N/A';
    String currentWeightStr = 'N/A';
    String deltaStr = '0.0 kg';

    if (_progressRecords.isNotEmpty) {
      final latest = _progressRecords.first;
      final oldest = _progressRecords.last;

      final currentWeight = double.tryParse(latest['weightKg']?.toString() ?? '');
      final startWeight = double.tryParse(oldest['weightKg']?.toString() ?? '');

      if (currentWeight != null) currentWeightStr = '${currentWeight.toStringAsFixed(1)} KG';
      if (startWeight != null) startWeightStr = '${startWeight.toStringAsFixed(1)} KG';

      if (currentWeight != null && startWeight != null) {
        final diff = currentWeight - startWeight;
        deltaStr = '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg';
      }
    } else {
      final profileWeight = AuthService().clientProfile['weightKg'];
      if (profileWeight != null) {
        final pw = double.tryParse(profileWeight.toString());
        if (pw != null) {
          startWeightStr = '${pw.toStringAsFixed(1)} KG';
          currentWeightStr = '${pw.toStringAsFixed(1)} KG';
        }
      }
    }

    return Scaffold(
      backgroundColor: AlphaXColors.background,
      appBar: AppBar(
        backgroundColor: AlphaXColors.background,
        elevation: 0,
        title: const Text(
          'BODY PROGRESS & WEIGHT',
          style: TextStyle(
            color: AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AlphaXColors.redAccent),
            tooltip: 'Log Check-In',
            onPressed: _showAddProgressDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProgress,
        color: AlphaXColors.redAccent,
        backgroundColor: AlphaXColors.surfaceCard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AlphaXHero(
              imageUrl: 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=1200&q=80',
              tag: 'BODY COMPOSITION',
              title: 'YOUR PROGRESS',
              subtitle: 'Consistency > daily fluctuations',
              height: 240,
              action: AlphaXButton(
                label: 'LOG CHECK-IN',
                icon: Icons.monitor_weight_outlined,
                height: 44,
                onPressed: _showAddProgressDialog,
              ),
            ),
            const SizedBox(height: 20),
            const AlphaXSectionHeader(title: 'WEIGHT OVERVIEW'),
            AlphaXCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricColumn('STARTING', startWeightStr),
                  Container(height: 38, width: 1, color: AlphaXColors.border),
                  _metricColumn('CURRENT', currentWeightStr, isAccent: true),
                  Container(height: 38, width: 1, color: AlphaXColors.border),
                  _metricColumn('NET CHANGE', deltaStr),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const AlphaXSectionHeader(title: 'LOGGED CHECK-INS'),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AlphaXColors.redAccent),
                ),
              )
            else if (_progressRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AlphaXColors.surfaceCard,
                  borderRadius: AlphaXRadius.roundedMd,
                  border: Border.all(color: AlphaXColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.auto_graph_outlined, size: 44, color: AlphaXColors.textTertiary),
                    const SizedBox(height: 12),
                    const Text(
                      'No progress data yet.',
                      style: TextStyle(color: AlphaXColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Log your first body weight check-in to start tracking your recomposition trend.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AlphaXColors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('LOG FIRST CHECK-IN'),
                      onPressed: _showAddProgressDialog,
                    ),
                  ],
                ),
              )
            else
              ..._progressRecords.map((r) {
                final raw = r['recordedAt'] ?? r['date'] ?? r['createdAt'] ?? '';
                final dt = DateTime.tryParse(raw.toString());
                final dateStr = dt != null
                    ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
                    : raw.toString();
                final weight = r['weightKg']?.toString() ?? '-';
                final waist = r['waistCm']?.toString();
                final notes = r['notes']?.toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceCard,
                    borderRadius: AlphaXRadius.roundedSm,
                    border: Border.all(color: AlphaXColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AlphaXColors.redAccent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monitor_weight_outlined, color: AlphaXColors.redAccent, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$weight kg',
                              style: const TextStyle(
                                color: AlphaXColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                dateStr,
                                if (waist != null && waist.isNotEmpty) 'Waist: $waist cm',
                                if (notes != null && notes.isNotEmpty) notes,
                              ].join(' • '),
                              style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(String label, String value, {bool isAccent = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AlphaXColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isAccent ? AlphaXColors.redAccent : AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. ATHLETE PROFILE SUB-SCREEN (REAL DATA)
// ==========================================

class _ClientProfileSubScreen extends StatelessWidget {
  final WorkoutRepository workoutRepository;

  const _ClientProfileSubScreen({required this.workoutRepository});

  @override
  Widget build(BuildContext context) {
    final userName = AuthService().currentUserName;
    final userEmail = AuthService().currentUserEmail;
    final userId = AuthService().currentUserId;
    final clientProfile = AuthService().clientProfile;
    final completedWorkoutsCount = workoutRepository.clientHistory.length;

    return Scaffold(
      backgroundColor: AlphaXColors.background,
      appBar: AppBar(
        backgroundColor: AlphaXColors.background,
        elevation: 0,
        title: const Text(
          'ATHLETE PROFILE',
          style: TextStyle(
            color: AlphaXColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AlphaXLogo(size: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'ATHLETE MEMBER',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryRed,
                  child: Text(
                    userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userName.isNotEmpty ? userName : 'Alpha X Athlete',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Client ID: $userId',
                    style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _profileMetric('COMPLETED WORKOUTS', '$completedWorkoutsCount', Icons.fitness_center),
                    Container(height: 32, width: 1, color: AppColors.border),
                    _profileMetric(
                      'START WEIGHT',
                      clientProfile['weightKg'] != null ? '${clientProfile['weightKg']} KG' : 'N/A',
                      Icons.monitor_weight_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Fitness Assessment Details if available
          if (clientProfile.isNotEmpty) ...[
            const AlphaXSectionHeader(title: 'FITNESS PROFILE'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _infoRow('Primary Goal', clientProfile['fitnessGoal'] ?? clientProfile['goal'] ?? 'Not set'),
                  const Divider(color: AppColors.border, height: 16),
                  _infoRow('Experience Level', clientProfile['experienceLevel'] ?? clientProfile['level'] ?? 'Not set'),
                  const Divider(color: AppColors.border, height: 16),
                  _infoRow('Activity Level', clientProfile['activityLevel'] ?? 'Moderate'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Sign Out Action
          ListTile(
            tileColor: AppColors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: AppColors.primaryRed, size: 20),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: const Text(
              'Log out of your Alpha X Gym athlete account',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
            onTap: () {
              AuthService().logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _profileMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primaryRed),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(
          value.toString(),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

