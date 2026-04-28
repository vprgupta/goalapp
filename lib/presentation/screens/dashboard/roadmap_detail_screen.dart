import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/topic_model.dart';
import '../../providers/goal_provider.dart';
import '../../providers/deep_dive_provider.dart';
import '../../providers/generation_provider.dart';

class RoadmapDetailScreen extends ConsumerWidget {
  final String roadmapId;
  const RoadmapDetailScreen({super.key, required this.roadmapId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(goalRepositoryProvider);
    final roadmap = repo.getGoal(roadmapId);
    if (roadmap == null) {
      return const Scaffold(body: Center(child: Text('Roadmap not found')));
    }

    final allTopics = repo.getTopicsForGoal(roadmapId);

    // ── Pillar identification ──────────────────────────────────────────────
    // Pillars: moduleName starts with 'PHASE' (set from chapter in ai_service)
    // Sub-topics: moduleName = pillar.name (set in deep_dive_provider line 55)
    final pillars = allTopics
        .where((t) =>
            t.moduleName?.toUpperCase().startsWith('PHASE') == true ||
            (t.moduleName == null && !t.isBlueprintGenerated))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // For each pillar, collect its atomic sub-topics
    Map<String, List<TopicModel>> subTopicsByPillar = {};
    for (final pillar in pillars) {
      subTopicsByPillar[pillar.id] =
          allTopics.where((t) => t.moduleName == pillar.name).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // ── Completion tracking ────────────────────────────────────────────────
    // A pillar is "completed" when it has been blueprinted AND
    // all its sub-topics have been learned (learnedOnDay > 0)
    int completedCount = 0;
    for (final pillar in pillars) {
      final subs = subTopicsByPillar[pillar.id] ?? [];
      if (pillar.isBlueprintGenerated &&
          subs.isNotEmpty &&
          subs.every((s) => s.learnedOnDay > 0)) {
        completedCount++;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.backgroundDark,
            pinned: true,
            expandedHeight: 160,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 20),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentAmber.withOpacity(0.12),
                      AppColors.backgroundDark,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          roadmap.name,
                          style: AppTextStyles.headlineLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // ── Phase progress bar ────────────────────────────
                        Row(
                          children: [
                            Text(
                              '$completedCount / ${pillars.length} phases complete',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.accentAmber,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pillars.isEmpty
                                      ? 0
                                      : completedCount / pillars.length,
                                  minHeight: 5,
                                  backgroundColor: AppColors.progressTrack,
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppColors.accentAmber),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // ── Stats row ─────────────────────────────────────
                        Row(
                          children: [
                            _statChip(Icons.layers_outlined,
                                '${pillars.length} Phases',
                                AppColors.accentTeal),
                            const SizedBox(width: 8),
                            _statChip(Icons.timer_outlined,
                                '${roadmap.totalDays} days',
                                AppColors.textSecondary),
                            const SizedBox(width: 8),
                            _statChip(Icons.school_outlined,
                                roadmap.level, AppColors.accentAmber),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Phase cards ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final pillar = pillars[idx];
                  final subs = subTopicsByPillar[pillar.id] ?? [];
                  final isExpanded = pillar.isBlueprintGenerated;
                  final isExpanding =
                      ref.watch(deepDiveProvider).contains(pillar.id);
                  final isCompleted = isExpanded &&
                      subs.isNotEmpty &&
                      subs.every((s) => s.learnedOnDay > 0);

                  return _PhaseCard(
                    pillar: pillar,
                    subTopics: subs,
                    phaseNumber: idx + 1,
                    isExpanded: isExpanded,
                    isExpanding: isExpanding,
                    isCompleted: isCompleted,
                    onBlueprint: () => ref
                        .read(deepDiveProvider.notifier)
                        .expandPillar(pillar),
                    onStart: () async {
                      // Calculate days from actual content:
                      // • 1 topic per day minimum pace
                      // • target ~60 min/day of learning
                      // • +30% revision buffer days
                      final topicCount = subs.isEmpty ? 1 : subs.length;
                      final totalMin = subs.fold(
                        pillar.estimatedLearnMinutes,
                        (sum, s) => sum + s.estimatedLearnMinutes,
                      );
                      final learnDays = (totalMin / 60).ceil().clamp(topicCount, 14);
                      final revisionBuffer = (topicCount * 0.3).ceil().clamp(1, 7);
                      final calculatedDays = (learnDays + revisionBuffer).clamp(1, 21);
                      await ref
                          .read(goalListProvider.notifier)
                          .importPhaseToActiveGoal(pillar, calculatedDays);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Sprint created! Go to Dashboard.')),
                        );
                        context.go('/');
                      }
                    },
                    genState: isExpanding
                        ? ref.watch(generationProvider)
                        : null,
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: idx * 60))
                      .slideY(begin: 0.08, end: 0);
                },
                childCount: pillars.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.tagStyle
                  .copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Phase Card ─────────────────────────────────────────────────────────────────

class _PhaseCard extends StatefulWidget {
  final TopicModel pillar;
  final List<TopicModel> subTopics;
  final int phaseNumber;
  final bool isExpanded;
  final bool isExpanding;
  final bool isCompleted;
  final VoidCallback onBlueprint;
  final VoidCallback onStart;
  final dynamic genState;

  const _PhaseCard({
    required this.pillar,
    required this.subTopics,
    required this.phaseNumber,
    required this.isExpanded,
    required this.isExpanding,
    required this.isCompleted,
    required this.onBlueprint,
    required this.onStart,
    this.genState,
  });

  @override
  State<_PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<_PhaseCard> {
  bool _showSubTopics = false;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = widget.isCompleted
        ? AppColors.accentGreen
        : widget.isExpanded
            ? AppColors.accentAmber
            : AppColors.textMuted;

    final String statusLabel = widget.isCompleted
        ? 'COMPLETED'
        : widget.isExpanded
            ? 'BLUEPRINTED'
            : 'PENDING';

    final IconData statusIcon = widget.isCompleted
        ? Icons.check_circle_rounded
        : widget.isExpanded
            ? Icons.bolt_rounded
            : Icons.radio_button_unchecked_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: widget.isCompleted
            ? AppColors.accentGreen.withOpacity(0.05)
            : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isCompleted
              ? AppColors.accentGreen.withOpacity(0.3)
              : widget.isExpanded
                  ? AppColors.accentAmber.withOpacity(0.25)
                  : AppColors.borderCard,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Phase header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: phase number + status badge
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.phaseNumber}',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // chapter label (e.g. "PHASE 1: Core Fundamentals")
                          if (widget.pillar.moduleName != null)
                            Text(
                              widget.pillar.moduleName!.toUpperCase(),
                              style: AppTextStyles.tagStyle.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 8,
                                letterSpacing: 0.8,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            widget.pillar.name,
                            style: AppTextStyles.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 10, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: AppTextStyles.tagStyle.copyWith(
                                  color: statusColor, fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sub-topic count row
                if (widget.isExpanded && widget.subTopics.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showSubTopics = !_showSubTopics),
                    child: Row(
                      children: [
                        Icon(Icons.account_tree_rounded,
                            size: 12,
                            color: AppColors.accentAmber.withOpacity(0.7)),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.subTopics.length} atomic topics',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Completion progress
                        Text(
                          '(${widget.subTopics.where((s) => s.learnedOnDay > 0).length}/${widget.subTopics.length} done)',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                        const Spacer(),
                        Icon(
                          _showSubTopics
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Action button ──────────────────────────────────────────
                const SizedBox(height: 12),
                if (!widget.isExpanded)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.isExpanding ? null : widget.onBlueprint,
                      icon: widget.isExpanding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  color: AppColors.backgroundDark,
                                  strokeWidth: 2))
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(widget.isExpanding
                          ? 'BLUEPRINTING...'
                          : 'GENERATE ATOMIC BLUEPRINT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isExpanding
                            ? AppColors.textMuted
                            : AppColors.accentAmber,
                        foregroundColor: AppColors.backgroundDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else if (!widget.isCompleted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('START LEARNING THIS PHASE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 16, color: AppColors.accentGreen),
                        const SizedBox(width: 8),
                        Text('PHASE MASTERED',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            )),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Atomic sub-topics list (collapsible) ───────────────────────
          if (_showSubTopics && widget.subTopics.isNotEmpty) ...[
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: widget.subTopics.asMap().entries.map((entry) {
                  final sub = entry.value;
                  final isDone = sub.learnedOnDay > 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isDone
                              ? AppColors.accentGreen
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.name,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDone
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: AppColors.textMuted,
                                ),
                              ),
                              if (sub.subTopics.isNotEmpty)
                                Text(
                                  '${sub.subTopics.length} micro-concepts',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '~${sub.estimatedLearnMinutes}m',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ── AI console (while blueprinting) ───────────────────────────
          if (widget.isExpanding && widget.genState != null)
            _LiveConsole(genState: widget.genState),
        ],
      ),
    );
  }
}

class _LiveConsole extends StatelessWidget {
  final dynamic genState;
  const _LiveConsole({required this.genState});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded,
                  size: 14, color: AppColors.accentAmber),
              const SizedBox(width: 6),
              Text('AI BLUEPRINTING',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.accentAmber,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.accentAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: Text('LIVE',
                    style: AppTextStyles.labelSmall
                        .copyWith(fontSize: 8, color: AppColors.accentAmber)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                genState.buffer ?? '',
                style: const TextStyle(
                  color: Color(0xFFADFF2F),
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
