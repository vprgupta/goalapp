import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/task_model.dart';

class TaskCardWidget extends StatefulWidget {
  final TaskModel task;
  final String topicName;
  final String? thumbnailUrl;
  final void Function({bool? recallCorrect}) onComplete;
  final bool isCompleted;

  const TaskCardWidget({
    super.key,
    required this.task,
    required this.topicName,
    this.thumbnailUrl,
    required this.onComplete,
    required this.isCompleted,
  });

  @override
  State<TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends State<TaskCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    if (widget.isCompleted) _checkController.forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.isCompleted || _tapped) return;

    bool? recallResult;

    if (widget.task.isRevise && widget.task.recallPrompt != null) {
      // Navigate to recall screen for revision tasks
      final result = await context.push('/recall', extra: widget.task);
      
      // If user popped without answer (null), don't complete
      if (result == null || result is! Map || !result.containsKey('correct')) return;
      
      recallResult = result['correct'] as bool;
    }

    if (!mounted) return;

    setState(() => _tapped = true);
    _checkController.forward().then((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          widget.onComplete(recallCorrect: recallResult);
        });
      }
    });
  }

  Future<void> _launchYouTube() async {
    if (widget.task.videoId == null) return;
    
    final String url = 'https://www.youtube.com/watch?v=${widget.task.videoId}&t=${widget.task.startSeconds}';
    final Uri uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRevise = widget.task.isRevise;
    final typeColor = isRevise ? AppColors.reviseColor : AppColors.learnColor;
    final typeLabel = isRevise ? 'REVISE' : 'LEARN';
    final typeIcon = isRevise
        ? Icons.psychology_rounded
        : Icons.menu_book_rounded;

    return AnimatedOpacity(
      opacity: widget.isCompleted ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isCompleted
                ? AppColors.borderSubtle
                : AppColors.borderCard,
          ),
          boxShadow: widget.isCompleted
              ? []
              : [
                  BoxShadow(
                    color: typeColor.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: typeColor.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildTypeIndicator(typeColor, typeIcon),
                  const SizedBox(width: 14),
                  Expanded(child: _buildContent(typeLabel, typeColor)),
                  const SizedBox(width: 12),
                  _buildCheckbox(typeColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIndicator(Color color, IconData icon) {
    if (widget.thumbnailUrl != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: CachedNetworkImage(
            imageUrl: widget.thumbnailUrl!,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(color: AppColors.backgroundDark),
            errorWidget: (ctx, url, err) => Icon(icon, color: color, size: 20),
          ),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildYouTubeButton() {
    if (widget.task.videoId == null) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: _launchYouTube,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF0000).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.play_circle_fill_rounded, 
             size: 14, color: Color(0xFFFF0000)),
             const SizedBox(width: 4),
             Text(
               'Resume at ${widget.task.startSeconds ~/ 60}m',
               style: AppTextStyles.labelSmall.copyWith(
                 color: const Color(0xFFFF0000),
                 fontSize: 9,
                 fontWeight: FontWeight.bold,
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(String typeLabel, Color typeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                typeLabel,
                style: AppTextStyles.tagStyle.copyWith(color: typeColor),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 3),
            Text(
              '~${widget.task.estimatedMinutes} min',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.task.title,
          style: AppTextStyles.titleMedium.copyWith(
            decoration: widget.isCompleted
                ? TextDecoration.lineThrough
                : null,
            decorationColor: AppColors.textMuted,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        _buildYouTubeButton(),
        if (widget.task.isRevise) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.arrow_circle_right_outlined,
                  size: 12, color: AppColors.accentAmber),
              const SizedBox(width: 4),
              Text(
                'Tap to recall',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.accentAmber),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCheckbox(Color typeColor) {
    return AnimatedBuilder(
      animation: _checkController,
      builder: (context, child) {
        final value = _checkController.value;
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isCompleted || _tapped
                ? AppColors.accentGreen
                : Colors.transparent,
            border: Border.all(
              color: widget.isCompleted || _tapped
                  ? AppColors.accentGreen
                  : AppColors.borderCard,
              width: 2,
            ),
          ),
          child: (widget.isCompleted || value > 0.5)
              ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 16)
                  .animate()
                  .scale(
                    duration: 200.ms,
                    curve: Curves.elasticOut,
                  )
              : null,
        );
      },
    );
  }
}
