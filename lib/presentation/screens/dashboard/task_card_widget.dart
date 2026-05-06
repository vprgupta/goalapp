import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isBoss; // G4: milestone badge + gold glow

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
    this.isBoss = false,
  });

  @override
  State<TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends State<TaskCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  final GlobalKey _checkKey = GlobalKey(); // G1: XP float anchor
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
      final result = await context.push('/recall', extra: {
        'task': widget.task,
        'subTopics': widget.subTopics,
        'revisionCount': widget.subTopics.isNotEmpty ? widget.subTopics.length : 0,
      });

      if (result == null || result is! Map || !result.containsKey('correct')) return;
      _onCompleteAction(recallResult: result['correct'] as bool);
    } else {
      if (!widget.isExpanded && widget.onDeepDive != null) {
        widget.onDeepDive!();
      } else {
        context.push('/topic-resources/${widget.task.topicId}');
      }
    }
  }

  void _onCompleteAction({bool? recallResult}) {
    if (_tapped) return;
    setState(() => _tapped = true);
    HapticFeedback.lightImpact(); // G1: haptic
    _checkController.forward().then((_) {
      if (mounted) {
        _showXpFloat(context); // G1: floating XP badge
        Future.delayed(const Duration(milliseconds: 200), () {
          widget.onComplete(recallCorrect: recallResult);
        });
      }
    });
  }

  // G1: Show floating "+XP ⚡" label above the checkbox
  void _showXpFloat(BuildContext context) {
    final xp = widget.isBoss ? 25 : widget.task.isRevise ? 5 : 10;
    final renderBox =
        _checkKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => _XpFloatBadge(
        xp: xp,
        position: pos,
        onDone: () => entry?.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  Future<void> _launchYouTube() async {
    if (widget.task.videoId == null) return;
    final String url =
        'https://www.youtube.com/watch?v=${widget.task.videoId}&t=${widget.task.startSeconds}';
    final Uri uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      debugPrint('Could not launch YouTube: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open YouTube')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.task.isRevise ? _buildReviseCard() : _buildLearnCard();
  }

  // ── REVISE card ─────────────────────────────────────────────────────────────
  Widget _buildReviseCard() {
    const reviseColor = Color(0xFF9B8FFF);
    const reviseBg = Color(0xFF13102A);
    // G4: Boss tasks get a gold glow border
    final borderColor = widget.isCompleted
        ? AppColors.borderSubtle
        : widget.isBoss
            ? AppColors.accentAmber.withOpacity(0.6)
            : reviseColor.withOpacity(0.4);
    final bossShadow = widget.isBoss && !widget.isCompleted
        ? [const BoxShadow(color: AppColors.glowAmber, blurRadius: 16)]
        : <BoxShadow>[];

    return AnimatedOpacity(
      opacity: widget.isCompleted ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 14),
        decoration: BoxDecoration(
          color: widget.isCompleted ? AppColors.backgroundCard : reviseBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: widget.isBoss ? 1.5 : 1.0),
          boxShadow: bossShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: reviseColor.withOpacity(0.08),
            child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          // G4: MILESTONE badge for boss tasks
                          if (widget.isBoss) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFFFD700), Color(0xFFFF9500)
                                ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('⚡ MILESTONE', style: TextStyle(
                                fontFamily: 'Outfit', fontSize: 8,
                                fontWeight: FontWeight.w900, color: Colors.black,
                              )),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  reviseColor.withOpacity(0.25),
                                  reviseColor.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: reviseColor.withOpacity(0.45)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.psychology_rounded, size: 11, color: reviseColor),
                                SizedBox(width: 4),
                                Text(
                                  'RECALL',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: reviseColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const ExcludeSemantics(
                            child: Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '~${widget.task.estimatedMinutes}m',
                            style: AppTextStyles.bodySmall,
                          ),
                          const Spacer(),
                          _buildCheckbox(reviseColor),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.task.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.task.recallPrompt != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: reviseColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: reviseColor.withOpacity(0.18)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.quiz_rounded, size: 13, color: reviseColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.task.recallPrompt!.prompt,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (widget.subTopics.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildSubTopicChips(reviseColor),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.arrow_circle_right_outlined,
                              size: 13, color: reviseColor),
                          const SizedBox(width: 5),
                          Text(
                            'Tap to start recall session',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: reviseColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }

  // ── LEARN card ───────────────────────────────────────────────────────────────
  Widget _buildLearnCard() {
    const learnColor = AppColors.learnColor;
    // G4: Boss tasks get amber glow border
    final borderColor = widget.isCompleted
        ? AppColors.borderSubtle
        : widget.isBoss
            ? AppColors.accentAmber.withOpacity(0.55)
            : AppColors.borderCard;
    final bossShadow = widget.isBoss && !widget.isCompleted
        ? [const BoxShadow(color: AppColors.glowAmber, blurRadius: 18)]
        : <BoxShadow>[];

    return AnimatedOpacity(
      opacity: widget.isCompleted ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: widget.isBoss ? 1.5 : 1.0),
          boxShadow: bossShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: learnColor.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // G4: MILESTONE badge for boss topics
                        if (widget.isBoss) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFFD700), Color(0xFFFF9500)
                              ]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('⚡ MILESTONE', style: TextStyle(
                              fontFamily: 'Outfit', fontSize: 8,
                              fontWeight: FontWeight.w900, color: Colors.black,
                            )),
                          ),
                        ],
                        _buildContent('LEARN', learnColor),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildCheckbox(learnColor),
                  ),
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CachedNetworkImage(
            imageUrl: widget.thumbnailUrl!,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(color: AppColors.backgroundDark),
            errorWidget: (ctx, url, err) => Icon(icon, color: color, size: 22),
          ),
        ),
      );
    }

    return Hero(
      tag: 'topic_icon_${widget.task.topicId}',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.2), color.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildYouTubeButton() {
    if (widget.task.videoId == null || widget.task.isRevise) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _launchYouTube,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF0000).withOpacity(0.15),
              const Color(0xFFFF0000).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill_rounded, size: 14, color: Color(0xFFFF4444)),
            const SizedBox(width: 5),
            Text(
              'Resume at ${widget.task.startSeconds ~/ 60}m',
              style: AppTextStyles.labelSmall.copyWith(
                color: const Color(0xFFFF4444),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isExpanding
                  ? [AppColors.backgroundDark, AppColors.backgroundElevated]
                  : [AppColors.gradientAmberStart, AppColors.gradientAmberEnd],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isExpanding
                ? []
                : const [
                    BoxShadow(color: AppColors.glowAmber, blurRadius: 12, offset: Offset(0, 4)),
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
                const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.isExpanding ? 'BLUEPRINTING...' : 'GENERATE ATOMIC BLUEPRINT',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: widget.isExpanding ? AppColors.accentAmber : Colors.white,
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
            duration: widget.isExpanding ? 1000.ms : 1500.ms,
          );
    }

    final hubButton = GestureDetector(
      onTap: () => context.push('/topic-resources/${widget.task.topicId}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentAmber.withOpacity(0.18),
              AppColors.accentAmber.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentAmber.withOpacity(0.45), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.menu_book_rounded, size: 14, color: AppColors.accentAmber),
            ),
            const SizedBox(width: 8),
            // G7: Show XP reward and time estimate so the tap feels like a transaction
            Text(
              'Start Learning  →  +10 XP · ~${widget.task.estimatedMinutes}min',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accentAmber,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Explore Learning Hub',
      child: hubButton
          .animate()
          .fadeIn(delay: 300.ms)
          .shimmer(delay: 2000.ms, duration: 1500.ms, color: Colors.white12),
    );
  }

  Widget _buildContent(String typeLabel, Color typeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor.withOpacity(0.18), typeColor.withOpacity(0.07)],
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: typeColor.withOpacity(0.25)),
              ),
              child: Text(
                typeLabel,
                style: AppTextStyles.tagStyle.copyWith(color: typeColor, fontSize: 9),
              ),
            ),
            if (widget.moduleName != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
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
            const SizedBox(width: 6),
            const ExcludeSemantics(
              child: Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
            ),
            const SizedBox(width: 3),
            Text(
              '~${widget.task.estimatedMinutes}m',
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          widget.task.title,
          style: AppTextStyles.titleMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.textMuted,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        _buildYouTubeButton(),
        const SizedBox(height: 10),
        _buildResourceHubButton(context),
        if (widget.subTopics.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSubTopicChips(AppColors.accentTeal),
        ],
      ],
    );
  }

  Widget _buildSubTopicChips(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 10, color: accentColor.withOpacity(0.8)),
            const SizedBox(width: 5),
            Text(
              'KEY CONCEPTS',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 8,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final chipMaxWidth = constraints.maxWidth * 0.88;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.subTopics.map((topic) {
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: chipMaxWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.1),
                          AppColors.backgroundElevated,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 10, color: accentColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            topic,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textPrimary.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCheckbox(Color typeColor) {
    return GestureDetector(
      key: _checkKey, // G1: anchor for XP float position
      onTap: widget.isCompleted ? null : () => _onCompleteAction(),
      child: AnimatedBuilder(
        animation: _checkController,
        builder: (context, child) {
          final isDone = widget.isCompleted || _tapped;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isDone
                  ? const LinearGradient(
                      colors: [AppColors.gradientGreenStart, AppColors.gradientGreenEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isDone ? null : Colors.transparent,
              border: Border.all(
                color: isDone ? AppColors.accentGreen : AppColors.borderCard,
                width: 2,
              ),
              boxShadow: isDone
                  ? const [BoxShadow(color: AppColors.glowGreen, blurRadius: 14)]
                  : [],
            ),
            child: Semantics(
              checked: isDone,
              label: 'Task completion status',
              child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      .animate()
                      .scale(duration: 200.ms, curve: Curves.elasticOut)
                  : Icon(
                      Icons.circle_outlined,
                      size: 14,
                      color: AppColors.textMuted.withOpacity(0.35),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ── G1: Floating XP badge overlay ────────────────────────────────────────────
class _XpFloatBadge extends StatefulWidget {
  final int xp;
  final Offset position;
  final VoidCallback onDone;
  const _XpFloatBadge(
      {required this.xp, required this.position, required this.onDone});
  @override
  State<_XpFloatBadge> createState() => _XpFloatBadgeState();
}

class _XpFloatBadgeState extends State<_XpFloatBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _dy;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
    _dy = Tween(begin: 0.0, end: -64.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: widget.position.dx - 24,
        top: widget.position.dy + _dy.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB197FC), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: AppColors.glowPurple, blurRadius: 12)
                ],
              ),
              child: Text(
                '+${widget.xp} XP ⚡',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
