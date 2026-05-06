import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/day_plan_model.dart';
import '../../../data/models/goal_model.dart';
import '../../../domain/services/user_progress_service.dart';

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
    final streak = UserProgressService.currentStreak;
    final level = UserProgressService.level;
    final title = UserProgressService.levelTitle;
    final sprintPercent =
        ((dayPlan.dayNumber / goal.totalDays) * 100).round().clamp(0, 100);

    return Material(
      color: Colors.black.withOpacity(0.88),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTrophyAnimation(),
                const SizedBox(height: 24),
                _buildTitle(),
                const SizedBox(height: 10),
                _buildSubtitle(),
                const SizedBox(height: 24),

                // G5: Sprint progress arc
                _buildSprintProgress(sprintPercent),
                const SizedBox(height: 20),

                _buildStats(streak, level, title),
                const SizedBox(height: 36),
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
            color: AppColors.accentAmber.withOpacity(0.45),
            blurRadius: 36,
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
    final t = isGoalComplete ? 'Sprint Complete! 🎉' : 'Day ${dayPlan.dayNumber} Done!';
    return Text(t, style: AppTextStyles.displayMedium, textAlign: TextAlign.center)
        .animate()
        .fadeIn(delay: 300.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildSubtitle() {
    final msg = isGoalComplete
        ? 'You mastered "${goal.name}". Outstanding! 🌟'
        : 'Keep the momentum. Day ${dayPlan.dayNumber + 1} is unlocked!';
    return Text(msg,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center)
        .animate()
        .fadeIn(delay: 420.ms, duration: 400.ms);
  }

  // G5: Mini sprint progress bar
  Widget _buildSprintProgress(int percent) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sprint Progress',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            Text(
              '$percent%',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accentAmber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              minHeight: 7,
              backgroundColor: AppColors.progressTrack,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentAmber),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 480.ms, duration: 400.ms);
  }

  Widget _buildStats(int streak, int level, String levelTitle) {
    final learnCount = dayPlan.learnTasks.length;
    final reviseCount = dayPlan.reviseTasks.length;
    return Column(
      children: [
        // Task chips row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _statChip(
              icon: Icons.menu_book_rounded,
              label: '$learnCount',
              sublabel: 'Learned',
              color: AppColors.learnColor,
            ),
            const SizedBox(width: 14),
            _statChip(
              icon: Icons.psychology_rounded,
              label: '$reviseCount',
              sublabel: 'Revised',
              color: AppColors.reviseColor,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // G5: Streak + level row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.accentAmber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 14, color: AppColors.accentAmber),
                  const SizedBox(width: 5),
                  Text(
                    '$streak-day streak 🔥',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.accentAmber,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFB197FC).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFB197FC).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded,
                      size: 14, color: Color(0xFFB197FC)),
                  const SizedBox(width: 5),
                  Text(
                    'Lv.$level $levelTitle',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: const Color(0xFFB197FC),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 540.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 5),
          Text(label, style: AppTextStyles.headlineMedium.copyWith(color: color)),
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
        child: Text(
            isGoalComplete ? 'View Summary' : 'Continue to Day ${dayPlan.dayNumber + 1}'),
      ),
    )
        .animate()
        .fadeIn(delay: 680.ms, duration: 400.ms)
        .slideY(begin: 0.4, end: 0);
  }
}
