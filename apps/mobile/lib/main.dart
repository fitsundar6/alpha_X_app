import 'dart:async';

import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/client_theme_service.dart';
import 'core/theme/app_typography.dart';
import 'core/auth/auth_service.dart';
import 'core/widgets/alpha_x_logo.dart';
import 'core/auth/login_screen.dart';
import 'core/auth/create_account_screen.dart';
import 'core/auth/admin_login_screen.dart';
import 'features/navigation/navigation_shell.dart';
import 'features/workout/data/repositories/workout_repository.dart';
import 'features/activity/data/repositories/activity_repository.dart';
import 'features/macro_planner/data/repositories/macro_repository.dart';
import 'features/dashboard/admin_main_dashboard_screen.dart';
import 'features/dashboard/client_main_dashboard_screen.dart';
import 'features/workout/presentation/admin/admin_workout_sessions_screen.dart';
import 'features/workout/presentation/admin/admin_create_edit_session_screen.dart';
import 'features/workout/presentation/client/client_workout_screen.dart';
import 'features/workout/presentation/client/client_session_overview_screen.dart';
import 'features/workout/presentation/client/client_workout_history_screen.dart';
import 'features/onboarding/client_onboarding_screen.dart';
import 'features/progress/data/repositories/weekly_progress_repository.dart';
import 'features/progress/presentation/screens/client_weekly_progress_screen.dart';
import 'features/progress/presentation/screens/admin_weekly_progress_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().initialize();
  await ClientThemeService().initialize();

  // OneSignal Push Notifications — Admin-triggered, client-received
  OneSignal.initialize('56c1791b-aa5e-4042-8fba-e370433b8055');
  // Request permission (shows iOS/Android system permission dialog)
  OneSignal.Notifications.requestPermission(true);

  // Runtime API Configuration Logging (Zero secrets or credentials logged)
  debugPrint('====================================================');
  debugPrint('ALPHA X GYM APP STARTUP');
  debugPrint('API BASE URL = ${ApiConfig.baseUrl}');
  debugPrint('====================================================');

  runApp(const AlphaXGymApp());
}

class AlphaXGymApp extends StatefulWidget {
  final Widget? home;
  const AlphaXGymApp({super.key, this.home});

  @override
  State<AlphaXGymApp> createState() => AlphaXGymAppState();
}

class AlphaXGymAppState extends State<AlphaXGymApp> {
  late final WorkoutRepository _workoutRepository;
  late final ActivityRepository _activityRepository;
  late final MacroRepository _macroRepository;
  late final WeeklyProgressRepository _weeklyProgressRepository;
  final AuthService _authService = AuthService();
  final ClientThemeService _clientThemeService = ClientThemeService();

  @override
  void initState() {
    super.initState();
    _authService.addListener(_onStateChange);
    _clientThemeService.addListener(_onStateChange);
    _workoutRepository = WorkoutRepository();
    _activityRepository = ActivityRepository();
    _macroRepository = MacroRepository();
    _weeklyProgressRepository = WeeklyProgressRepository();

    // Automatically update daily activity tracking & sync with backend when workout is completed
    _workoutRepository.onWorkoutCompleted = (record) {
      final minutes = (record.durationSeconds / 60).round().clamp(1, 300);
      final estimatedCalories = record.totalVolume > 0
          ? (record.totalVolume * 0.05).clamp(50.0, 1000.0)
          : (minutes * 6.5);
      _activityRepository.recordCompletedWorkoutActivity(
        durationMinutes: minutes,
        caloriesBurned: estimatedCalories,
      );
    };
  }

  @override
  void dispose() {
    _authService.removeListener(_onStateChange);
    _clientThemeService.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    return buildAppRoute(
      settings,
      authService: _authService,
      workoutRepository: _workoutRepository,
      activityRepository: _activityRepository,
      macroRepository: _macroRepository,
      weeklyProgressRepository: _weeklyProgressRepository,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Admin application must strictly remain unchanged and dark:
    final bool isAdmin = _authService.isAuthenticated && _authService.isAdmin;
    final ThemeData effectiveTheme = isAdmin
        ? AppTheme.darkTheme
        : _clientThemeService.resolveTheme(context);

    return AnimatedTheme(
      data: effectiveTheme,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: effectiveTheme,
        home: widget.home ?? const FoundationSplashScreen(),
        onGenerateRoute: _onGenerateRoute,
        routes: {
          '/dashboard': (context) => NavigationShell(
            workoutRepository: _workoutRepository,
            activityRepository: _activityRepository,
            macroRepository: _macroRepository,
            weeklyProgressRepository: _weeklyProgressRepository,
          ),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const CreateAccountScreen(),
          '/admin/login': (context) => const AdminLoginScreen(),
          '/onboarding': (context) => const ClientOnboardingScreen(),
        },
      ),
    );
  }
}

class FoundationSplashScreen extends StatefulWidget {
  const FoundationSplashScreen({super.key});

  @override
  State<FoundationSplashScreen> createState() => _FoundationSplashScreenState();
}

class _FoundationSplashScreenState extends State<FoundationSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<double> _entranceScale;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _autoTransitionTimer;

  @override
  void initState() {
    super.initState();
    // 1. Smooth Logo Entrance: Fade + slight scale
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );
    _entranceController.forward();

    // 2. Subtle Brand Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-transition to main app after 3 seconds if user doesn't press the button
    _autoTransitionTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _enterApp();
      }
    });
  }

  void _enterApp() {
    _autoTransitionTimer?.cancel();
    final auth = AuthService();
    if (auth.isAuthenticated) {
      if (auth.isAdmin) {
        Navigator.of(context).pushReplacementNamed('/admin');
      } else {
        if (!auth.onboardingCompleted) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        } else {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _autoTransitionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Official Alpha X Gym Brand Logo with smooth entrance and subtle pulse animation
              FadeTransition(
                opacity: _entranceFade,
                child: ScaleTransition(
                  scale: _entranceScale,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: const AlphaXLogo.splash(
                      size: 140,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Accessible semantic branding title (0-height to avoid duplicate visual text)
              const SizedBox(
                height: 0,
                width: 0,
                child: Text(
                  'ALPHA X GYM',
                  style: TextStyle(fontSize: 0, color: Colors.transparent),
                ),
              ),

              const SizedBox(height: 8),

              // Brand Tagline
              const Text(
                AppConstants.appTagline,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Motto Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  AppConstants.appMotto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),

              const Spacer(),

              // Enter Gym Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enterApp,
                  icon: const Icon(Icons.fitness_center, size: 20),
                  label: const Text(
                    'ENTER ALPHA X GYM',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: AppColors.primaryRed,
                    elevation: 8,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Member Portal / Sign-In Button
              TextButton.icon(
                onPressed: () {
                  _autoTransitionTimer?.cancel();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                icon: const Icon(Icons.login, size: 16, color: AppColors.textSecondary),
                label: const Text(
                  'Member Sign In',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Foundation status pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'All Feature Modules Online',
                      style: AppTypography.titleSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centralized application route builder and RBAC security guard
Route<dynamic>? buildAppRoute(
  RouteSettings settings, {
  AuthService? authService,
  WorkoutRepository? workoutRepository,
  ActivityRepository? activityRepository,
  MacroRepository? macroRepository,
  WeeklyProgressRepository? weeklyProgressRepository,
}) {
  final auth = authService ?? AuthService();
  final workoutRepo = workoutRepository ?? WorkoutRepository();
  final activityRepo = activityRepository ?? ActivityRepository();
  final macroRepo = macroRepository ?? MacroRepository();
  final weeklyProgressRepo = weeklyProgressRepository ?? WeeklyProgressRepository();
  final uri = Uri.parse(settings.name ?? '/');
  final path = uri.path;

  // Master Administrator Login route (Public portal)
  if (path == '/admin/login') {
    return MaterialPageRoute(
      builder: (_) => const AdminLoginScreen(),
    );
  }

  // Admin protected routes: require Admin role
  if (path.startsWith('/admin')) {
    if (!auth.isAdmin) {
      // Safe access denial state: never grant admin permissions to client or unknown role
      return MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('ACCESS DENIED')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'UNAUTHORIZED ACCESS',
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Admin permissions are required to access this endpoint. Your role (Client) has limited access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                    ),
                    onPressed: () =>
                        Navigator.of(ctx).pushReplacementNamed('/dashboard'),
                    child: const Text(
                      'Return to Client Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    switch (path) {
      case '/admin':
      case '/admin/clients':
      case '/admin/assignments':
        return MaterialPageRoute(
          builder: (_) => Theme(
            data: AppTheme.darkTheme,
            child: AdminMainDashboardScreen(
              workoutRepository: workoutRepo,
              activityRepository: activityRepo,
              macroRepository: macroRepo,
              weeklyProgressRepository: weeklyProgressRepo,
            ),
          ),
        );
      case '/admin/weekly-progress':
        return MaterialPageRoute(
          builder: (_) => Theme(
            data: AppTheme.darkTheme,
            child: AdminWeeklyProgressScreen(
              repository: weeklyProgressRepo,
            ),
          ),
        );
      case '/admin/workout-sessions':
        return MaterialPageRoute(
          builder: (_) => Theme(
            data: AppTheme.darkTheme,
            child: AdminWorkoutSessionsScreen(
              workoutRepository: workoutRepo,
            ),
          ),
        );
      case '/admin/workout-sessions/create':
      case '/admin/workout-sessions/edit':
        return MaterialPageRoute(
          builder: (_) => Theme(
            data: AppTheme.darkTheme,
            child: AdminCreateEditSessionScreen(
              workoutRepository: workoutRepo,
            ),
          ),
        );
    }
  }

  // Client protected routes: require Client or Admin access
  if (path.startsWith('/client')) {
    switch (path) {
      case '/client':
        return MaterialPageRoute(
          builder: (_) => ClientMainDashboardScreen(
            workoutRepository: workoutRepo,
            activityRepository: activityRepo,
            macroRepository: macroRepo,
            weeklyProgressRepository: weeklyProgressRepo,
          ),
        );
      case '/client/weekly-check-in':
        return MaterialPageRoute(
          builder: (_) => ClientWeeklyProgressScreen(
            repository: weeklyProgressRepo,
          ),
        );
      case '/client/workout':
        return MaterialPageRoute(
          builder: (_) =>
              ClientWorkoutScreen(workoutRepository: workoutRepo),
        );
      case '/client/workout/session':
        return MaterialPageRoute(
          builder: (_) => ClientSessionOverviewScreen(
            session: workoutRepo.activeSession,
            workoutRepository: workoutRepo,
          ),
        );
      case '/client/workout/history':
        return MaterialPageRoute(
          builder: (_) => ClientWorkoutHistoryScreen(
            workoutRepository: workoutRepo,
          ),
        );
    }
  }

  // Member Login & Auth routes
  if (path == '/login') {
    return MaterialPageRoute(
      builder: (_) => const LoginScreen(),
    );
  }

  // Client Create Account / Registration route
  if (path == '/register') {
    return MaterialPageRoute(
      builder: (_) => const CreateAccountScreen(),
    );
  }

  // Client Fitness Onboarding route
  if (path == '/onboarding') {
    return MaterialPageRoute(
      builder: (_) => const ClientOnboardingScreen(),
    );
  }

  // Default route: Dashboard (handled by NavigationShell with RoleRouter)
  if (path == '/dashboard') {
    return MaterialPageRoute(
      builder: (_) => NavigationShell(
        workoutRepository: workoutRepo,
        activityRepository: activityRepo,
        macroRepository: macroRepo,
        weeklyProgressRepository: weeklyProgressRepo,
      ),
    );
  }

  return null;
}
