import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Duration slider widget (7–90 days).
/// Extracted from GoalSetupScreen to reduce unnecessary rebuilds.
class DurationSlider extends StatelessWidget {
  final double days;
  final ValueChanged<double> onChanged;

  const DurationSlider({
    super.key,
    required this.days,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Duration', style: AppTextStyles.titleMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${days.round()} days',
                style:
                    AppTextStyles.labelLarge.copyWith(color: AppColors.accentAmber),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.accentAmber,
            inactiveTrackColor: AppColors.progressTrack,
            thumbColor: AppColors.accentAmber,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            overlayColor: AppColors.accentAmber.withOpacity(0.15),
          ),
          child: Slider(
            value: days,
            min: 7,
            max: 90,
            divisions: 83,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('7 days', style: AppTextStyles.bodySmall),
            Text('90 days', style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 650.ms, duration: 400.ms);
  }
}
