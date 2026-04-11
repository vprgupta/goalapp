import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/task_model.dart';
import '../../providers/goal_provider.dart';
import 'task_card_widget.dart';
import 'key_concepts_dialog.dart';
import 'day_complete_overlay.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showCompleteOverlay = false;

  Future<void> _onTaskComplete(TaskModel task, {bool? recallCorrect}) async {
    List<String>? subTopics;

    // Quick Reflection is ONLY for Learn tasks (not Revise/Recall sessions)
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

    if (goal == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B0F1A), Color(0xFF0D1225)],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(goal, dayPlan)),
                  SliverToBoxAdapter(
                    child: _buildMotivationBanner(dayPlan),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        "Today's Tasks",
                        style: AppTextStyles.titleLarge,
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
                            return TaskCardWidget(
                              key: ValueKey(task.id),
                              task: task,
                              topicName: topic?.name ?? task.title,
                              thumbnailUrl: topic?.thumbnailUrl,
                              subTopics: topic?.subTopics ?? [],
                              isCompleted: task.isDone,
                              onComplete: ({recallCorrect}) =>
                                  _onTaskComplete(task, recallCorrect: recallCorrect),
                            )
                                .animate()
                                .fadeIn(
                                  delay: Duration(milliseconds: 100 + i * 60),
                                  duration: 350.ms,
                                )
                                .slideX(begin: 0.1, end: 0);
                          },
                          childCount: dayPlan.tasks.length,
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(child: _buildEmptyState()),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
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

  Widget _buildHeader(dynamic goal, dynamic dayPlan) {
    final progress = goal.currentDay / goal.totalDays;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                      style: AppTextStyles.headlineLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day ${goal.currentDay} of ${goal.totalDays}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.accentAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/goals'),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderCard),
                  ),
                  child: const Icon(Icons.collections_bookmark_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/stats'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderCard),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(progress),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.borderSubtle),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Overall Progress', style: AppTextStyles.bodySmall),
            Text(
              '${(progress * 100).round()}%',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (ctx, val, _) => LinearProgressIndicator(
              value: val,
              minHeight: 6,
              backgroundColor: AppColors.progressTrack,
              valueColor: const AlwaysStoppedAnimation(AppColors.progressFill),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationBanner(dynamic dayPlan) {
    if (dayPlan == null) return const SizedBox.shrink();
    final pending = dayPlan.pendingCount;
    final String msg = pending == 0
        ? "All done! You're unstoppable 🔥"
        : pending == 1
            ? 'One task left — finish strong 💪'
            : '$pending tasks to go. Stay focused.';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Row(
        children: [
          Text('⚡', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.celebration_rounded,
                size: 64, color: AppColors.accentAmber),
            const SizedBox(height: 16),
            Text('All caught up!', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text('No tasks left for today.',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
