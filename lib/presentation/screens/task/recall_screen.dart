import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/task_model.dart';
import '../../providers/goal_provider.dart';

class RecallScreen extends ConsumerStatefulWidget {
  final TaskModel task;
  final List<String> subTopics;
  final int revisionCount;

  const RecallScreen({
    super.key,
    required this.task,
    this.subTopics = const [],
    this.revisionCount = 0,
  });

  @override
  ConsumerState<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends ConsumerState<RecallScreen> {
  RecallPrompt get _prompt => widget.task.recallPrompt!;
  int? _selectedOption;
  bool _revealed = false;
  final Set<String> _tickedTopics = {};

  // Resolved topic data (from props or Hive fallback)
  List<String> _subTopics = [];
  int _revisionCount = 0;

  @override
  void initState() {
    super.initState();
    // Start with whatever was passed in
    _subTopics = List.from(widget.subTopics);
    _revisionCount = widget.revisionCount;

    // Always also load from Hive on first frame — this is the source of truth
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromHive());
  }

  void _loadFromHive() {
    final topic = ref.read(goalRepositoryProvider).getTopic(widget.task.topicId);
    if (topic != null && mounted) {
      setState(() {
        // Always use Hive data if it has more/current info
        if (topic.subTopics.isNotEmpty) {
          _subTopics = List.from(topic.subTopics);
        }
        _revisionCount = topic.revisionCount;
      });
    }
  }

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

  void _toggleTopic(String topic) {
    setState(() {
      if (_tickedTopics.contains(topic)) {
        _tickedTopics.remove(topic);
      } else {
        _tickedTopics.add(topic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => context.pop(null),
        ),
        centerTitle: false,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.reviseColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'RECALL SESSION',
            style: AppTextStyles.tagStyle
                .copyWith(color: AppColors.reviseColor, letterSpacing: 1.2),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _buildTopicChip()),
                  if (_revisionCount > 0) ...[
                    const SizedBox(width: 12),
                    _buildRevisionBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              _buildPromptCard(),
              const SizedBox(height: 24),
              
              if (_subTopics.isNotEmpty) ...[
                _buildSectionHeader('Your Saved Topics'),
                const SizedBox(height: 12),
                _buildSubTopicsList(),
                const SizedBox(height: 28),
              ],

              _buildSectionHeader('The Challenge'),
              const SizedBox(height: 12),
              if (_prompt.type == PromptType.miniQuiz) _buildQuizOptions(),
              if (_prompt.type == PromptType.flashcard) _buildFlashcardReveal(),
              if (_prompt.type == PromptType.question) _buildSelfRating(),
              
              const SizedBox(height: 40),
              if (_revealed || _prompt.type == PromptType.question)
                _buildResultButtons(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 1.5,
        fontWeight: FontWeight.bold,
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildRevisionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, color: AppColors.accentTeal, size: 14),
          const SizedBox(width: 6),
          Text(
            'Revised ${_revisionCount}x',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.accentTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSubTopicsList() {
    return Column(
      children: _subTopics.map((sub) {
        final isTicked = _tickedTopics.contains(sub);
        return GestureDetector(
          onTap: () => _toggleTopic(sub),
          child: AnimatedContainer(
            duration: 250.ms,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isTicked 
                  ? AppColors.accentGreen.withOpacity(0.08) 
                  : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTicked ? AppColors.accentGreen : AppColors.borderCard,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: 200.ms,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isTicked ? AppColors.accentGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isTicked ? AppColors.accentGreen : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: isTicked 
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    sub,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isTicked ? AppColors.textPrimary : AppColors.textSecondary,
                      decoration: isTicked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08, end: 0);
      }).toList(),
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
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_promptIcon(), color: AppColors.reviseColor, size: 20),
              const SizedBox(width: 10),
              Text(_promptTypeLabel(),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.reviseColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(_prompt.prompt,
              style: AppTextStyles.titleLarge.copyWith(height: 1.4, fontSize: 20)),
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
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
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
              side: const BorderSide(color: AppColors.accentAmber, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_revealed) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.accentAmber.withOpacity(0.3), width: 1.5),
            ),
            child: Text(_prompt.answer ?? '', style: AppTextStyles.bodyLarge.copyWith(height: 1.5)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Text(
        'Take a moment to think, then rate your recall below.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildResultButtons() {
    return Column(
      children: [
        const Divider(color: AppColors.borderSubtle, height: 40),
        Text('How did you do?',
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _submitResult(false),
                icon: const Icon(Icons.sentiment_dissatisfied_rounded,
                    size: 20),
                label: const Text('Struggled'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentRed,
                  side: const BorderSide(color: AppColors.accentRed, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _submitResult(true),
                icon: const Icon(Icons.thumb_up_rounded, size: 20),
                label: const Text('Got it!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                  shadowColor: AppColors.accentGreen.withOpacity(0.4),
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
