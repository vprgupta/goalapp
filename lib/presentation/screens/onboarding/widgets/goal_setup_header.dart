import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Pure presentational header widget for the Goal Setup screen.
/// Stateless — receives no data, displays static branding + tagline.
class GoalSetupHeader extends StatelessWidget {
  const GoalSetupHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accentAmber, Color(0xFFFF6B35)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          'What do you\nwant to learn?',
          style: AppTextStyles.displayLarge.copyWith(height: 1.15),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'Build a science-backed plan that adapts to you.',
          style: AppTextStyles.bodyMedium,
        ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
      ],
    );
  }
}
