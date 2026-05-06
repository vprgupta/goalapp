import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/topic_model.dart';
import '../../providers/goal_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  Color _strengthColor(double s) {
    if (s < 0.3) return AppColors.strengthWeak;
    if (s < 0.6) return AppColors.strengthMedium;
    if (s < 0.85) return AppColors.strengthStrong;
    return AppColors.strengthPerfect;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(activeGoalProvider);
    if (goal == null) return const SizedBox.shrink();

    final topics = ref.watch(topicsProvider(goal.id));
    final dayPlans = ref.watch(dayPlansProvider(goal.id));


    final completedDays = dayPlans.where((d) => d.isCompleted).length;
    final learnedTopics = topics.where((t) => t.isLearned).length;
    final avgStrength = topics.isEmpty
        ? 0.0
        : topics.fold(0.0, (s, t) => s + t.strengthScore) / topics.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text('Progress', style: AppTextStyles.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(completedDays, learnedTopics, avgStrength, goal.totalDays),
            const SizedBox(height: 28),
            Text('Topic Strength Map', style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Based on your recall performance',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            ...topics.asMap().entries.map((entry) =>
                _buildTopicRow(entry.value, entry.key)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
      int completedDays, int learnedTopics, double avgStrength, int totalDays) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Days Done',
            value: '$completedDays',
            suffix: '/ $totalDays',
            color: AppColors.learnColor,
            icon: Icons.calendar_today_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Topics Learned',
            value: '$learnedTopics',
            color: AppColors.accentTeal,
            icon: Icons.menu_book_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Avg Strength',
            value: '${(avgStrength * 100).round()}%',
            color: _strengthColor(avgStrength),
            icon: Icons.electric_bolt_rounded,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _statCard({
    required String label,
    required String value,
    String suffix = '',
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              text: value,
              style: AppTextStyles.headlineMedium.copyWith(color: color),
              children: suffix.isNotEmpty
                  ? [
                      TextSpan(
                        text: ' $suffix',
                        style: AppTextStyles.bodySmall,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTopicRow(TopicModel topic, int index) {
    final strength = topic.strengthScore;
    final color = _strengthColor(strength);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: topic.isLearned ? color : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.name, style: AppTextStyles.titleMedium),
                if (topic.isLearned)
                  Row(
                    children: [
                      Text(topic.strengthLabel,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: color)),
                      const SizedBox(width: 8),
                      Text('· ${topic.revisionCount}x revised',
                          style: AppTextStyles.bodySmall),
                    ],
                  )
                else
                  Text('Not yet learned',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (topic.isLearned)
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(strength * 100).round()}%',
                    style: AppTextStyles.labelLarge.copyWith(color: color),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: strength,
                      minHeight: 4,
                      backgroundColor: AppColors.progressTrack,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 100 + index * 40))
        .slideX(begin: 0.05, end: 0);
  }
}
