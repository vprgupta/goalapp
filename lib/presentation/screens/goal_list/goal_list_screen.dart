import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/goal_provider.dart';
import '../../../data/models/goal_model.dart';

class GoalListScreen extends ConsumerWidget {
  const GoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(allGoalsProvider);
    final activeGoal = ref.watch(activeGoalProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('My Goals'),
        centerTitle: true,
      ),
      body: goals.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: goals.length,
              itemBuilder: (ctx, idx) {
                final goal = goals[idx];
                final isSelected = activeGoal?.id == goal.id;
                return _GoalListItem(
                  goal: goal,
                  isSelected: isSelected,
                  onTap: () {
                    ref.read(activeGoalProvider.notifier).switchGoal(goal.id);
                    context.go('/dashboard');
                  },
                  onDelete: () => _showDeleteConfirmation(context, ref, goal),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal'),
        backgroundColor: AppColors.accentAmber,
        foregroundColor: AppColors.backgroundDark,
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "${goal.name}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              foregroundColor: Colors.redAccent,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(activeGoalProvider.notifier).deleteGoalById(goal.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Goal "${goal.name}" deleted')),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('No goals yet', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Start your learning journey\nby creating your first goal.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.push('/create'),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}

class _GoalListItem extends StatelessWidget {
  final GoalModel goal;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GoalListItem({
    required this.goal,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.progressPercent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentAmber.withOpacity(0.05) : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.accentAmber : AppColors.borderCard,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentAmber.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
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
                            style: AppTextStyles.titleLarge.copyWith(
                              color: isSelected ? AppColors.accentAmber : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Level: ${goal.level.toUpperCase()}',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (goal.status == GoalStatus.completed)
                      const Icon(Icons.check_circle_rounded, color: AppColors.strengthStrong)
                    else if (isSelected)
                      const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentAmber),
                    const SizedBox(width: 40), // Space for delete button
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress:',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isSelected ? AppColors.accentAmber : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.progressTrack,
                    color: isSelected ? AppColors.accentAmber : AppColors.progressFill,
                  ),
                ),
              ],
            ),
            Positioned(
              top: -10,
              right: -10,
              child: IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.textMuted.withOpacity(0.5),
                splashRadius: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
