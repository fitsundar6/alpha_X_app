import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/workout_summary_models.dart';
import '../services/workout_summary_service.dart';
import '../utils/ordinal_formatter.dart';
import '../widgets/action_row.dart';
import '../widgets/cards/card_1_workout_overview.dart';
import '../widgets/cards/card_2_muscle_activation.dart';
import '../widgets/cards/card_3_exercise_list.dart';
import '../widgets/cards/card_4_personal_records.dart';
import '../widgets/cards/card_5_streak_calendar.dart';
import '../widgets/cards/card_6_minimal_text.dart';

/// Displays the Workout Complete summary modal bottom sheet.
///
/// Configured with:
/// - isScrollControlled: true
/// - rounded top corners: 28
/// - white background
/// - ~92% screen height
Future<void> showWorkoutCompleteModal(
  BuildContext context, {
  WorkoutSummary? summary,
}) {
  final workoutData = summary ?? WorkoutSummary.mock();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (ctx) => ProviderScope(
      overrides: [
        currentWorkoutSummaryProvider.overrideWithValue(workoutData),
      ],
      child: const _WorkoutCompleteModalContent(),
    ),
  );
}

class _WorkoutCompleteModalContent extends ConsumerStatefulWidget {
  const _WorkoutCompleteModalContent();

  @override
  ConsumerState<_WorkoutCompleteModalContent> createState() =>
      _WorkoutCompleteModalContentState();
}

class _WorkoutCompleteModalContentState
    extends ConsumerState<_WorkoutCompleteModalContent>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final List<GlobalKey> _cardKeys;
  late final AnimationController _entryAnimController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _cardKeys = List.generate(6, (_) => GlobalKey());

    _entryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryAnimController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryAnimController,
      curve: Curves.easeOutCubic,
    ));

    _entryAnimController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSummaryProvider);
    final notifier = ref.read(workoutSummaryProvider.notifier);
    final summary = state.summary;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.92;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 1. Centered grey drag handle (40x4, rounded)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 2. Header: Title, Subtitle, and Yellow "Done" button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title: "Well done!" (bold, ~32sp, black)
                        const Text(
                          'Well done!',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtitle: "This is your {n}th workout" (grey, ~18sp)
                        Text(
                          'This is your ${formatOrdinal(summary.workoutNumber)} workout',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Yellow "Done" button top-right (color #FFC400, radius 10, bold black text)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC400),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC400).withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Share Card Carousel (6 pages, viewportFraction ~0.88)
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentPage = idx;
                      });
                      notifier.setPageIndex(idx);
                    },
                    children: [
                      // Page 1: Workout summary overview
                      _buildCarouselPage(
                        index: 0,
                        card: Card1WorkoutOverview(summary: summary),
                      ),

                      // Page 2: MUSCLE ACTIVATION CARD (Main Feature)
                      _buildCarouselPage(
                        index: 1,
                        card: Card2MuscleActivation(summary: summary),
                      ),

                      // Page 3: Exercise list
                      _buildCarouselPage(
                        index: 2,
                        card: Card3ExerciseList(summary: summary),
                      ),

                      // Page 4: Personal records
                      _buildCarouselPage(
                        index: 3,
                        card: Card4PersonalRecords(summary: summary),
                      ),

                      // Page 5: Streak & consistency calendar
                      _buildCarouselPage(
                        index: 4,
                        card: Card5StreakCalendar(summary: summary),
                      ),

                      // Page 6: Minimal text-only card
                      _buildCarouselPage(
                        index: 5,
                        card: Card6MinimalText(summary: summary),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Dot Indicator below (smooth_page_indicator)
            // Active dot is yellow #FFC400, inactive dots are grey
            SmoothPageIndicator(
              controller: _pageController,
              count: 6,
              effect: const ExpandingDotsEffect(
                dotWidth: 8,
                dotHeight: 8,
                expansionFactor: 2.8,
                spacing: 6,
                activeDotColor: Color(0xFFFFC400),
                dotColor: Color(0xFFD1D1D6),
              ),
            ),

            const SizedBox(height: 20),

            // 5. Action Row (Stories | Share | Save | Save All | Text)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ActionRow(
                isExporting: state.isExporting,
                onStories: () => notifier.shareToInstagramStories(
                  boundaryKey: _cardKeys[_currentPage],
                  context: context,
                ),
                onShare: () => notifier.shareCurrentCard(
                  boundaryKey: _cardKeys[_currentPage],
                  context: context,
                ),
                onSave: () => notifier.saveCurrentCard(
                  boundaryKey: _cardKeys[_currentPage],
                  context: context,
                ),
                onSaveAll: () => notifier.saveAllCards(
                  boundaryKeys: _cardKeys,
                  pageController: _pageController,
                  context: context,
                ),
                onText: () => notifier.sharePlainTextSummary(context: context),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselPage({
    required int index,
    required Widget card,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: RepaintBoundary(
        key: _cardKeys[index],
        child: card,
      ),
    );
  }
}
