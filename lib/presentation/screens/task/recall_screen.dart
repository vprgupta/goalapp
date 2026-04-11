import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/task_model.dart';

class RecallScreen extends StatefulWidget {
  final TaskModel task;

  const RecallScreen({super.key, required this.task});

  @override
  State<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends State<RecallScreen> {
  RecallPrompt get _prompt => widget.task.recallPrompt!;
  int? _selectedOption;
  bool _revealed = false;

  void _selectOption(int idx) {
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = idx;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  void _submitResult(bool correct) {
    context.pop({'correct': correct});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(null),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.reviseColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'RECALL',
                style: AppTextStyles.tagStyle
                    .copyWith(color: AppColors.reviseColor),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopicChip(),
              const SizedBox(height: 24),
              _buildPromptCard(),
              const SizedBox(height: 24),
              if (_prompt.type == PromptType.miniQuiz) _buildQuizOptions(),
              if (_prompt.type == PromptType.flashcard) _buildFlashcardReveal(),
              if (_prompt.type == PromptType.question) _buildSelfRating(),
              const Spacer(),
              if (_revealed || _prompt.type == PromptType.question)
                _buildResultButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Text(
        widget.task.title.replaceFirst('Revise: ', ''),
        style: AppTextStyles.bodyMedium,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_promptIcon(), color: AppColors.reviseColor, size: 20),
              const SizedBox(width: 8),
              Text(_promptTypeLabel(),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.reviseColor)),
            ],
          ),
          const SizedBox(height: 14),
          Text(_prompt.prompt,
              style: AppTextStyles.titleLarge.copyWith(height: 1.5)),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  IconData _promptIcon() {
    return switch (_prompt.type) {
      PromptType.question => Icons.help_outline_rounded,
      PromptType.flashcard => Icons.flash_on_rounded,
      PromptType.miniQuiz => Icons.quiz_rounded,
    };
  }

  String _promptTypeLabel() {
    return switch (_prompt.type) {
      PromptType.question => 'OPEN QUESTION',
      PromptType.flashcard => 'FLASHCARD',
      PromptType.miniQuiz => 'MINI QUIZ',
    };
  }

  Widget _buildQuizOptions() {
    return Column(
      children: _prompt.options!.asMap().entries.map((entry) {
        final idx = entry.key;
        final opt = entry.value;
        final isCorrect = opt == _prompt.answer;
        final isSelected = _selectedOption == idx;

        Color borderColor = AppColors.borderCard;
        Color bgColor = AppColors.backgroundCard;
        Widget? trailingIcon;

        if (_selectedOption != null) {
          if (isCorrect) {
            borderColor = AppColors.accentGreen;
            bgColor = AppColors.accentGreen.withOpacity(0.1);
            trailingIcon = const Icon(Icons.check_circle_rounded,
                color: AppColors.accentGreen, size: 20);
          } else if (isSelected) {
            borderColor = AppColors.accentRed;
            bgColor = AppColors.accentRed.withOpacity(0.1);
            trailingIcon = const Icon(Icons.cancel_rounded,
                color: AppColors.accentRed, size: 20);
          }
        }

        return GestureDetector(
          onTap: () => _selectOption(idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(opt, style: AppTextStyles.bodyLarge),
                ),
                if (trailingIcon != null) trailingIcon,
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: 200 + idx * 80))
            .slideX(begin: 0.05, end: 0);
      }).toList(),
    );
  }

  Widget _buildFlashcardReveal() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _revealed
                ? null
                : () => setState(() => _revealed = true),
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('Reveal Answer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentAmber,
              side: const BorderSide(color: AppColors.accentAmber),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_revealed) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accentAmber.withOpacity(0.3)),
            ),
            child: Text(_prompt.answer ?? '', style: AppTextStyles.bodyLarge),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.1, end: 0),
        ],
      ],
    );
  }

  Widget _buildSelfRating() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Text(
        'Take a moment to think, then rate your recall below.',
        style: AppTextStyles.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildResultButtons() {
    return Column(
      children: [
        Text('How did you do?',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _submitResult(false),
                icon: const Icon(Icons.sentiment_dissatisfied_rounded,
                    size: 18),
                label: const Text('Struggled'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentRed,
                  side: const BorderSide(color: AppColors.accentRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _submitResult(true),
                icon: const Icon(Icons.thumb_up_rounded, size: 18),
                label: const Text('Got it!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 350.ms)
        .slideY(begin: 0.2, end: 0);
  }
}
