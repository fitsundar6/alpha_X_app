import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_sessions_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_create_edit_session_screen.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_widgets.dart';
import 'package:alpha_x_gym/features/exercise/presentation/admin/admin_exercise_database_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_change_requests_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_performance_dashboard_screen.dart';
import 'package:alpha_x_gym/core/widgets/server_config_dialog.dart';
import 'package:alpha_x_gym/features/dashboard/admin_client_nutrition_screen.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/admin_weekly_progress_screen.dart';
import 'package:alpha_x_gym/features/food_photo_tracking/presentation/screens/admin_food_photos_monitoring_screen.dart';
import 'package:alpha_x_gym/features/dashboard/widgets/admin_attention_center_view.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/admin_ai_coach_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/features/dashboard/admin_client_verification_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_x_gym/features/dashboard/admin_client_detail_screen.dart';
import 'package:alpha_x_gym/features/dashboard/admin_create_edit_diet_plan_screen.dart';
import 'package:alpha_x_gym/features/macro_planner/data/food_database.dart';

class AdminMainDashboardScreen extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final ActivityRepository activityRepository;
  final MacroRepository macroRepository;
  final WeeklyProgressRepository? weeklyProgressRepository;

  const AdminMainDashboardScreen({
    super.key,
    required this.workoutRepository,
    required this.activityRepository,
    required this.macroRepository,
    this.weeklyProgressRepository,
  });

  @override
  State<AdminMainDashboardScreen> createState() => _AdminMainDashboardScreenState();
}

class _AdminMainDashboardScreenState extends State<AdminMainDashboardScreen> {
  int _selectedIndex = 0;
  final List<int> _tabHistory = [0];
  DateTime? _lastBackPressTime;
  double? _dragStartX;
  bool _isLoadingClients = false;
  String? _clientsError;
  late final WeeklyProgressRepository _weeklyProgressRepo;
  late final AiCoachRepository _aiCoachRepo;
  late final Future<AiDailySummary> _aiSummaryFuture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _clientSearchController = TextEditingController();
  String _clientSearchQuery = '';
  int _pendingVerificationCount = 0;

  final List<String> _tabTitles = [
    '🤖 AI COACH',
    '👥 CLIENTS',
    '🏋️ WORKOUT COMMAND',
    '🥗 MACRO & DIET',
    '⚙️ SETTINGS',
    '📈 WEEKLY PROGRESS',
    '⚠️ CLIENT ATTENTION',
    '📸 CLIENT FOOD PHOTOS',
    '🛡️ USERS & VERIFICATION',
    '🏠 FACILITY OVERVIEW',
  ];

  @override
  void initState() {
    super.initState();
    _weeklyProgressRepo = widget.weeklyProgressRepository ?? WeeklyProgressRepository();
    _aiCoachRepo = AiCoachRepository();
    // Memoize the future so it is only created once — not on every rebuild.
    // Calling getDailySummary() directly inside build() would spawn a new HTTP
    // request on every setState(), causing repeated AI_SERVICE_UNAVAILABLE logs.
    _aiSummaryFuture = _aiCoachRepo.getDailySummary();
    _loadClients();
    _loadVerificationMetrics();
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadVerificationMetrics() async {
    try {
      final token = await AuthService().getValidToken();
      if (token.isEmpty) return;
      final res = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/admin/verification/metrics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          if (mounted) {
            setState(() {
              _pendingVerificationCount = (decoded['data']['pending'] as num?)?.toInt() ?? 0;
            });
          }
        }
      }
    } catch (_) {}
  }

  /// Select an admin tab and record it in history for back-gesture support.
  void _selectAdminTab(int idx) {
    if (_selectedIndex != idx) {
      setState(() {
        _selectedIndex = idx;
        if (_tabHistory.isEmpty || _tabHistory.last != idx) {
          _tabHistory.add(idx);
        }
      });
      if (idx == 1) {
        _loadClients(forceRefresh: true);
      }
      if (idx == 0 || idx == 8) {
        _loadVerificationMetrics();
      }
    }
  }

  /// Handles Android back gesture inside the admin dashboard.
  /// Steps back through tab history, or shows a double-back exit prompt.
  bool _navigateBack() {
    // 1. Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
      return true;
    }

    // 2. Step back through tab history
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _selectedIndex = _tabHistory.last;
      });
      return true;
    }

    // 3. If on a non-home tab, return to Dashboard (tab 0)
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
        _tabHistory
          ..clear()
          ..add(0);
      });
      return true;
    }

    // At root — caller will handle double-back exit
    return false;
  }

  Future<void> _loadClients({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingClients = true;
      _clientsError = null;
    });
    try {
      await widget.workoutRepository.fetchClientsList(forceRefresh: forceRefresh);
    } catch (e) {
      if (mounted) {
        setState(() {
          _clientsError = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingClients = false;
        });
      }
    }
  }

  String _formatJoinDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_navigateBack()) return;

        // Double-back to exit protection at root Dashboard tab
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2, milliseconds: 500)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Press back again to exit Admin Panel',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          );
          return;
        }
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
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Row(
          children: [
            const AlphaXLogo.appBar(size: 28),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ADMIN',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedIndex < _tabTitles.length
                    ? _tabTitles[_selectedIndex]
                    : 'ALPHA X ADMIN',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoadingClients
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                  )
                : Icon(Icons.refresh, size: 20, color: colors.textSecondary),
            tooltip: 'Refresh Clients',
            onPressed: _isLoadingClients ? null : () => _loadClients(forceRefresh: true),
          ),
          IconButton(
            icon: Icon(Icons.logout, size: 20, color: colors.textSecondary),
            tooltip: 'Logout',
            onPressed: () {
              AuthService().logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      drawer: _buildAdminDrawer(colors),
      body: _buildCurrentTab(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border, width: 1)),
          color: colors.surfaceCard,
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex > 3 ? 0 : _selectedIndex,
          onDestinationSelected: _selectAdminTab,
          backgroundColor: colors.surfaceCard,
          indicatorColor: colors.glow,
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined, color: colors.textSecondary),
              selectedIcon: Icon(Icons.smart_toy, color: colors.primary),
              label: 'AI Coach',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined, color: colors.textSecondary),
              selectedIcon: Icon(Icons.groups, color: colors.primary),
              label: 'Clients',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined, color: colors.textSecondary),
              selectedIcon: Icon(Icons.fitness_center, color: colors.primary),
              label: 'Workout',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined, color: colors.textSecondary),
              selectedIcon: Icon(Icons.restaurant_menu, color: colors.primary),
              label: 'Macro / Diet',
            ),
          ],
        ),
      ),
      ),
    ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return AdminAiCoachScreen(
          aiCoachRepository: _aiCoachRepo,
          workoutRepository: widget.workoutRepository,
          macroRepository: widget.macroRepository,
          showAppBar: false,
        );
      case 1:
        return _buildClientsTab();
      case 2:
        return _buildWorkoutCommandTab();
      case 3:
        return _buildMacroDietCommandTab();
      case 4:
        return _buildSettingsTab();
      case 5:
        return AdminWeeklyProgressScreen(repository: _weeklyProgressRepo);
      case 6:
        return const AdminAttentionCenterView();
      case 7:
        return const AdminFoodPhotosMonitoringScreen(showAppBar: false);
      case 8:
        return const AdminClientVerificationScreen(showAppBar: false);
      case 9:
        return _buildAdminHomeTab();
      default:
        return _buildClientsTab();
    }
  }

  Widget _buildAdminDrawer(ClientThemeColors colors) {
    return Drawer(
      backgroundColor: colors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colors.surfaceCard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const AlphaXLogo(size: 38),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ALPHA X GYM', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('ADMIN CONTROL PANEL', style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Logged in: ${AuthService().currentUserName}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          _drawerItem(0, 'Dashboard', Icons.dashboard_outlined, colors),
          ListTile(
            leading: const Text('🤖', style: TextStyle(fontSize: 20)),
            title: Text('Alpha X AI Coach', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
            subtitle: Text('Master Intelligence Controller', style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AdminAiCoachScreen(
                    aiCoachRepository: _aiCoachRepo,
                    workoutRepository: widget.workoutRepository,
                    macroRepository: widget.macroRepository,
                  ),
                ),
              );
            },
          ),
          _drawerItem(1, 'Clients', Icons.groups_outlined, colors),
          ListTile(
            leading: Icon(
              Icons.verified_user_outlined,
              color: _pendingVerificationCount > 0 ? const Color(0xFFF59E0B) : colors.textSecondary,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Users & Verification',
                    style: TextStyle(
                      color: _selectedIndex == 8 ? colors.primary : colors.textPrimary,
                      fontWeight: _selectedIndex == 8 ? FontWeight.w800 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_pendingVerificationCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_pendingVerificationCount PENDING',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              _pendingVerificationCount > 0
                  ? '$_pendingVerificationCount new users awaiting approval'
                  : 'Manage approvals & account statuses',
              style: TextStyle(
                color: _pendingVerificationCount > 0 ? const Color(0xFFF59E0B) : colors.textSecondary,
                fontSize: 10,
              ),
            ),
            selected: _selectedIndex == 8,
            onTap: () {
              Navigator.of(context).pop();
              _selectAdminTab(8);
            },
          ),
          _drawerItem(2, 'Workout Sessions', Icons.fitness_center_outlined, colors),
          ListTile(
            leading: Icon(Icons.storage_outlined, color: colors.textSecondary),
            title: Text('Exercise Database', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AdminExerciseDatabaseScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.swap_calls_outlined, color: colors.textSecondary),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Change Requests',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.workoutRepository.changeRequests.where((r) => r.isPending).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${widget.workoutRepository.changeRequests.where((r) => r.isPending).length}',
                      style: TextStyle(color: colors.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AdminChangeRequestsScreen(workoutRepository: widget.workoutRepository),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.analytics_outlined, color: colors.textSecondary),
            title: Text('Athlete Performance', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AdminPerformanceDashboardScreen(workoutRepository: widget.workoutRepository),
                ),
              );
            },
          ),
          _drawerItem(3, 'Assignments', Icons.calendar_month_outlined, colors),
          _drawerItem(4, 'Settings', Icons.settings_outlined, colors),
          _drawerItem(5, 'Weekly Progress', Icons.insights_rounded, colors),
          _drawerItem(6, 'Client Attention', Icons.warning_amber_rounded, colors),
          _drawerItem(7, 'Client Food Photos', Icons.camera_alt_outlined, colors),
          Divider(color: colors.border),
          ListTile(
            leading: Icon(Icons.logout, color: colors.primary),
            title: Text('Sign Out', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
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

  Widget _drawerItem(int index, String title, IconData icon, ClientThemeColors colors) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? colors.primary : colors.textSecondary),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? colors.primary : colors.textPrimary,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onTap: () {
        _selectAdminTab(index);
        Navigator.of(context).pop();
      },
    );
  }

  // --- TAB 0: 🏠 DASHBOARD OVERVIEW ---
  Widget _buildAdminHomeTab() {
    final sessions = widget.workoutRepository.adminSessions;
    final clients = widget.workoutRepository.clientsList;
    final assignments = widget.workoutRepository.assignments;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_pendingVerificationCount > 0) ...[
          AlphaXSubtleEntrance(
            child: InkWell(
              onTap: () => _selectAdminTab(8),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withOpacity(0.20),
                      const Color(0xFFB45309).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.7), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1, color: Color(0xFFF59E0B), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'NEW USERS PENDING VERIFICATION',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_pendingVerificationCount',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_pendingVerificationCount ${_pendingVerificationCount == 1 ? "client has" : "clients have"} joined and ${_pendingVerificationCount == 1 ? "is" : "are"} waiting for verification.',
                            style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Color(0xFFF59E0B), size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Operational Header Banner
        AlphaXSubtleEntrance(
          child: AlphaXCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AlphaXColors.redAccent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.shield_outlined, color: AlphaXColors.redAccent, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FACILITY COMMAND CENTER',
                            style: TextStyle(
                              color: AlphaXColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'ALPHA X PERFORMANCE ARCHITECTURE',
                            style: TextStyle(
                              color: AlphaXColors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prescribe elite workout sessions, configure superset programming, manage athlete roster, and track transformation progress in real time.',
                  style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 🤖 ALPHA X AI COACH Summary Card
        AlphaXSubtleEntrance(
          delay: const Duration(milliseconds: 50),
          child: _buildAiCoachDashboardCard(),
        ),
        const SizedBox(height: 20),

        // Section Title: CORE GYM KPIs (6 Required Metrics)
        AlphaXSubtleEntrance(
          delay: const Duration(milliseconds: 70),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AlphaXSectionHeader(title: 'FACILITY PERFORMANCE METRICS'),
              const SizedBox(height: 12),

              // Grid of 6 KPIs
              Row(
                children: [
                  Expanded(
                    child: AlphaXStatCard(
                      label: 'TOTAL CLIENTS',
                      value: '${clients.length}',
                      subtext: '${assignments.length} assigned programs',
                      icon: Icons.groups_outlined,
                      accentColor: AlphaXColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AlphaXStatCard(
                      label: 'ACTIVE MEMBERS',
                      value: '${clients.length}',
                      subtext: clients.isEmpty ? '0 active athletes' : '100% database verified',
                      icon: Icons.check_circle_outline,
                      accentColor: AlphaXColors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final engagementRate = clients.isEmpty
                            ? 0
                            : ((clients.where((c) => assignments.any((a) => a.clientId == c['id'])).length / clients.length) * 100).round();
                        return AlphaXStatCard(
                          label: 'ATHLETE ENGAGEMENT',
                          value: '$engagementRate%',
                          subtext: clients.isEmpty ? '0 active athletes' : 'Active training roster',
                          icon: Icons.trending_up,
                          accentColor: AlphaXColors.textPrimary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final history = widget.workoutRepository.workoutHistory;
                        final completed = history.where((r) => r.isCompleted).length;
                        final total = history.length;
                        final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;
                        return AlphaXStatCard(
                          label: 'WORKOUT COMPLETION',
                          value: '$completionRate%',
                          subtext: total > 0 ? '$completed of $total completed' : 'No workout sessions yet',
                          icon: Icons.fitness_center_outlined,
                          accentColor: AlphaXColors.redAccent,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AlphaXStatCard(
                      label: 'WORKOUT SESSIONS',
                      value: '${sessions.length}',
                      subtext: sessions.isEmpty ? 'No created sessions' : '${sessions.length} library routines',
                      icon: Icons.fitness_center_outlined,
                      accentColor: AlphaXColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AlphaXStatCard(
                      label: 'ASSIGNED PLANS',
                      value: '${assignments.length}',
                      subtext: assignments.isEmpty ? 'No active plans' : '${assignments.length} assigned routines',
                      icon: Icons.calendar_month_outlined,
                      accentColor: AlphaXColors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title: QUICK MANAGEMENT ACTIONS
        const AlphaXSectionHeader(title: 'ATHLETE & SYSTEM CONTROLS'),
        const SizedBox(height: 12),

        // Quick Actions Grid (9 Actions)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _adminActionChip('Alpha X AI Coach', Icons.smart_toy_outlined, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AdminAiCoachScreen(
                    aiCoachRepository: _aiCoachRepo,
                    workoutRepository: widget.workoutRepository,
                    macroRepository: widget.macroRepository,
                  ),
                ),
              );
            }),
            _adminActionChip('New Workout Session', Icons.add_circle_outline, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AdminCreateEditSessionScreen(
                    workoutRepository: widget.workoutRepository,
                  ),
                ),
              );
            }),
            _adminActionChip('Exercise Database', Icons.storage_outlined, () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AdminExerciseDatabaseScreen()),
              );
            }),
            _adminActionChip('Change Requests', Icons.swap_calls_outlined, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AdminChangeRequestsScreen(workoutRepository: widget.workoutRepository),
                ),
              );
            }),
            _adminActionChip('Athlete Performance', Icons.analytics_outlined, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AdminPerformanceDashboardScreen(workoutRepository: widget.workoutRepository),
                ),
              );
            }),
            _adminActionChip('Client Food Photos', Icons.camera_alt_outlined, () {
              _selectAdminTab(7);
            }),
            _adminActionChip(
              _pendingVerificationCount > 0
                  ? 'Verification ($_pendingVerificationCount)'
                  : 'Client Verification',
              Icons.verified_user_outlined,
              () => _selectAdminTab(8),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Prescribed Sessions Overview
        AlphaXSectionHeader(
          title: 'CURRENT PRESCRIBED SESSIONS',
          actionLabel: 'CREATE NEW',
          onActionTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => AdminCreateEditSessionScreen(
                  workoutRepository: widget.workoutRepository,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        ...sessions.take(3).map((session) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AlphaXCard(
              padding: const EdgeInsets.all(14),
              onTap: () => _selectAdminTab(2),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AlphaXColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.fitness_center, color: AlphaXColors.redAccent, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: const TextStyle(
                            color: AlphaXColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${session.targetMuscleGroup.toUpperCase()} • ${session.exercises.length} exercises • ~${session.estimatedDurationMinutes}m',
                          style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AlphaXColors.textSecondary),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAiCoachDashboardCard() {
    return FutureBuilder<AiDailySummary>(
      future: _aiSummaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? AiDailySummary.fallback();

        return AlphaXCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryRed, width: 1.5),
                    ),
                    child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALPHA X AI COACH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          "Today's AI Summary",
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.statusGreen.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: AppColors.statusGreen, size: 12),
                        const SizedBox(width: 4),
                        const Text(
                          'ONLINE',
                          style: TextStyle(color: AppColors.statusGreen, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Metrics
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _aiSummaryRow(Icons.fitness_center, '${summary.workoutsCompleted} workouts completed today', AppColors.statusGreen),
                    const SizedBox(height: 8),
                    _aiSummaryRow(Icons.restaurant, '${summary.foodLogsRecorded} food logs recorded', Colors.amber),
                    const SizedBox(height: 8),
                    _aiSummaryRow(Icons.assignment_outlined, '${summary.weeklyCheckInsPending} weekly check-ins pending', Colors.lightBlueAccent),
                    const SizedBox(height: 8),
                    _aiSummaryRow(Icons.warning_amber_rounded, '${summary.clientsNeedReview} clients need review', AppColors.primaryRed),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                  label: const Text(
                    'Open AI Coach',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => AdminAiCoachScreen(
                          aiCoachRepository: _aiCoachRepo,
                          workoutRepository: widget.workoutRepository,
                          macroRepository: widget.macroRepository,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _aiSummaryRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }


  Widget _adminActionChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AlphaXColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AlphaXColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AlphaXColors.redAccent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AlphaXColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }



  // --- TAB 1: 👥 CLIENTS TAB ---
  Widget _buildClientsTab() {
    final clients = widget.workoutRepository.clientsList;
    final activeCount = clients.where((c) => c['onboardingCompleted'] == 'true').length;
    final pendingCount = clients.length - activeCount;

    final filteredClients = _clientSearchQuery.trim().isEmpty
        ? clients
        : clients.where((c) {
            final query = _clientSearchQuery.trim().toLowerCase();
            final name = (c['name'] ?? '').toString().toLowerCase();
            final email = (c['email'] ?? '').toString().toLowerCase();
            final cid = (c['clientId'] ?? c['id'] ?? '').toString().toLowerCase();
            return name.contains(query) || email.contains(query) || cid.contains(query);
          }).toList();

    return RefreshIndicator(
      color: AppColors.primaryRed,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () => _loadClients(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Category Filter Pills (Mockup Screen 8)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAdminCategoryPill(
                  title: 'Clients',
                  isSelected: true,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _buildAdminCategoryPill(
                  title: 'Workouts',
                  isSelected: false,
                  onTap: () => _selectAdminTab(2),
                ),
                const SizedBox(width: 8),
                _buildAdminCategoryPill(
                  title: 'Diet Plans',
                  isSelected: false,
                  onTap: () => _selectAdminTab(7),
                ),
                const SizedBox(width: 8),
                _buildAdminCategoryPill(
                  title: 'Reports',
                  isSelected: false,
                  onTap: () => _selectAdminTab(5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Summary Metrics Cards (Mockup Screen 8: Total Clients, Active, Pending)
          Row(
            children: [
              Expanded(
                child: _buildAdminSummaryMetricCard(
                  label: 'Total Clients',
                  value: '${clients.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdminSummaryMetricCard(
                  label: 'Active',
                  value: '$activeCount',
                  indicatorColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdminSummaryMetricCard(
                  label: 'Pending',
                  value: '$pendingCount',
                  indicatorColor: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Search Bar (Mockup Screen 8)
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF242424)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _clientSearchController,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search clients...',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _clientSearchQuery = val;
                      });
                    },
                  ),
                ),
                if (_clientSearchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _clientSearchController.clear();
                      setState(() {
                        _clientSearchQuery = '';
                      });
                    },
                    child: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REGISTERED ATHLETES & CLIENTS (${filteredClients.length})',
                      style: GoogleFonts.poppins(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live roster synchronized with Alpha X Neon Cloud Database.',
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.primaryRed),
                tooltip: 'Refresh Roster',
                onPressed: _isLoadingClients ? null : () => _loadClients(forceRefresh: true),
              ),
            ],
          ),
          if (_clientsError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.primaryRed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sync notice: $_clientsError',
                      style: const TextStyle(color: AppColors.primaryRed, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _loadClients(forceRefresh: true),
                    child: const Text('RETRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
          if (_isLoadingClients && clients.isEmpty) ...[
            const SizedBox(height: 60),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primaryRed),
                  SizedBox(height: 16),
                  Text(
                    'Loading registered clients from database...',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else if (clients.isEmpty) ...[
            const SizedBox(height: 50),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'No Clients Yet',
                      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'New clients will appear here after registration.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                      label: const Text('REFRESH ROSTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () => _loadClients(forceRefresh: true),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (filteredClients.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 44, color: AppColors.textTertiary),
                    const SizedBox(height: 10),
                    Text(
                      'No Matching Clients',
                      style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No athletes match "$_clientSearchQuery"',
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () {
                        _clientSearchController.clear();
                        setState(() => _clientSearchQuery = '');
                      },
                      child: const Text('Clear Search', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            ...filteredClients.map((client) {
              final clientId = client['id'] ?? '';
              final joinDate = _formatJoinDate(client['createdAt']);
              final displayClientId = client['clientId'] ?? clientId;
              final isOnboarded = client['onboardingCompleted'] == 'true';
              final photoUrl = client['photoUrl'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryRed,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(
                            (client['name'] ?? 'A').isNotEmpty ? (client['name'] ?? 'A').substring(0, 1).toUpperCase() : 'A',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          client['name'] ?? 'Athlete',
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isOnboarded ? AppColors.success : Colors.orangeAccent).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isOnboarded ? AppColors.success : Colors.orangeAccent, width: 0.8),
                        ),
                        child: Text(
                          isOnboarded ? 'Active' : 'Pending',
                          style: GoogleFonts.poppins(
                            color: isOnboarded ? AppColors.success : Colors.orangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displayClientId,
                            style: const TextStyle(
                              color: AppColors.primaryRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            client['email'] ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        joinDate,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
                    ],
                  ),
                  onTap: () => _showClientProfileModal(context, client),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminCategoryPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFF282828),
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: isSelected ? const Color(0xFF0A0A0A) : Colors.white,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSummaryMetricCard({
    required String label,
    required String value,
    Color? indicatorColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (indicatorColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the Complete Client Detail Screen (Profile, Workout, Nutrition) for Master Admin.
  void _showClientProfileModal(BuildContext context, Map<String, dynamic> client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminClientDetailScreen(
          client: client,
          workoutRepository: widget.workoutRepository,
          macroRepository: widget.macroRepository,
          activityRepository: widget.activityRepository,
          weeklyProgressRepository: _weeklyProgressRepo,
          initialTabIndex: 0,
        ),
      ),
    );
  }

  // --- TAB 2: 🏋️ WORKOUT COMMAND TAB ---
  Widget _buildWorkoutCommandTab() {
    final colors = ClientThemeColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: colors.surfaceCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: colors.textSecondary,
                      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(text: '🏋️ SESSIONS'),
                        Tab(text: '📅 ASSIGNMENTS'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('CREATE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminCreateEditSessionScreen(
                          workoutRepository: widget.workoutRepository,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                AdminWorkoutSessionsScreen(
                  workoutRepository: widget.workoutRepository,
                  showAppBar: false,
                ),
                _buildAssignmentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: 🥗 MACRO / DIET COMMAND TAB ---
  Widget _buildMacroDietCommandTab() {
    final colors = ClientThemeColors.of(context);
    final clients = widget.workoutRepository.clientsList;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: colors.surfaceCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: colors.textSecondary,
                      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11),
                      tabs: const [
                        Tab(text: '🥗 ATHLETES'),
                        Tab(text: '📖 FOOD LIBRARY'),
                        Tab(text: '📸 PHOTOS'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('NEW PLAN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showSelectClientForDietDialog(),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAthleteDietsSubTab(colors, clients),
                _buildFoodLibrarySubTab(colors),
                const AdminFoodPhotosMonitoringScreen(showAppBar: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSelectClientForDietDialog() {
    final clients = widget.workoutRepository.clientsList;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered clients available.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Athlete for Diet Plan',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('Choose a client to configure and assign their daily macros & meals:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (ctx, i) {
                    final c = clients[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryRed,
                        child: Text(
                          (c['name'] ?? 'A').isNotEmpty ? (c['name'] ?? 'A').substring(0, 1).toUpperCase() : 'A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(c['name'] ?? 'Athlete', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text('${c['clientId'] ?? c['id']} • Goal: ${c['primaryGoal'] ?? 'Fitness'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminCreateEditDietPlanScreen(
                              client: c,
                              macroRepository: widget.macroRepository,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAthleteDietsSubTab(ClientThemeColors colors, List<Map<String, dynamic>> clients) {
    if (clients.isEmpty) {
      return Center(
        child: Text('No clients found.', style: TextStyle(color: colors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clients.length,
      itemBuilder: (ctx, i) {
        final client = clients[i];
        final photoUrl = client['photoUrl']?.toString();
        final name = client['name']?.toString() ?? 'Athlete';
        final cid = client['clientId']?.toString() ?? client['id']?.toString() ?? '';
        final goal = client['primaryGoal']?.toString() ?? 'General Fitness';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.primary,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.poppins(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('$cid • Goal: $goal', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 18),
                    tooltip: 'Macro Options',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: colors.surfaceCard,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.tune, color: AppColors.primaryRed),
                                title: const Text('Quick Assign Macro Targets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showMacroTargetsDialog(context, client);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.playlist_add_check, color: AppColors.info),
                                title: const Text('Assign Saved Diet Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showAssignDietPlanDialog(context, client);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.restaurant, size: 14, color: AppColors.accentRed),
                      label: const Text('PRESCRIBE PLAN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminCreateEditDietPlanScreen(
                              client: client,
                              macroRepository: widget.macroRepository,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.lunch_dining, size: 14, color: Colors.white),
                      label: const Text('VIEW FOOD LOGS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminClientDetailScreen(
                              client: client,
                              workoutRepository: widget.workoutRepository,
                              macroRepository: widget.macroRepository,
                              activityRepository: widget.activityRepository,
                              weeklyProgressRepository: _weeklyProgressRepo,
                              initialTabIndex: 2, // Nutrition tab
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoodLibrarySubTab(ClientThemeColors colors) {
    final foods = FoodDatabase.defaultFoods;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: foods.length,
      itemBuilder: (ctx, i) {
        final f = foods[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: GoogleFonts.poppins(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${f.servingDisplay} • P:${f.protein.toInt()}g C:${f.carbs.toInt()}g F:${f.fat.toInt()}g Fib:${f.fiber.toInt()}g',
                      style: TextStyle(color: colors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${f.calories.toInt()} kcal',
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: 📅 ASSIGNMENTS TAB ---
  Widget _buildAssignmentsTab() {
    final assignments = widget.workoutRepository.assignments;
    final sessions = widget.workoutRepository.adminSessions;
    final clients = widget.workoutRepository.clientsList;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SESSION ASSIGNMENTS',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1),
            ),
            Text(
              '${assignments.length} Active',
              style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (assignments.isEmpty)
          const Center(child: Text('No active assignments', style: TextStyle(color: AppColors.textSecondary)))
        else
          ...assignments.map((assign) {
            final session = sessions.where((s) => s.id == assign.sessionId).firstOrNull;
            final client = clients.where((c) => c['id'] == assign.clientId).firstOrNull;
            final targetLabel = assign.clientId == null ? 'All Clients' : (client?['name'] ?? assign.clientId!);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: assign.isRecommended ? AppColors.primaryRed : AppColors.border,
                  width: assign.isRecommended ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (assign.isRecommended)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.glowRed,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.primaryRed, width: 0.6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 11, color: AppColors.gold),
                                    SizedBox(width: 4),
                                    Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            Text(
                              session?.title ?? 'Session',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.arrow_forward, size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              'Assigned to: $targetLabel',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                    tooltip: 'Unassign',
                    onPressed: () {
                      widget.workoutRepository.unassignSession(assign.sessionId, assign.clientId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unassigned from $targetLabel'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }


  void _showMacroTargetsDialog(BuildContext context, Map<String, dynamic> client) {
    final clientId = client['clientId'] ?? client['id'] ?? '';
    final clientName = client['name'] ?? 'Client';
    final calCtrl = TextEditingController(text: '2400');
    final proCtrl = TextEditingController(text: '175');
    final carbCtrl = TextEditingController(text: '240');
    final fatCtrl = TextEditingController(text: '70');
    final fiberCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('ASSIGN MACRO TARGETS ($clientName)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Client ID: $clientId', style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Daily Calories (kcal)', suffixText: 'kcal'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: proCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Protein (g)', suffixText: 'g'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: carbCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Carbohydrates (g)', suffixText: 'g'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fatCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Fat (g)', suffixText: 'g'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fiberCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Fiber (g)', suffixText: 'g'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () async {
              final cal = int.tryParse(calCtrl.text) ?? 2400;
              final p = double.tryParse(proCtrl.text) ?? 175.0;
              final c = double.tryParse(carbCtrl.text) ?? 240.0;
              final f = double.tryParse(fatCtrl.text) ?? 70.0;
              final fib = double.tryParse(fiberCtrl.text) ?? 30.0;

              Navigator.of(ctx).pop();
              await widget.workoutRepository.assignMacroPlanToClient(clientId, {
                'calories': cal,
                'protein': p,
                'carbs': c,
                'fat': f,
                'fiber': fib,
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Assigned macro targets for $clientName saved to database.'),
                    backgroundColor: AppColors.primaryRed,
                  ),
                );
              }
            },
            child: const Text('SAVE TARGETS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAssignDietPlanDialog(BuildContext context, Map<String, dynamic> client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminClientNutritionScreen(
          client: client,
          macroRepository: widget.macroRepository,
        ),
      ),
    );
  }

  // --- TAB 8: ⚙️ SETTINGS TAB ---
  Widget _buildSettingsTab() {
    final themeService = ClientThemeService();
    final colors = ClientThemeColors.of(context);
    final isDark = colors.isDark;

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final currentMode = themeService.themeMode;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'APPEARANCE',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
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
                      Icon(Icons.palette_outlined, size: 20, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Theme Mode',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildAdminThemeRadioRow(
                    title: 'Light Mode',
                    subtitle: 'Clean, bright interface with crisp contrast',
                    icon: Icons.wb_sunny_rounded,
                    selected: currentMode == ClientThemeMode.light,
                    onTap: () => themeService.setThemeMode(ClientThemeMode.light),
                    colors: colors,
                  ),
                  Divider(color: colors.border, height: 16),
                  _buildAdminThemeRadioRow(
                    title: 'Dark Mode',
                    subtitle: 'Classic Alpha X sleek dark appearance',
                    icon: Icons.nightlight_round,
                    selected: currentMode == ClientThemeMode.dark,
                    onTap: () => themeService.setThemeMode(ClientThemeMode.dark),
                    colors: colors,
                  ),
                  Divider(color: colors.border, height: 16),
                  _buildAdminThemeRadioRow(
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
            Text(
              'ADMINISTRATIVE PREFERENCES',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: colors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.border),
              ),
              leading: Icon(Icons.verified_user_outlined, color: colors.primary),
              title: Text(
                'Single Master Admin Authorized',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Backend verified email: ${AuthService().currentUserEmail}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: colors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.border),
              ),
              leading: Icon(Icons.security, color: colors.textSecondary),
              title: Text(
                'Security & RBAC Enforcement',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Admin Only • Strict Client Data Isolation Enforced',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: colors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.border),
              ),
              leading: Icon(Icons.cloud_sync_outlined, color: colors.primary),
              title: Text(
                'Backend API Server Endpoint',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                AppConstants.apiBaseUrl,
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              trailing: Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
              onTap: () async {
                await ServerConfigDialog.show(context);
                if (mounted) setState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminThemeRadioRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ClientThemeColors colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withOpacity(0.15)
                    : (colors.isDark ? AppColors.secondaryCard : AppColors.lightSecondaryCard),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? colors.primary : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? colors.primary : colors.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onTap(),
              activeColor: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}



class _AdminNotesEditor extends StatefulWidget {
  final String clientId;
  final String initialNote;
  final Future<bool> Function(String) onSave;
  final void Function(String) onNoteUpdated;

  const _AdminNotesEditor({
    required this.clientId,
    required this.initialNote,
    required this.onSave,
    required this.onNoteUpdated,
  });

  @override
  State<_AdminNotesEditor> createState() => _AdminNotesEditorState();
}

class _AdminNotesEditorState extends State<_AdminNotesEditor> {
  late final TextEditingController _notesCtrl;
  bool _isSavingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_person_outlined, size: 16, color: AppColors.primaryRed),
              SizedBox(width: 8),
              Text(
                '9. PRIVATE ADMIN / TRAINER NOTES (CONFIDENTIAL)',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Private notes are strictly visible to Master Admin only and never shared with the client.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. Focus on squat form first 4 weeks. Re-assess knee mobility after phase 1.',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: _isSavingNotes
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 14, color: Colors.white),
              label: const Text('SAVE PRIVATE NOTE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _isSavingNotes
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isSavingNotes = true);
                      final success = await widget.onSave(_notesCtrl.text.trim());
                      widget.onNoteUpdated(_notesCtrl.text.trim());
                      if (!mounted) return;
                      setState(() => _isSavingNotes = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Private trainer notes saved to database.' : 'Note saved locally.'),
                          backgroundColor: AppColors.primaryRed,
                        ),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientProfileDetailSheet extends StatefulWidget {
  final Map<String, dynamic> initialClient;
  final WorkoutRepository workoutRepository;
  final ActivityRepository activityRepository;
  final String Function(String?) formatJoinDate;
  final VoidCallback onAssignWorkout;
  final Function(Map<String, dynamic>) onAssignDietPlan;
  final Function(Map<String, dynamic>) onSetMacros;

  const _ClientProfileDetailSheet({
    required this.initialClient,
    required this.workoutRepository,
    required this.activityRepository,
    required this.formatJoinDate,
    required this.onAssignWorkout,
    required this.onAssignDietPlan,
    required this.onSetMacros,
  });

  @override
  State<_ClientProfileDetailSheet> createState() => _ClientProfileDetailSheetState();
}

class _ClientProfileDetailSheetState extends State<_ClientProfileDetailSheet> {
  late Map<String, dynamic> _clientData;
  bool _isFetchingLive = false;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _clientData = Map<String, dynamic>.from(widget.initialClient);
    _loadLiveProfile();
  }

  Future<void> _loadLiveProfile() async {
    if (!mounted) return;
    setState(() {
      _isFetchingLive = true;
      _fetchError = null;
    });

    final clientId = _clientData['clientId'] ?? _clientData['id'] ?? '';
    try {
      final fresh = await widget.workoutRepository.fetchClientProfile(clientId);
      if (fresh != null && mounted) {
        setState(() {
          _clientData = {..._clientData, ...fresh};
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = 'Could not sync latest data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLive = false;
        });
      }
    }
  }

  String _formatList(dynamic val) {
    if (val == null) return 'None';
    if (val is List) {
      return val.isEmpty ? 'None' : val.join(', ');
    }
    final s = val.toString().trim();
    return s.isEmpty ? 'None' : s;
  }

  @override
  Widget build(BuildContext context) {
    final clientId = _clientData['clientId'] ?? _clientData['id'] ?? 'Pending ID';
    final name = _clientData['name'] ?? 'Athlete';
    final email = _clientData['email'] ?? '';
    final phone = _clientData['phone']?.toString().isNotEmpty == true ? _clientData['phone'].toString() : 'Not recorded';
    final joinDate = widget.formatJoinDate(_clientData['createdAt']?.toString());
    final isOnboarded = _clientData['onboardingCompleted'] == true || _clientData['onboardingCompleted'] == 'true';
    final fitnessLevel = (_clientData['fitnessLevel']?.toString() ?? 'Not specified').toUpperCase();
    final primaryGoal = _clientData['primaryGoal']?.toString() ?? 'Not specified';
    final secondaryGoal = _clientData['secondaryGoal']?.toString() ?? 'None';
    final weight = _clientData['weightKg']?.toString() ?? 'Not recorded';
    final height = _clientData['heightCm']?.toString() ?? 'Not recorded';
    final age = _clientData['age']?.toString() ?? 'Not recorded';
    final gender = _clientData['gender']?.toString() ?? 'Not specified';
    final trainingExperience = _clientData['trainingExperience']?.toString() ?? 'Not specified';
    final trainingDaysPerWeek = _clientData['trainingDaysPerWeek']?.toString() ?? '4';
    final preferredDays = _formatList(_clientData['preferredDays']);
    final hasInjury = _clientData['hasCurrentInjury'] == true || _clientData['hasCurrentInjury'] == 'true';
    final injuryAreas = _formatList(_clientData['injuryAreas']);
    final injuryDescription = _clientData['injuryDescription']?.toString() ?? _clientData['injuryDetails']?.toString() ?? 'None';
    final hasSurgery = _clientData['hasPreviousSurgery'] == true || _clientData['hasPreviousSurgery'] == 'true';
    final surgeryDetails = _clientData['surgeryDetails']?.toString() ?? 'None';
    final activityLevel = _clientData['activityLevel']?.toString() ?? 'MODERATE';
    final sleepHours = _clientData['sleepHours']?.toString() ?? '7–8 hours';
    final trainingTimePref = _clientData['trainingTimePref']?.toString() ?? 'Flexible';
    final trainingPreferences = _formatList(_clientData['trainingPreferences']);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        children: [
          // Modal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryRed,
                  radius: 20,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'CLIENT ID: $clientId',
                            style: const TextStyle(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• Joined $joinDate',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isFetchingLive
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                        )
                      : const Icon(Icons.refresh, color: AppColors.primaryRed),
                  tooltip: 'Fetch Latest Database Data',
                  onPressed: _isFetchingLive ? null : _loadLiveProfile,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          if (_fetchError != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_fetchError!, style: const TextStyle(color: Colors.orange, fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: _loadLiveProfile,
                    child: const Text('RETRY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Modal Content: Assessment Breakdown & Step Synchronization
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isOnboarded ? AppColors.success : Colors.orangeAccent).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isOnboarded ? AppColors.success : Colors.orangeAccent),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOnboarded ? Icons.check_circle : Icons.pending,
                        color: isOnboarded ? AppColors.success : Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnboarded ? 'FITNESS ASSESSMENT COMPLETED & SYNCHRONIZED' : 'ASSESSMENT IN PROGRESS / INCOMPLETE',
                        style: TextStyle(
                          color: isOnboarded ? AppColors.success : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Fitness Baseline & Goals
                _buildProfileSectionCard(
                  title: '1. Fitness Baseline & Goals',
                  icon: Icons.flag_outlined,
                  items: [
                    {'label': 'Fitness Level', 'value': fitnessLevel},
                    {'label': 'Primary Goal', 'value': primaryGoal},
                    {'label': 'Secondary Goal', 'value': secondaryGoal},
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Body Measurements & Demographics
                _buildProfileSectionCard(
                  title: '2. Body Measurements & Demographics',
                  icon: Icons.straighten_outlined,
                  items: [
                    {'label': 'Phone Number', 'value': phone},
                    {'label': 'Current Weight', 'value': weight.isNotEmpty && weight != 'Not recorded' ? '$weight kg' : 'Not recorded'},
                    {'label': 'Height', 'value': height.isNotEmpty && height != 'Not recorded' ? '$height cm' : 'Not recorded'},
                    {'label': 'Age', 'value': age.isNotEmpty && age != 'Not recorded' ? '$age years' : 'Not recorded'},
                    {'label': 'Gender / Biological Sex', 'value': gender},
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Training Experience & Availability
                _buildProfileSectionCard(
                  title: '3. Training Experience & Availability',
                  icon: Icons.calendar_month_outlined,
                  items: [
                    {'label': 'Training Experience', 'value': trainingExperience},
                    {'label': 'Commitment', 'value': '$trainingDaysPerWeek days per week'},
                    {'label': 'Preferred Time', 'value': trainingTimePref},
                    {'label': 'Preferred Days', 'value': preferredDays},
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Injury & Pain Screening
                _buildProfileSectionCard(
                  title: '4. Injury & Pain Screening',
                  icon: Icons.healing_outlined,
                  items: [
                    {'label': 'Current Injury/Pain', 'value': hasInjury ? 'YES - ACTIVE INJURY REPORTED' : 'NO KNOWN INJURIES'},
                    if (hasInjury) ...[
                      {'label': 'Affected Areas', 'value': injuryAreas},
                      if (injuryDescription.isNotEmpty && injuryDescription != 'None')
                        {'label': 'Description', 'value': injuryDescription},
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // 5. Surgical History & Limitations
                _buildProfileSectionCard(
                  title: '5. Surgical History & Limitations',
                  icon: Icons.medical_services_outlined,
                  items: [
                    {'label': 'Previous Surgery', 'value': hasSurgery ? 'YES' : 'NO'},
                    if (hasSurgery) {'label': 'Surgery Details', 'value': surgeryDetails},
                  ],
                ),
                const SizedBox(height: 14),

                // 6. Daily Activity & Lifestyle
                _buildProfileSectionCard(
                  title: '6. Daily Activity & Lifestyle (Macro Planner)',
                  icon: Icons.directions_walk_outlined,
                  items: [
                    {'label': 'Daily Activity Outside Gym', 'value': activityLevel},
                    {'label': 'Average Sleep', 'value': sleepHours},
                  ],
                ),
                const SizedBox(height: 14),

                // 7. Training Modality Preferences
                _buildProfileSectionCard(
                  title: '7. Training Modality Preferences',
                  icon: Icons.fitness_center_outlined,
                  items: [
                    {'label': 'Enjoyed Modalities', 'value': trainingPreferences},
                  ],
                ),
                const SizedBox(height: 14),



                // 8. Individual Client Management Quick Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, size: 16, color: AppColors.primaryRed),
                          SizedBox(width: 8),
                          Text(
                            '8. INDIVIDUAL CLIENT MANAGEMENT',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.fitness_center, size: 14, color: Colors.white),
                            label: const Text('ASSIGN WORKOUT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: widget.onAssignWorkout,
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceElevated,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.restaurant_menu, size: 14, color: AppColors.primaryRed),
                            label: const Text('ASSIGN DIET PLAN', style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => widget.onAssignDietPlan(_clientData),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceElevated,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.pie_chart, size: 14, color: AppColors.gold),
                            label: const Text('SET MACROS', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => widget.onSetMacros(_clientData),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 10. Private Admin Notes
                _AdminNotesEditor(
                  clientId: clientId,
                  initialNote: _clientData['adminNotes']?.toString() ?? '',
                  onSave: (newNote) => widget.workoutRepository.saveAdminNotes(clientId, newNote),
                  onNoteUpdated: (newNote) => _clientData['adminNotes'] = newNote,
                ),
                const SizedBox(height: 14),

                // Security Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Client credentials verified via permanent Client ID ($clientId) and backend bcrypt password hashing. Neon PostgreSQL database is the single source of truth.',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSectionCard({
    required String title,
    required IconData icon,
    required List<Map<String, String>> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primaryRed),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      item['label']!,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item['value']!,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

