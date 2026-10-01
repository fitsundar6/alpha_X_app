import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'role_router.dart';

class NavigationShell extends StatefulWidget {
  final WorkoutRepository? workoutRepository;
  final ActivityRepository? activityRepository;
  final MacroRepository? macroRepository;
  final WeeklyProgressRepository? weeklyProgressRepository;

  const NavigationShell({
    super.key,
    this.workoutRepository,
    this.activityRepository,
    this.macroRepository,
    this.weeklyProgressRepository,
  });

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  late final WorkoutRepository _workoutRepository;
  late final ActivityRepository _activityRepository;
  late final MacroRepository _macroRepository;
  late final WeeklyProgressRepository _weeklyProgressRepository;
  final bool _isExpandedView = false;

  @override
  void initState() {
    super.initState();
    _workoutRepository = widget.workoutRepository ?? WorkoutRepository();
    _activityRepository = widget.activityRepository ?? ActivityRepository();
    _macroRepository = widget.macroRepository ?? MacroRepository();
    _weeklyProgressRepository = widget.weeklyProgressRepository ?? WeeklyProgressRepository();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 850;

    final appContent = RoleRouter(
      workoutRepository: _workoutRepository,
      activityRepository: _activityRepository,
      macroRepository: _macroRepository,
      weeklyProgressRepository: _weeklyProgressRepository,
    );

    // Responsive desktop container wrapper:
    if (isWideScreen && !_isExpandedView) {
      return Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: Center(
          child: Container(
            width: 540,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).dividerTheme.color ?? AppColors.border,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: appContent,
          ),
        ),
      );
    }

    return appContent;
  }
}
