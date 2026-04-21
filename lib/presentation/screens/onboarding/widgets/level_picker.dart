import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Dual-row level picker (Current Level + Target Level).
/// Fixed: uses Material+InkWell on each button instead of GestureDetector.
class LevelPicker extends StatelessWidget {
  final String currentLevel;
  final String targetLevel;
  final ValueChanged<String> onCurrentChanged;
  final ValueChanged<String> onTargetChanged;

  const LevelPicker({
    super.key,
    required this.currentLevel,
    required this.targetLevel,
    required this.onCurrentChanged,
    required this.onTargetChanged,
  });

  static const _levels = [
    _LevelOption('beginner', 'Beginner', Icons.spa_rounded),
    _LevelOption('intermediate', 'Inter.', Icons.trending_up_rounded),
    _LevelOption('advanced', 'Advanced', Icons.local_fire_department_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Level row
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Level', style: AppTextStyles.titleMedium),
            const SizedBox(height: 14),
            Row(
              children: _levels.map((opt) {
                final isLast = opt == _levels.last;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: _LevelButton(
                      option: opt,
                      isSelected: currentLevel == opt.value,
                      onTap: () => onCurrentChanged(opt.value),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ).animate().fadeIn(delay: 550.ms, duration: 400.ms),

        const SizedBox(height: 24),

        // Target Level row
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target Level', style: AppTextStyles.titleMedium),
            const SizedBox(height: 14),
            Row(
              children: _levels.map((opt) {
                final isLast = opt == _levels.last;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: _LevelButton(
                      option: opt,
                      isSelected: targetLevel == opt.value,
                      onTap: () => onTargetChanged(opt.value),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
      ],
    );
  }
}

class _LevelOption {
  final String value;
  final String label;
  final IconData icon;

  const _LevelOption(this.value, this.label, this.icon);
}

class _LevelButton extends StatelessWidget {
  final _LevelOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelButton({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentAmber.withOpacity(0.15)
              : AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accentAmber : AppColors.borderCard,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            splashColor: AppColors.accentAmber.withOpacity(0.12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Icon(
                    option.icon,
                    size: 20,
                    color: isSelected
                        ? AppColors.accentAmber
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected
                          ? AppColors.accentAmber
                          : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
