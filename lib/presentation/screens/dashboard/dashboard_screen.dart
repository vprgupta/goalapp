import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/task_model.dart';
import '../../providers/goal_provider.dart';
import 'task_card_widget.dart';
import 'key_concepts_dialog.dart';
import 'day_complete_overlay.dart';
import 'phase_completion_overlay.dart';
import '../../providers/deep_dive_provider.dart';
import '../../../domain/services/home_widget_service.dart';
import '../../../domain/services/user_progress_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showCompleteOverlay = false;
  bool _showPhaseComplete = false;

  Future<void> _onTaskComplete(TaskModel task, {bool? recallCorrect}) async {
    List<String>? subTopics;

    if (task.isLearn && !task.isDone) {
      final topic = ref.read(goalRepositoryProvider).getTopic(task.topicId);
      final result = await showDialog<List<String>>(
        context: context,
        builder: (ctx) => KeyConceptsDialog(
          topicName: topic?.name ?? task.title,
          initialConcepts: topic?.subTopics ?? [],
          isRevision: false,
        ),
      );
      if (result != null) {
        subTopics = result;
      }
    }

    final allDone = await ref.read(currentDayPlanProvider.notifier).completeTask(
          task.id,
          recallCorrect: recallCorrect,
          topicId: task.topicId,
          subTopics: subTopics,
        );

    if (allDone && mounted) {
      setState(() => _showCompleteOverlay = true);
    }
  }

  Future<void> _onDayAdvance() async {
    setState(() => _showCompleteOverlay = false);
    await ref.read(currentDayPlanProvider.notifier).advanceToNextDay();

    final goal = ref.read(activeGoalProvider);
    if (goal?.status.name == 'completed' && mounted) {
      // Show phase completion celebration instead of navigating immediately
      setState(() => _showPhaseComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(activeGoalProvider);
    final dayPlan = ref.watch(currentDayPlanProvider);

    ref.listen(currentDayPlanProvider, (previous, next) {
      if (goal != null && next != null) {
        final pendingCount = next.tasks.where((t) => !t.isDone).length;
        HomeWidgetService.updateTasksWidget(
          pendingTasksCount: pendingCount,
          goalName: goal.name,
        );
      }
    });

    if (goal == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: _buildNoSprintScreen(context),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF080C17), Color(0xFF0D1428)],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                cacheExtent: 600,
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(goal, dayPlan)),
                  SliverToBoxAdapter(child: _buildStreakXpBar()),
                  SliverToBoxAdapter(child: _buildMotivationBanner(dayPlan, goal)),
                  if (dayPlan != null) SliverToBoxAdapter(child: _buildCatchUpBanner(dayPlan, goal)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                      child: Row(
                        children: [
                          // Left accent bar
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.gradientAmberStart,
                                  AppColors.gradientAmberEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Today's Tasks",
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (dayPlan != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final task = dayPlan.tasks[i];
                            final topic = ref
                                .read(goalRepositoryProvider)
                                .getTopic(task.topicId);
                            final isExpanded = topic?.isBlueprintGenerated ?? true;
                            final isExpanding =
                                ref.watch(deepDiveProvider).contains(task.topicId);

                            return TaskCardWidget(
                              key: ValueKey(task.id),
                              task: task,
                              topicName: topic?.name ?? task.title,
                              moduleName: topic?.moduleName,
                              thumbnailUrl: topic?.thumbnailUrl,
                              subTopics: topic?.subTopics ?? [],
                              isCompleted: task.isDone,
                              isExpanded: isExpanded,
                              isExpanding: isExpanding,
                              onDeepDive: () {
                                if (topic != null) {
                                  ref
                                      .read(deepDiveProvider.notifier)
                                      .expandPillar(topic);
                                }
                              },
                              onComplete: ({recallCorrect}) =>
                                  _onTaskComplete(task, recallCorrect: recallCorrect),
                            );
                          },
                          childCount: dayPlan.tasks.length,
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(child: _buildEmptyState()),
                  // Safety advance button
                  if (dayPlan != null && dayPlan.allTasksDone && !_showCompleteOverlay)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: _buildAdvanceButton(dayPlan, goal),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),

          // Day Complete Overlay
          if (_showCompleteOverlay && dayPlan != null)
            DayCompleteOverlay(
              dayPlan: dayPlan,
              goal: goal,
              onContinue: _onDayAdvance,
            ),

          // Phase Complete Celebration
          if (_showPhaseComplete)
            PhaseCompletionOverlay(
              phaseName: goal.name,
              topicsCompleted: goal.topicIds.length,
              xpEarned: goal.topicIds.length * UserProgressService.xpLearnTopic + UserProgressService.xpPerfectDay,
              onContinue: () {
                setState(() => _showPhaseComplete = false);
                context.go('/complete');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAdvanceButton(dynamic dayPlan, dynamic goal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: _onDayAdvance,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(
          dayPlan.dayNumber >= goal.totalDays
              ? 'Complete Sprint 🎉'
              : 'Continue to Day ${dayPlan.dayNumber + 1}',
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic goal, dynamic dayPlan) {
    final progress = goal.currentDay / goal.totalDays;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Glowing amber day badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentAmber.withOpacity(0.2),
                            AppColors.accentAmber.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accentAmber.withOpacity(0.45),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.glowAmber,
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 13, color: AppColors.accentAmber),
                          const SizedBox(width: 5),
                          Text(
                            'Day ${goal.currentDay} of ${goal.totalDays}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accentAmber,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Icon buttons with gradient background
              _buildHeaderIconButton(
                Icons.collections_bookmark_rounded,
                onTap: () => context.push('/goals'),
              ),
              const SizedBox(width: 8),
              _buildHeaderIconButton(
                Icons.bar_chart_rounded,
                onTap: () => context.push('/stats'),
              ),
              const SizedBox(width: 8),
              _buildHeaderIconButton(
                Icons.settings_rounded,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressBar(progress),
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.borderSubtle),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton(IconData icon, {required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.textSecondary, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.backgroundElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderCard),
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall Progress',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(progress * 100).round()}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accentAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (ctx, val, _) {
            return Stack(
              children: [
                // Track
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 8,
                    color: AppColors.progressTrack,
                  ),
                ),
                // Fill
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: FractionallySizedBox(
                    widthFactor: val.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gradientBlueStart,
                            AppColors.gradientBlueEnd,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNoSprintScreen(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentAmber.withOpacity(0.18),
                      AppColors.accentAmber.withOpacity(0.0),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentAmber.withOpacity(0.35), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: AppColors.glowAmber, blurRadius: 20),
                  ],
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    size: 42, color: AppColors.accentAmber),
              ),
              const SizedBox(height: 28),
              Text('No Active Sprint',
                  style: AppTextStyles.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Start a phase from your Roadmap Library to begin your daily learning plan.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () => context.push('/goals'),
                icon: const Icon(Icons.collections_bookmark_rounded, size: 18),
                label: const Text('Open Roadmap Library'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/create'),
                child: const Text('Design new roadmap'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakXpBar() {
    final streak = UserProgressService.currentStreak;
    final level = UserProgressService.level;
    final lvlProgress = UserProgressService.levelProgress;
    final xpInLevel = UserProgressService.xpInCurrentLevel;
    final xpNeeded = UserProgressService.xpForNextLevel(level);
    final title = UserProgressService.levelTitle;
    final streakBroken = UserProgressService.isStreakBroken;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Row(
        children: [
          // Streak counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: streakBroken
                  ? Colors.grey.withOpacity(0.1)
                  : AppColors.accentAmber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: streakBroken
                    ? Colors.grey.withOpacity(0.2)
                    : AppColors.accentAmber.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: streakBroken ? Colors.grey : AppColors.accentAmber,
                ),
                const SizedBox(width: 5),
                Text(
                  '$streak day${streak == 1 ? '' : 's'}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: streakBroken ? Colors.grey : AppColors.accentAmber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // XP + level bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lv.$level $title',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: const Color(0xFFB197FC),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$xpInLevel/$xpNeeded XP',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: lvlProgress,
                    minHeight: 5,
                    backgroundColor: AppColors.progressTrack,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFB197FC)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatchUpBanner(dynamic dayPlan, dynamic goal) {
    // Detect if there are tasks from previous days that are incomplete
    final goalId = goal.id as String;
    final allDayPlans = ref.read(goalRepositoryProvider).getDayPlansForGoal(goalId);
    final currentDayNum = goal.currentDay as int;

    final incomplete = allDayPlans.where((dp) {
      return !(dp.isCompleted as bool) &&
          (dp.dayNumber as int) < currentDayNum &&
          dp.tasks.any((t) => !(t.isDone as bool));
    }).toList();

    if (incomplete.isEmpty) return const SizedBox.shrink();

    final overdueCount = incomplete.fold<int>(
      0,
      (int sum, dynamic dp) => sum + (dp.tasks as List).where((t) => !(t.isDone as bool)).length,
    );

    return GestureDetector(
      onTap: () => _showCatchUpDialog(incomplete, goal),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B6B).withOpacity(0.15),
              const Color(0xFFFF6B6B).withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.replay_rounded, color: Color(0xFFFF6B6B), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ $overdueCount overdue task${overdueCount == 1 ? '' : 's'} from past days',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Tap to reschedule missed tasks to today',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: const Color(0xFFFF6B6B).withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF6B6B)),
          ],
        ),
      ),
    );
  }

  Future<void> _showCatchUpDialog(List<dynamic> incompletePlans, dynamic goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Catch-Up Mode 📋'),
        content: const Text(
          'Move all overdue incomplete tasks to today so you can get back on track. This will not change your overall deadline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Mark past incomplete day plans as completed to push tasks forward
    for (final plan in incompletePlans) {
      await ref.read(goalRepositoryProvider).markDayComplete(plan.id as String);
    }
    // Refresh state
    ref.invalidate(currentDayPlanProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasks rescheduled to today ✅')),
      );
    }
  }

  Widget _buildMotivationBanner(dynamic dayPlan, [dynamic goal]) {
    if (dayPlan == null) return const SizedBox.shrink();

    final pending = dayPlan.pendingCount;
    final bool allDone = pending == 0;

    // Today's total estimated time
    final int todayMinutes = (dayPlan.tasks as List)
        .where((t) => !(t.isDone as bool))
        .fold<int>(0, (int sum, dynamic t) => sum + (t.estimatedMinutes as int));
    final String timeLabel = todayMinutes > 0
        ? '~${todayMinutes}min'
        : '';

    final String msg = allDone
        ? "All done! You're unstoppable 🔥"
        : pending == 1
            ? 'One task left — finish strong 💪'
            : '$pending tasks to go.${ timeLabel.isNotEmpty ? ' $timeLabel today.' : ' Stay focused.'}';

    final Color bannerColor =
        allDone ? AppColors.accentGreen : AppColors.learnColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            bannerColor.withOpacity(0.15),
            bannerColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allDone ? Icons.verified_rounded : Icons.bolt_rounded,
              size: 18,
              color: bannerColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentGreen.withOpacity(0.18),
                    AppColors.accentGreen.withOpacity(0.0),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.accentGreen.withOpacity(0.35), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: AppColors.glowGreen, blurRadius: 20),
                ],
              ),
              child: const Icon(Icons.verified_rounded,
                  size: 40, color: AppColors.accentGreen),
            ),
            const SizedBox(height: 24),
            Text('Phase Complete!',
                style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'You\'ve finished all tasks in this sprint.\nReady for the next phase?',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => context.push('/goals'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Start Next Phase'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
