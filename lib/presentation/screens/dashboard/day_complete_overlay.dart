import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/day_plan_model.dart';
import '../../../data/models/goal_model.dart';

class DayCompleteOverlay extends StatelessWidget {
  final DayPlanModel dayPlan;
  final GoalModel goal;
  final VoidCallback onContinue;

  const DayCompleteOverlay({
    super.key,
    required this.dayPlan,
    required this.goal,
    required this.onContinue,
  });

  bool get isGoalComplete => dayPlan.dayNumber >= goal.totalDays;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTrophyAnimation(),
                const SizedBox(height: 28),
                _buildTitle(),
                const SizedBox(height: 12),
                _buildSubtitle(),
                const SizedBox(height: 32),
                _buildStats(),
                const SizedBox(height: 40),
                _buildContinueButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyAnimation() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accentAmber, Color(0xFFFF6B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentAmber.withOpacity(0.4),
            blurRadius: 32,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Icon(
        isGoalComplete ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
        color: Colors.white,
        size: 52,
      ),
    )
        .animate(onPlay: (c) => c.forward())
        .scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildTitle() {
    final title = isGoalComplete ? 'Goal Complete! 🎉' : 'Day ${dayPlan.dayNumber} Complete!';
    return Text(
      title,
      style: AppTextStyles.displayMedium,
      textAlign: TextAlign.center,
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildSubtitle() {
    final msg = isGoalComplete
        ? 'You mastered ${goal.name}. Outstanding! 🌟'
        : 'Keep up the momentum. Day ${dayPlan.dayNumber + 1} is unlocking now.';
    return Text(
      msg,
      style: AppTextStyles.bodyMedium,
      textAlign: TextAlign.center,
    )
        .animate()
        .fadeIn(delay: 450.ms, duration: 400.ms);
  }

  Widget _buildStats() {
    final learnCount = dayPlan.learnTasks.length;
    final reviseCount = dayPlan.reviseTasks.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statChip(
          icon: Icons.menu_book_rounded,
          label: '$learnCount',
          sublabel: 'Learned',
          color: AppColors.learnColor,
        ),
        const SizedBox(width: 16),
        _statChip(
          icon: Icons.psychology_rounded,
          label: '$reviseCount',
          sublabel: 'Revised',
          color: AppColors.reviseColor,
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 550.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: AppTextStyles.headlineMedium.copyWith(color: color)),
          Text(sublabel, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onContinue,
        child: Text(isGoalComplete ? 'View Summary' : 'Continue to Day ${dayPlan.dayNumber + 1}'),
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 400.ms)
        .slideY(begin: 0.4, end: 0);
  }
}
