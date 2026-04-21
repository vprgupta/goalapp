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
  final String? moduleName;
  final String? thumbnailUrl;
  final List<String> subTopics;
  final void Function({bool? recallCorrect}) onComplete;
  final VoidCallback? onDeepDive;
  final bool isCompleted;
  final bool isExpanded;
  final bool isExpanding;

  const TaskCardWidget({
    super.key,
    required this.task,
    required this.topicName,
    this.moduleName,
    this.thumbnailUrl,
    this.subTopics = const [],
    required this.onComplete,
    this.onDeepDive,
    required this.isCompleted,
    this.isExpanded = true,
    this.isExpanding = false,
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
    if (widget.isCompleted) return;

    if (widget.task.isRevise && widget.task.recallPrompt != null) {
      // Navigate to recall screen
      final result = await context.push('/recall', extra: {
        'task': widget.task,
        'subTopics': widget.subTopics,
        'revisionCount': widget.subTopics.isNotEmpty ? widget.subTopics.length : 0,
      });
      
      if (result == null || result is! Map || !result.containsKey('correct')) return;
      _onCompleteAction(recallResult: result['correct'] as bool);
    } else {
      // For LEARN tasks, if it's an unexpanded pillar, trigger deep dive
      if (!widget.isExpanded && widget.onDeepDive != null) {
        widget.onDeepDive!();
      } else {
        // Otherwise, open the Learning Hub
        context.push('/topic-resources/${widget.task.topicId}');
      }
    }
  }

  void _onCompleteAction({bool? recallResult}) {
    if (_tapped) return;
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
    
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
      }
    } catch (e) {
      debugPrint('Could not launch YouTube: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open YouTube')),
        );
      }
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

    return Hero(
      tag: 'topic_icon_${widget.task.topicId}',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildYouTubeButton() {
    if (widget.task.videoId == null || widget.task.isRevise) return const SizedBox.shrink();
    
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

  Widget _buildResourceHubButton(BuildContext context) {
    if (widget.isCompleted) return const SizedBox.shrink();
    
    if (!widget.isExpanded) {
      return GestureDetector(
        onTap: widget.isExpanding ? null : widget.onDeepDive,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isExpanding 
                ? [AppColors.backgroundDark, AppColors.backgroundElevated]
                : [AppColors.accentAmber, const Color(0xFFFF6B2B)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.isExpanding ? [] : [
              BoxShadow(
                color: AppColors.accentAmber.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isExpanding)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentAmber),
                  ),
                )
              else
                const Icon(Icons.bolt_rounded, size: 16, color: AppColors.backgroundDark),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.isExpanding ? 'BLUEPRINTING...' : 'GENERATE ATOMIC BLUEPRINT',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: widget.isExpanding ? AppColors.accentAmber : AppColors.backgroundDark,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ).animate().shimmer(
        delay: widget.isExpanding ? 0.ms : 1000.ms, 
        duration: widget.isExpanding ? 1000.ms : 1500.ms
      );
    }

    final hubButton = GestureDetector(
      onTap: () => context.push('/topic-resources/${widget.task.topicId}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentAmber.withOpacity(0.15),
              AppColors.accentAmber.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accentAmber.withOpacity(0.4), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.hub_rounded, size: 14, color: AppColors.accentAmber),
            ),
            const SizedBox(width: 8),
            Text(
              'Explore Learning Hub',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accentAmber,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.accentAmber),
          ],
        ),
      ),
    );
    
    // flutter-improving-accessibility: explicitly mark this container as a button 
    return Semantics(
      button: true,
      label: 'Explore Learning Hub',
      child: hubButton.animate().fadeIn(delay: 300.ms).shimmer(delay: 2000.ms, duration: 1500.ms, color: Colors.white12),
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
            if (widget.moduleName != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    widget.moduleName!.toUpperCase(),
                    style: AppTextStyles.tagStyle.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 8,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const ExcludeSemantics(
              child: Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
            ),
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
        const SizedBox(height: 8),
        _buildResourceHubButton(context),
        if (widget.subTopics.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildSubTopicChips(),
        ],
        if (widget.task.isRevise) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.arrow_circle_right_outlined,
                  size: 13, color: AppColors.accentAmber),
              const SizedBox(width: 5),
              Text(
                'Focus on Recall',
                style:
                    AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accentAmber,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSubTopicChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 10, color: AppColors.accentTeal.withOpacity(0.8)),
            const SizedBox(width: 5),
            Text(
              'KEY CONCEPTS',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 8,
                letterSpacing: 0.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.subTopics.map((topic) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderCard),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, 
                      size: 10, color: AppColors.accentGreen),
                  const SizedBox(width: 6),
                  Text(
                    topic,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textPrimary.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCheckbox(Color typeColor) {
    return GestureDetector(
      onTap: widget.isCompleted ? null : () => _onCompleteAction(),
      child: AnimatedBuilder(
        animation: _checkController,
        builder: (context, child) {
          final value = _checkController.value;
          return Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(2), // Hit area padding
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
            // flutter-improving-accessibility: Semantics for custom checkbox 
            child: Semantics(
              checked: widget.isCompleted || value > 0.5,
              label: 'Task completion status',
              child: (widget.isCompleted || value > 0.5)
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18)
                      .animate()
                      .scale(
                        duration: 200.ms,
                        curve: Curves.elasticOut,
                      )
                  : Icon(Icons.circle_outlined, size: 14, color: AppColors.textMuted.withOpacity(0.3)),
            ),
          );
        },
      ),
    );
  }
}
