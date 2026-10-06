import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/dashboard/admin_main_dashboard_screen.dart';
import 'package:alpha_x_gym/features/dashboard/client_main_dashboard_screen.dart';

/// Central single-app role router
/// Dynamically mounts Admin or Client dashboard according to authenticated user's role.
class RoleRouter extends StatefulWidget {
  final WorkoutRepository workoutRepository;
  final ActivityRepository activityRepository;
  final MacroRepository macroRepository;
  final WeeklyProgressRepository? weeklyProgressRepository;

  const RoleRouter({
    super.key,
    required this.workoutRepository,
    required this.activityRepository,
    required this.macroRepository,
    this.weeklyProgressRepository,
  });

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  final _auth = AuthService();
  late final WeeklyProgressRepository _weeklyProgressRepository;

  @override
  void initState() {
    super.initState();
    _weeklyProgressRepository = widget.weeklyProgressRepository ?? WeeklyProgressRepository();
    _auth.addListener(_onAuthChange);
    if (!_auth.isInitialized) {
      _auth.initialize();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      );
    }

    final role = _auth.currentRole;

    // Strict role check:
    // If Admin -> Admin Dashboard (Full control)
    // If Client -> Client Dashboard (Limited access)
    // If unknown / invalid -> Fallback safely to client dashboard, never grant admin
    if (role == UserRole.admin) {
      return AdminMainDashboardScreen(
        workoutRepository: widget.workoutRepository,
        activityRepository: widget.activityRepository,
        macroRepository: widget.macroRepository,
        weeklyProgressRepository: _weeklyProgressRepository,
      );
    } else {
      return ClientMainDashboardScreen(
        workoutRepository: widget.workoutRepository,
        activityRepository: widget.activityRepository,
        macroRepository: widget.macroRepository,
        weeklyProgressRepository: _weeklyProgressRepository,
      );
    }
  }
}
