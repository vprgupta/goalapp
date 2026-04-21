import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../providers/generation_provider.dart';

/// Full-screen loading state shown while generating a roadmap.
///
/// Fixes applied (per flutter-building-layouts skill):
/// 1. Wrapped Column in [SingleChildScrollView] to prevent overflow on short screens.
/// 2. Replaced hardcoded `width: 160` progress bar with [FractionallySizedBox] (50% of available width).
class LoadingStateView extends ConsumerStatefulWidget {
  final String currentLevel;
  final String targetLevel;
  final String currentStatus;
  final String currentTip;

  const LoadingStateView({
    super.key,
    required this.currentLevel,
    required this.targetLevel,
    required this.currentStatus,
    required this.currentTip,
  });

  @override
  ConsumerState<LoadingStateView> createState() => _LoadingStateViewState();
}

class _LoadingStateViewState extends ConsumerState<LoadingStateView> {
  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('loading'),
      // Fix #1: SingleChildScrollView prevents overflow on short/split-screen devices
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            _buildPulsingIcon(),
            const SizedBox(height: 48),
            _buildStatusText(),
            const SizedBox(height: 12),
            _buildLevelRow(),
            const SizedBox(height: 64),
            _buildConsoleOrTips(),
            const SizedBox(height: 56),
            _buildProgressBar(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Aura
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.accentAmber.withOpacity(0.2),
                AppColors.accentAmber.withOpacity(0.05),
                Colors.transparent,
              ],
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.3, 1.3),
                duration: 2.seconds,
                curve: Curves.easeInOut)
            .fadeOut(duration: 2.seconds, curve: Curves.easeInOut),

        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated,
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.accentAmber.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentAmber.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 40,
            color: AppColors.accentAmber,
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 3.seconds, color: Colors.white24)
            .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1.5.seconds,
                curve: Curves.easeInOut)
            .then()
            .scale(
                begin: const Offset(1.05, 1.05),
                end: const Offset(1, 1),
                duration: 1.5.seconds,
                curve: Curves.easeInOut),
      ],
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        widget.currentStatus,
        key: ValueKey(widget.currentStatus),
        style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLevelRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Personalizing for ',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        Text(
          widget.currentLevel.toUpperCase(),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.accentAmber,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Text(
          ' ➔ ',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        Text(
          widget.targetLevel.toUpperCase(),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.accentAmber,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildConsoleOrTips() {
    final genState = ref.watch(generationProvider);

    if (genState.isGenerating || genState.buffer.isNotEmpty) {
      return Container(
        width: double.infinity,
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_rounded,
                    size: 16, color: AppColors.accentAmber),
                const SizedBox(width: 8),
                Text(
                  'AI THINKING PROCESS',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accentAmber,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'STREAMING',
                    style: AppTextStyles.labelSmall
                        .copyWith(fontSize: 8, color: AppColors.accentAmber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  genState.buffer,
                  style: const TextStyle(
                    color: Color(0xFFADFF2F),
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default Tips View
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                    color: AppColors.accentAmber, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text(
                'MASTER TIPS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accentAmber.withOpacity(0.8),
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                    color: AppColors.accentAmber, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Text(
              widget.currentTip,
              key: ValueKey(widget.currentTip),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary.withOpacity(0.9),
                fontStyle: FontStyle.italic,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildProgressBar() {
    // Fix #2: Use FractionallySizedBox instead of hardcoded width: 160
    // This correctly adapts to whatever space the parent provides.
    return FractionallySizedBox(
      widthFactor: 0.5,
      child: Stack(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.accentAmber.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1200.ms);
  }
}
