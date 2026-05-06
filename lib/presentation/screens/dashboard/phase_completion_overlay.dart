import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Phase Completion Celebration dialog.
/// Shown when all topics in a phase are marked as learned.
class PhaseCompletionOverlay extends StatelessWidget {
  final String phaseName;
  final int topicsCompleted;
  final int xpEarned;
  final VoidCallback onContinue;

  const PhaseCompletionOverlay({
    super.key,
    required this.phaseName,
    required this.topicsCompleted,
    required this.xpEarned,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trophy icon
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentAmber.withOpacity(0.25),
                      AppColors.accentAmber.withOpacity(0.0),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.accentAmber.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: AppColors.glowAmber, blurRadius: 30),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 52,
                  color: AppColors.accentAmber,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.08, duration: 1200.ms, curve: Curves.easeInOut),

              const SizedBox(height: 32),

              Text(
                '🎉 Phase Complete!',
                style: AppTextStyles.headlineLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

              const SizedBox(height: 12),

              Text(
                phaseName,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.accentAmber,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 24),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatChip(
                    icon: Icons.check_circle_rounded,
                    label: '$topicsCompleted Topics',
                    color: AppColors.accentGreen,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.bolt_rounded,
                    label: '+$xpEarned XP',
                    color: const Color(0xFFB197FC),
                  ),
                ],
              ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 48),

              // Stars decoration
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star_rounded,
                      color: AppColors.accentAmber,
                      size: 24,
                    )
                        .animate(delay: Duration(milliseconds: 100 * i))
                        .scale(begin: const Offset(0, 0), end: const Offset(1, 1))
                        .fadeIn(),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue to Next Phase'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(280, 54),
                  backgroundColor: AppColors.accentAmber,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ).animate().fadeIn(delay: 900.ms).scaleXY(begin: 0.9),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
