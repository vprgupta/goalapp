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
import '../../providers/deep_dive_provider.dart';
import '../../../domain/services/home_widget_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showCompleteOverlay = false;

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
      context.go('/complete');
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
                  SliverToBoxAdapter(child: _buildMotivationBanner(dayPlan)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildMotivationBanner(dynamic dayPlan) {
    if (dayPlan == null) return const SizedBox.shrink();

    final pending = dayPlan.pendingCount;
    final bool allDone = pending == 0;

    final String msg = allDone
        ? "All done! You're unstoppable 🔥"
        : pending == 1
            ? 'One task left — finish strong 💪'
            : '$pending tasks to go. Stay focused.';

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
