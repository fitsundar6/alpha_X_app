import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_session_overview_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_execution_screen.dart';
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
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_weekly_progress_screen.dart';
import 'package:alpha_x_gym/features/notifications/data/repositories/notification_repository.dart';
import 'package:alpha_x_gym/features/notifications/presentation/widgets/notification_sheet.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_transformation_timeline_screen.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/presentation/screens/my_food_photos_screen.dart';
import 'package:alpha_x_gym/features/notifications/presentation/widgets/notification_preferences_dialog.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';


class ClientMainDashboardScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final ActivityRepository activityRepository;
  final MacroRepository macroRepository;
  final WeeklyProgressRepository? weeklyProgressRepository;

  const ClientMainDashboardScreen({
    super.key,
    required this.workoutRepository,
    required this.activityRepository,
    required this.macroRepository,
    this.weeklyProgressRepository,
  });

  @override
  State<ClientMainDashboardScreen> createState() => _ClientMainDashboardScreenState();
}

class _ClientMainDashboardScreenState extends State<ClientMainDashboardScreen> {
  int _currentTabIndex = 0;
  final List<int> _tabHistory = [0];
  DateTime? _lastBackPressTime;
  double? _dragStartX;
  late final WeeklyProgressRepository _weeklyProgressRepository;
  final NotificationRepository _notificationRepository = NotificationRepository();
  final ClientThemeService _themeService = ClientThemeService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _weeklyProgressRepository = widget.weeklyProgressRepository ?? WeeklyProgressRepository();
    widget.workoutRepository.addListener(_onRepoChange);
    widget.activityRepository.addListener(_onRepoChange);
    widget.macroRepository.addListener(_onRepoChange);
    _weeklyProgressRepository.addListener(_onRepoChange);
    _notificationRepository.addListener(_onRepoChange);
    _themeService.addListener(_onRepoChange);
    _weeklyProgressRepository.fetchCheckInStatus();
    _notificationRepository.sendActivityPing();
    _notificationRepository.fetchNotifications();

    // Automatically synchronize assigned workouts and diet plan from shared database
    widget.workoutRepository.fetchClientWorkouts();
    widget.macroRepository.fetchAssignedDietPlan();
  }

  @override
  void dispose() {
    widget.workoutRepository.removeListener(_onRepoChange);
    widget.activityRepository.removeListener(_onRepoChange);
    widget.macroRepository.removeListener(_onRepoChange);
    _weeklyProgressRepository.removeListener(_onRepoChange);
    _notificationRepository.removeListener(_onRepoChange);
    _themeService.removeListener(_onRepoChange);
    _notificationRepository.dispose();
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  void _selectTab(int idx) {
    if (_currentTabIndex != idx) {
      AlphaXHaptics.selection();
      setState(() {
        _currentTabIndex = idx;
        if (_tabHistory.isEmpty || _tabHistory.last != idx) {
          _tabHistory.add(idx);
        }
      });

      // Synchronize latest plans from database whenever the client switches tabs
      AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Client tab switch to $idx');
    }
  }

  bool _navigateBack() {
    // 1. If Drawer is open, close it
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
      return true;
    }

    // 2. If tab history has previous tabs, step back in history (e.g. Exercise -> Workout -> Home)
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _currentTabIndex = _tabHistory.last;
      });
      return true;
    }

    // 3. If currently on a non-zero tab, return to Home (Tab 0)
    if (_currentTabIndex != 0) {
      setState(() {
        _currentTabIndex = 0;
        _tabHistory.clear();
        _tabHistory.add(0);
      });
      return true;
    }

    // At root Home screen:
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final clientTheme = _themeService.resolveTheme(context);
    final colors = ClientThemeColors(context);

    return AnimatedTheme(
      data: clientTheme,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          if (_navigateBack()) {
            return;
          }

          // 4. Root Home Screen Protection against accidental exit:
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2, milliseconds: 500)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Press back again to exit Alpha X Gym',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: colors.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: colors.border),
                ),
              ),
            );
            return;
          }

          // Confirmed double-back at root: allow system exit
          SystemNavigator.pop();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) {
            _dragStartX = details.globalPosition.dx;
          },
          onHorizontalDragEnd: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isLeftEdgeSwipe = _dragStartX != null && _dragStartX! <= 60.0 && (details.primaryVelocity ?? 0) > 150;
            final isRightEdgeSwipe = _dragStartX != null && _dragStartX! >= (screenWidth - 60.0) && (details.primaryVelocity ?? 0) < -150;
            if (isLeftEdgeSwipe || isRightEdgeSwipe) {
              _navigateBack();
            }
            _dragStartX = null;
          },
          child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: clientTheme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: clientTheme.appBarTheme.backgroundColor,
            titleSpacing: 16,
            iconTheme: IconThemeData(color: colors.textPrimary),
            title: Row(
              children: [
                const AlphaXLogo.appBar(size: 28),
                const SizedBox(width: 10),
                Text(
                  'ALPHA X GYM',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            actions: [
              // In-App Notification Bell with Unread Count Badge
              AnimatedBuilder(
                animation: _notificationRepository,
                builder: (context, _) {
                  final unread = _notificationRepository.unreadCount;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined, color: colors.textSecondary, size: 22),
                        tooltip: 'Notifications',
                        onPressed: () => NotificationSheet.show(context, _notificationRepository),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.history, color: colors.textSecondary, size: 22),
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
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AlphaXGlassBar(
                blur: 20.0,
                borderRadius: BorderRadius.circular(24),
                color: colors.isDark ? const Color(0xF2151515) : colors.surfaceElevated.withOpacity(0.92),
                border: Border.all(
                  color: colors.isDark ? const Color(0xFF262626) : colors.border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(colors.isDark ? 0.6 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    backgroundColor: Colors.transparent,
                    indicatorColor: AppColors.primary.withOpacity(0.18),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        );
                      }
                      return GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      );
                    }),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const IconThemeData(color: AppColors.primary, size: 22);
                      }
                      return const IconThemeData(color: AppColors.textSecondary, size: 20);
                    }),
                  ),
                  child: NavigationBar(
                    height: 64,
                    selectedIndex: _currentTabIndex.clamp(0, 4),
                    onDestinationSelected: _selectTab,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.fitness_center_outlined),
                        selectedIcon: Icon(Icons.fitness_center_rounded, color: AppColors.primary),
                        label: 'Workout',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.format_list_bulleted_rounded),
                        selectedIcon: Icon(Icons.format_list_bulleted_rounded, color: AppColors.primary),
                        label: 'Exercises',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.restaurant_outlined),
                        selectedIcon: Icon(Icons.restaurant_rounded, color: AppColors.primary),
                        label: 'Nutrition',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.directions_walk_outlined),
                        selectedIcon: Icon(Icons.directions_walk_rounded, color: AppColors.primary),
                        label: 'Steps',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildClientDrawer() {
    final colors = ClientThemeColors(context);
    return Drawer(
      backgroundColor: colors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(bottom: BorderSide(color: colors.border, width: 1)),
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
                      backgroundColor: colors.primaryRed,
                      child: Text(
                        AuthService().currentUserName.isNotEmpty ? AuthService().currentUserName.substring(0, 1) : 'A',
                        style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w900, fontSize: 18),
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
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.glowRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ELITE',
                        style: TextStyle(
                          color: colors.primaryRed,
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
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
          Divider(color: colors.border),
          _drawerSubPageItem('Food Library', Icons.restaurant_menu_outlined, () {
            Navigator.of(context).pop();
            AddFoodBottomSheet.show(
              context,
              repository: widget.macroRepository,
              mealType: MealType.snack,
              dateString: widget.macroRepository.getTodayDateString(),
            );
          }),
          _drawerSubPageItem('My Food Photos', Icons.camera_alt_outlined, () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyFoodPhotosScreen()),
            );
          }),
          _drawerSubPageItem('Weekly Progress & Check-In', Icons.event_available_outlined, () {
            Navigator.of(context).pop();
            _openProgressSubPage(context);
          }),
          _drawerSubPageItem('Transformation Timeline', Icons.timeline_outlined, () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientTransformationTimelineScreen()),
            );
          }),
          _drawerSubPageItem('Athlete Profile', Icons.person_outline, () {
            Navigator.of(context).pop();
            _openProfileSubPage(context);
          }),
          _drawerSubPageItem('Appearance', Icons.palette_outlined, () {
            Navigator.of(context).pop();
            _openAppearanceDialog(context);
          }),
          _drawerSubPageItem('Notification Settings', Icons.tune_outlined, () {
            Navigator.of(context).pop();
            NotificationPreferencesDialog.show(context, _notificationRepository);
          }),
          Divider(color: ClientThemeColors(context).border),
          ListTile(
            leading: Icon(Icons.logout, color: ClientThemeColors(context).textSecondary),
            title: Text('Sign Out', style: TextStyle(color: ClientThemeColors(context).textSecondary, fontWeight: FontWeight.w600)),
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
    final colors = ClientThemeColors(context);
    final isSelected = _currentTabIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? colors.primaryRed.withOpacity(0.12) : Colors.transparent,
        leading: Icon(icon, color: isSelected ? colors.primaryRed : colors.textSecondary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? colors.primaryRed : colors.textPrimary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        onTap: () {
          HapticFeedback.lightImpact();
          _selectTab(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _drawerSubPageItem(String title, IconData icon, VoidCallback onTap) {
    final colors = ClientThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon, color: colors.textSecondary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 12, color: colors.textTertiary),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }

  void _openAppearanceDialog(BuildContext context) {
    final colors = ClientThemeColors(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final mode = _themeService.themeMode;
          return AlertDialog(
            backgroundColor: colors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            title: Row(
              children: [
                Icon(Icons.palette_outlined, color: colors.primaryRed, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Appearance',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeRadioOption(
                  mode: ClientThemeMode.light,
                  icon: Icons.wb_sunny_outlined,
                  title: 'Light Mode',
                  selected: mode == ClientThemeMode.light,
                  onSelect: () {
                    _themeService.setThemeMode(ClientThemeMode.light);
                    setDialogState(() {});
                  },
                  colors: colors,
                ),
                Divider(color: colors.border, height: 16),
                _buildThemeRadioOption(
                  mode: ClientThemeMode.dark,
                  icon: Icons.nightlight_round_outlined,
                  title: 'Dark Mode',
                  selected: mode == ClientThemeMode.dark,
                  onSelect: () {
                    _themeService.setThemeMode(ClientThemeMode.dark);
                    setDialogState(() {});
                  },
                  colors: colors,
                ),
                Divider(color: colors.border, height: 16),
                _buildThemeRadioOption(
                  mode: ClientThemeMode.system,
                  icon: Icons.settings_brightness_outlined,
                  title: 'System Default',
                  selected: mode == ClientThemeMode.system,
                  onSelect: () {
                    _themeService.setThemeMode(ClientThemeMode.system);
                    setDialogState(() {});
                  },
                  colors: colors,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Done', style: TextStyle(color: colors.primaryRed, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeRadioOption({
    required ClientThemeMode mode,
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onSelect,
    required ClientThemeColors colors,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, color: selected ? colors.primaryRed : colors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? colors.primaryRed : colors.textPrimary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colors.primaryRed : colors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeginnerWorkoutCard(ClientThemeColors colors, WorkoutSession? recommended) {
    final hasActive = widget.workoutRepository.hasActiveSavedSession;
    final active = widget.workoutRepository.activeSession;

    final String sessionTitle;
    final String sessionSubtitle;
    final String statusLabel;
    final Color statusColor;
    final String buttonLabel;
    final IconData buttonIcon;

    if (hasActive) {
      final totalSets = active.totalSets;
      final completedSets = active.totalCompletedSets;
      final percent = totalSets > 0 ? ((completedSets / totalSets) * 100).round() : 0;
      sessionTitle = active.title;
      sessionSubtitle = '$percent% complete • $completedSets/$totalSets sets done';
      statusLabel = 'IN PROGRESS';
      statusColor = AppColors.warning;
      buttonLabel = 'RESUME WORKOUT';
      buttonIcon = Icons.play_arrow_rounded;
    } else if (recommended != null) {
      sessionTitle = recommended.title;
      sessionSubtitle = '${recommended.estimatedDurationMinutes} min • ${recommended.exercises.length} exercises • ${recommended.targetMuscleGroup}';
      statusLabel = "TODAY'S TARGET";
      statusColor = colors.primaryRed;
      buttonLabel = 'START WORKOUT';
      buttonIcon = Icons.play_arrow_rounded;
    } else {
      sessionTitle = 'No workout assigned';
      sessionSubtitle = "Your trainer hasn't assigned a workout yet.";
      statusLabel = 'NO ASSIGNMENT';
      statusColor = colors.textSecondary;
      buttonLabel = 'CONTACT YOUR TRAINER';
      buttonIcon = Icons.chat_bubble_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colors.isDark ? 0.35 : 0.04),
            blurRadius: 14,
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.primaryRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.fitness_center_rounded, color: colors.primaryRed, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "TODAY'S WORKOUT",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sessionTitle,
            style: GoogleFonts.poppins(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            sessionSubtitle,
            style: GoogleFonts.poppins(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(buttonIcon, size: 20),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: () {
                AlphaXHaptics.tap();
                if (hasActive) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => ClientWorkoutExecutionScreen(
                        workoutRepository: widget.workoutRepository,
                        session: active,
                        sessionId: active.id,
                      ),
                    ),
                  );
                } else if (recommended != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => ClientSessionOverviewScreen(
                        session: recommended,
                        workoutRepository: widget.workoutRepository,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Your trainer hasn't assigned a workout yet. Please reach out to your coach."),
                      backgroundColor: AppColors.surfaceElevated,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeginnerNutritionCard(ClientThemeColors colors, DailyMacroSummary dailySummary) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colors.isDark ? 0.35 : 0.04),
            blurRadius: 14,
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.primaryRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.restaurant_rounded, color: colors.primaryRed, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "TODAY'S NUTRITION",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$calConsumed / $calTarget kcal',
                style: GoogleFonts.poppins(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: dailySummary.calorieProgress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colors.isDark ? const Color(0xFF262626) : colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primaryRed),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMacroMiniTile(
                  label: 'PROTEIN',
                  current: protConsumed,
                  target: protTarget,
                  unit: 'g',
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroMiniTile(
                  label: 'CARBS',
                  current: carbsConsumed,
                  target: carbsTarget,
                  unit: 'g',
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroMiniTile(
                  label: 'FATS',
                  current: fatConsumed,
                  target: fatTarget,
                  unit: 'g',
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isCalOver
                ? '+${dailySummary.overCalories.round()} kcal over daily target'
                : '${dailySummary.safeRemainingCalories.round()} kcal remaining today',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCalOver ? colors.primaryRed : colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text(
                      'LOG FOOD',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () {
                      AlphaXHaptics.tap();
                      AddFoodBottomSheet.show(
                        context,
                        repository: widget.macroRepository,
                        mealType: MealType.snack,
                        dateString: widget.macroRepository.getTodayDateString(),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.isDark ? const Color(0xFF1E1E1E) : colors.surfaceElevated,
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.pie_chart_outline_rounded, size: 16, color: colors.primaryRed),
                    label: const Text(
                      'VIEW MACROS',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    onPressed: () {
                      AlphaXHaptics.selection();
                      _selectTab(3);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMiniTile({
    required String label,
    required String current,
    required String target,
    required String unit,
    required ClientThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF1E1E1E) : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: colors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$current/$target$unit',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBeginnerProgressCard(ClientThemeColors colors, List<WorkoutRecord> history) {
    final status = _weeklyProgressRepository.currentStatus;
    final isAvailable = status?.isAvailable ?? true;
    final weekNum = status?.currentWeekNumber ?? 1;
    final weightVal = AuthService().clientProfile['weightKg'];
    final weightStr = weightVal != null && (weightVal as num) > 0 ? '$weightVal kg' : '-- kg';
    final stepsStr = widget.activityRepository.todayRecord.formattedSteps;
    final stepsGoal = widget.activityRepository.todayRecord.formattedGoal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colors.isDark ? 0.35 : 0.04),
            blurRadius: 14,
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.primaryRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.trending_up_rounded, color: colors.primaryRed, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "PROGRESS & CHECK-IN",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAvailable ? AppColors.success : colors.textSecondary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isAvailable ? AppColors.success : colors.textSecondary).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  isAvailable ? 'WEEK $weekNum READY' : 'WEEK $weekNum LOGGED',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: isAvailable ? AppColors.success : colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildProgressStatItem(
                  label: 'BODY WEIGHT',
                  value: weightStr,
                  icon: Icons.monitor_weight_outlined,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProgressStatItem(
                  label: 'TODAY STEPS',
                  value: '$stepsStr / $stepsGoal',
                  icon: Icons.directions_walk_rounded,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProgressStatItem(
                  label: 'SESSIONS',
                  value: '${history.length} Done',
                  icon: Icons.check_circle_outline_rounded,
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isAvailable
                ? 'Your Week $weekNum progress review is open. Complete check-in for your coach review.'
                : 'Next check-in unlocks next week. Keep logging workouts and meals consistently!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: colors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? colors.primaryRed : (colors.isDark ? const Color(0xFF1E1E1E) : colors.surfaceElevated),
                foregroundColor: isAvailable ? Colors.white : colors.textPrimary,
                elevation: 0,
                side: isAvailable ? BorderSide.none : BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(
                isAvailable ? Icons.event_available_rounded : Icons.insights_rounded,
                size: 18,
                color: isAvailable ? Colors.white : colors.primaryRed,
              ),
              label: Text(
                isAvailable ? 'START WEEK $weekNum CHECK-IN' : 'VIEW PROGRESS SUMMARY',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: () => _openProgressSubPage(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStatItem({
    required String label,
    required String value,
    required IconData icon,
    required ClientThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF1E1E1E) : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: colors.primaryRed),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: colors.textTertiary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
    final greetingPrefix = currentHour < 12
        ? 'GOOD MORNING'
        : (currentHour < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING');

    final colors = ClientThemeColors(context);

    return RefreshIndicator(
      color: colors.primaryRed,
      backgroundColor: colors.surfaceElevated,
      onRefresh: () async {
        await AppAutoRefreshService.instance.triggerImmediateSync(
          reason: 'Client Dashboard pull-to-refresh',
          force: true,
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. User Header & Membership ID
          AlphaXSubtleEntrance(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.primaryRed, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primaryRed.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: colors.surfaceElevated,
                        child: Text(
                          firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: colors.primaryRed,
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
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.background, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$greetingPrefix, ${firstName.toUpperCase()}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'What do you want to accomplish today?',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primaryRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.primaryRed.withOpacity(0.4), width: 1),
                  ),
                  child: Text(
                    AuthService().currentClientId,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: colors.primaryRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Clear Section Header: TODAY'S PLAN
          AlphaXSubtleEntrance(
            delay: const Duration(milliseconds: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TODAY'S PLAN",
                  style: GoogleFonts.poppins(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '3 Daily Focus Areas',
                  style: GoogleFonts.poppins(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. 🏋️ Section 1: Workout Card
          AlphaXSubtleEntrance(
            delay: const Duration(milliseconds: 50),
            child: _buildBeginnerWorkoutCard(colors, recommended),
          ),
          const SizedBox(height: 14),

          // 4. 🍽️ Section 2: Nutrition Card
          AlphaXSubtleEntrance(
            delay: const Duration(milliseconds: 70),
            child: _buildBeginnerNutritionCard(colors, dailySummary),
          ),
          const SizedBox(height: 14),

          // 5. 📈 Section 3: Progress Card
          AlphaXSubtleEntrance(
            delay: const Duration(milliseconds: 90),
            child: _buildBeginnerProgressCard(colors, history),
          ),
          const SizedBox(height: 20),

          // 6. Secondary Navigation: MY ATHLETE PORTAL
          AlphaXSubtleEntrance(
            delay: const Duration(milliseconds: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AlphaXSectionHeader(title: 'MY ATHLETE PORTAL'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _clientSectionChip('MY WORKOUT', Icons.fitness_center, () => _selectTab(1)),
                    _clientSectionChip('EXERCISE LIBRARY', Icons.format_list_bulleted_rounded, () => _selectTab(2)),
                    _clientSectionChip('NUTRITION & MACROS', Icons.restaurant_menu, () => _selectTab(3)),
                    _clientSectionChip('FOOD PHOTOS', Icons.camera_alt, () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyFoodPhotosScreen()),
                      );
                    }),
                    _clientSectionChip('DAILY STEPS', Icons.directions_walk, () => _selectTab(4)),
                    _clientSectionChip('MY PROGRESS', Icons.auto_graph, () => _openProgressSubPage(context)),
                    _clientSectionChip('MY PROFILE', Icons.person, () => _openProfileSubPage(context)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 7. Recent Sessions (only when history is available)
          if (history.isNotEmpty) ...[
            AlphaXSubtleEntrance(
              delay: const Duration(milliseconds: 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlphaXSectionHeader(
                    title: 'RECENT SESSIONS',
                    actionLabel: 'View All',
                    onActionTap: () => _selectTab(1),
                  ),
                  const SizedBox(height: 8),
                  ...history.take(2).map((r) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: colors.primaryRed.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_rounded, color: colors.primaryRed, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r.sessionTitle,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${r.durationDisplay} • ${r.totalVolume.toInt()} kg',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  void _openProgressSubPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientWeeklyProgressScreen(
          repository: _weeklyProgressRepository,
          workoutRepository: widget.workoutRepository,
          activityRepository: widget.activityRepository,
        ),
      ),
    );
  }


  void _openProfileSubPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientProfileSubScreen(workoutRepository: widget.workoutRepository),
      ),
    );
  }

  Widget _clientSectionChip(String label, IconData icon, VoidCallback onTap, {bool isSelected = false}) {
    final colors = ClientThemeColors(context);
    return AlphaXPressable(
      onTap: () {
        AlphaXHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryRed : colors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? colors.primaryRed : colors.border,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primaryRed.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.onPrimary : colors.primaryRed,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isSelected ? AppColors.onPrimary : colors.textPrimary,
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

class ClientProfileSubScreen extends StatelessWidget {
  final WorkoutRepository workoutRepository;

  const ClientProfileSubScreen({super.key, required this.workoutRepository});

  @override
  Widget build(BuildContext context) {
    final themeService = ClientThemeService();
    final colors = ClientThemeColors.of(context);
    final userName = AuthService().currentUserName;
    final userEmail = AuthService().currentUserEmail;
    final userId = AuthService().currentUserId;
    final clientProfile = AuthService().clientProfile;
    final completedWorkoutsCount = workoutRepository.clientHistory.length;

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final currentMode = themeService.themeMode;
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            iconTheme: IconThemeData(color: colors.textPrimary),
            title: Text(
              'ATHLETE PROFILE',
              style: TextStyle(
                color: colors.textPrimary,
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
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AlphaXLogo(size: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: colors.primaryRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: colors.primaryRed.withOpacity(0.4)),
                          ),
                          child: Text(
                            'ATHLETE MEMBER',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: colors.primaryRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.primaryRed, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primaryRed.withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: colors.primaryRed,
                        child: Text(
                          userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'A',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      userName.isNotEmpty ? userName : 'Alpha X Athlete',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        'Client ID: $userId',
                        style: TextStyle(color: colors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(color: colors.border, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _profileMetric('COMPLETED WORKOUTS', '$completedWorkoutsCount', Icons.fitness_center, colors),
                        Container(height: 32, width: 1, color: colors.border),
                        _profileMetric(
                          'START WEIGHT',
                          clientProfile['weightKg'] != null ? '${clientProfile['weightKg']} KG' : 'N/A',
                          Icons.monitor_weight_outlined,
                          colors,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Achievement Badges (Next-Level Delight)
              const AlphaXSectionHeader(title: 'ATHLETE TROPHIES & BADGES'),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.88,
                children: [
                  _buildAchievementBadge(
                    context,
                    'FIRST BLOOD',
                    '1st Session Done',
                    Icons.military_tech_rounded,
                    true,
                    colors,
                  ),
                  _buildAchievementBadge(
                    context,
                    '12-DAY STREAK',
                    'Active Habit',
                    Icons.local_fire_department_rounded,
                    true,
                    colors,
                  ),
                  _buildAchievementBadge(
                    context,
                    'MACRO SNIPER',
                    'Target Met',
                    Icons.track_changes_rounded,
                    true,
                    colors,
                  ),
                  _buildAchievementBadge(
                    context,
                    'CENTURION',
                    '100 Workouts',
                    Icons.workspace_premium_rounded,
                    false,
                    colors,
                  ),
                  _buildAchievementBadge(
                    context,
                    'IRON MASTER',
                    '5,000 kg Volume',
                    Icons.fitness_center_rounded,
                    false,
                    colors,
                  ),
                  _buildAchievementBadge(
                    context,
                    'EARLY BIRD',
                    '6 AM Session',
                    Icons.alarm_on_rounded,
                    true,
                    colors,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section: Appearance Settings
              const AlphaXSectionHeader(title: 'APPEARANCE'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 20, color: colors.primaryRed),
                        const SizedBox(width: 8),
                        Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildThemeRadioRow(
                      title: 'Light Mode',
                      subtitle: 'Clean, bright interface with crisp contrast',
                      icon: Icons.wb_sunny_rounded,
                      selected: currentMode == ClientThemeMode.light,
                      onTap: () => themeService.setThemeMode(ClientThemeMode.light),
                      colors: colors,
                    ),
                    Divider(color: colors.border, height: 16),
                    _buildThemeRadioRow(
                      title: 'Dark Mode',
                      subtitle: 'Classic Alpha X sleek dark appearance',
                      icon: Icons.nightlight_round,
                      selected: currentMode == ClientThemeMode.dark,
                      onTap: () => themeService.setThemeMode(ClientThemeMode.dark),
                      colors: colors,
                    ),
                    Divider(color: colors.border, height: 16),
                    _buildThemeRadioRow(
                      title: 'System Default',
                      subtitle: 'Automatically follow device appearance setting',
                      icon: Icons.settings_brightness_rounded,
                      selected: currentMode == ClientThemeMode.system,
                      onTap: () => themeService.setThemeMode(ClientThemeMode.system),
                      colors: colors,
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
                    color: colors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Primary Goal', clientProfile['fitnessGoal'] ?? clientProfile['goal'] ?? 'Not set', colors),
                      Divider(color: colors.border, height: 16),
                      _infoRow('Experience Level', clientProfile['experienceLevel'] ?? clientProfile['level'] ?? 'Not set', colors),
                      Divider(color: colors.border, height: 16),
                      _infoRow('Activity Level', clientProfile['activityLevel'] ?? 'Moderate', colors),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Sign Out Action
              ListTile(
                tileColor: colors.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.border),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.logout, color: colors.primaryRed, size: 20),
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(color: colors.primaryRed, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                subtitle: Text(
                  'Log out of your Alpha X Gym athlete account',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: colors.textTertiary),
                onTap: () {
                  AuthService().logout();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildThemeRadioRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ClientThemeColors colors,
  }) {
    return InkWell(
      onTap: () {
        AlphaXHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? colors.primaryRed.withOpacity(0.12) : colors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: selected ? colors.primaryRed : colors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? colors.primaryRed : colors.textPrimary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colors.primaryRed : colors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAchievementBadge(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool isUnlocked,
    ClientThemeColors colors,
  ) {
    final limeColor = colors.primaryRed;
    return AlphaXPressable(
      onTap: () {
        if (isUnlocked) {
          AlphaXHaptics.celebrate();
          AlphaXCelebrationBurst.show(context);
        } else {
          AlphaXHaptics.tap();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isUnlocked ? limeColor.withOpacity(0.08) : colors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUnlocked ? limeColor.withOpacity(0.55) : colors.border,
            width: isUnlocked ? 1.5 : 1.0,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: limeColor.withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked ? limeColor.withOpacity(0.18) : colors.surfaceElevated,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isUnlocked ? limeColor : colors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isUnlocked ? colors.textPrimary : colors.textTertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: isUnlocked ? limeColor : colors.textTertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileMetric(String label, String value, IconData icon, ClientThemeColors colors) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: colors.primaryRed),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: colors.textTertiary,
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
          style: TextStyle(
            fontFamily: 'Poppins',
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, dynamic value, ClientThemeColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(
          value.toString(),
          style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

