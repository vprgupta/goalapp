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

    final pillars = allTopics
        .where((t) =>
            t.moduleName?.toUpperCase().startsWith('PHASE') == true ||
            (t.moduleName == null && !t.isBlueprintGenerated))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    Map<String, List<TopicModel>> subTopicsByPillar = {};
    for (final pillar in pillars) {
      subTopicsByPillar[pillar.id] =
          allTopics.where((t) => t.moduleName == pillar.name).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

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
          // ── Upgraded App Bar ─────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.backgroundDark,
            pinned: true,
            expandedHeight: 180,
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 16),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentAmber.withOpacity(0.20),
                      AppColors.accentAmber.withOpacity(0.06),
                      AppColors.backgroundDark,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Roadmap title with ShaderMask
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.textPrimary, Color(0xFFCBD5E1)],
                          ).createShader(bounds),
                          child: Text(
                            roadmap.name,
                            style: AppTextStyles.headlineLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Progress bar
                        Row(
                          children: [
                            Text(
                              '$completedCount / ${pillars.length} phases',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.accentAmber,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    Container(height: 7, color: AppColors.progressTrack),
                                    FractionallySizedBox(
                                      widthFactor: pillars.isEmpty
                                          ? 0
                                          : (completedCount / pillars.length).clamp(0.0, 1.0),
                                      child: Container(
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.gradientAmberStart,
                                              AppColors.gradientAmberEnd,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Stat chips row
                        Row(
                          children: [
                            _statChip(Icons.layers_outlined,
                                '${pillars.length} Phases', AppColors.accentTeal),
                            const SizedBox(width: 8),
                            _statChip(Icons.timer_outlined,
                                '${roadmap.totalDays} days', AppColors.textSecondary),
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

          // ── Phase cards ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                    onBlueprint: () =>
                        ref.read(deepDiveProvider.notifier).expandPillar(pillar),
                    onStart: () async {
                      final topicCount = subs.isEmpty ? 1 : subs.length;
                      final totalMin = subs.fold(
                        pillar.estimatedLearnMinutes,
                        (sum, s) => sum + s.estimatedLearnMinutes,
                      );
                      final learnDays =
                          (totalMin / 60).ceil().clamp(topicCount, 14);
                      final revisionBuffer =
                          (topicCount * 0.3).ceil().clamp(1, 7);
                      final calculatedDays =
                          (learnDays + revisionBuffer).clamp(1, 21);
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
                    genState:
                        isExpanding ? ref.watch(generationProvider) : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.tagStyle.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Phase Card ────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isCompleted
              ? [
                  AppColors.accentGreen.withOpacity(0.08),
                  AppColors.backgroundCard,
                ]
              : widget.isExpanded
                  ? [
                      AppColors.accentAmber.withOpacity(0.07),
                      AppColors.backgroundCard,
                    ]
                  : [
                      AppColors.backgroundCard,
                      AppColors.backgroundCard,
                    ],
        ),
        border: Border.all(
          color: widget.isCompleted
              ? AppColors.accentGreen.withOpacity(0.35)
              : widget.isExpanded
                  ? AppColors.accentAmber.withOpacity(0.3)
                  : AppColors.borderCard,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isCompleted
                ? AppColors.glowGreen
                : widget.isExpanded
                    ? AppColors.glowAmber
                    : const Color(0x14000000),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Phase header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Phase number circle — bigger with colored ring
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.06),
                          ],
                        ),
                        border: Border.all(
                            color: statusColor.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${widget.phaseNumber}',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.pillar.moduleName != null)
                            Text(
                              widget.pillar.moduleName!.toUpperCase(),
                              style: AppTextStyles.tagStyle.copyWith(
                                color: statusColor.withOpacity(0.7),
                                fontSize: 8,
                                letterSpacing: 1.0,
                              ),
                            ),
                          const SizedBox(height: 3),
                          Text(
                            widget.pillar.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: statusColor.withOpacity(0.35)),
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
                const SizedBox(height: 14),

                // Sub-topic toggle row
                if (widget.isExpanded && widget.subTopics.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showSubTopics = !_showSubTopics),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundElevated.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderCard),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_tree_rounded,
                              size: 13,
                              color: AppColors.accentAmber.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.subTopics.length} atomic topics',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accentAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${widget.subTopics.where((s) => s.learnedOnDay > 0).length}/${widget.subTopics.length} done)',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted, fontSize: 11),
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
                  ),
                  const SizedBox(height: 12),
                ],

                // Action buttons
                if (!widget.isExpanded)
                  _buildBlueprintButton()
                else if (!widget.isCompleted)
                  _buildStartButton()
                else
                  _buildMasteredBadge(),
              ],
            ),
          ),

          // ── Atomic sub-topics list ────────────────────────────────────
          if (_showSubTopics && widget.subTopics.isNotEmpty) ...[
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                children: widget.subTopics.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sub = entry.value;
                  final isDone = sub.learnedOnDay > 0;
                  final isLast = idx == widget.subTopics.length - 1;
                  return _buildSubTopicRow(sub, isDone, isLast);
                }).toList(),
              ),
            ),
          ],

          // ── AI console ───────────────────────────────────────────────
          if (widget.isExpanding && widget.genState != null)
            _LiveConsole(genState: widget.genState),
        ],
      ),
    );
  }

  Widget _buildSubTopicRow(TopicModel sub, bool isDone, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tree connector
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.accentGreen.withOpacity(0.15)
                        : AppColors.backgroundElevated,
                    border: Border.all(
                      color: isDone
                          ? AppColors.accentGreen.withOpacity(0.6)
                          : AppColors.borderCard,
                      width: 1.5,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 8, color: AppColors.accentGreen)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: AppColors.borderCard,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    style: AppTextStyles.bodySmall.copyWith(
                      color:
                          isDone ? AppColors.textMuted : AppColors.textPrimary,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
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
          ),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Text(
              '~${sub.estimatedLearnMinutes}m',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlueprintButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isExpanding
                ? [AppColors.backgroundElevated, AppColors.backgroundCard]
                : [AppColors.gradientAmberStart, AppColors.gradientAmberEnd],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: widget.isExpanding
              ? []
              : const [
                  BoxShadow(
                      color: AppColors.glowAmber,
                      blurRadius: 16,
                      offset: Offset(0, 5)),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.isExpanding ? null : widget.onBlueprint,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isExpanding)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: AppColors.accentAmber, strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.isExpanding
                        ? 'BLUEPRINTING...'
                        : 'GENERATE ATOMIC BLUEPRINT',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: widget.isExpanding
                          ? AppColors.accentAmber
                          : Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gradientGreenStart, AppColors.gradientGreenEnd],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: AppColors.glowGreen, blurRadius: 16, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onStart,
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'START LEARNING THIS PHASE',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasteredBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentGreen.withOpacity(0.12),
            AppColors.accentGreen.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: AppColors.accentGreen),
          SizedBox(width: 8),
          Text(
            'PHASE MASTERED',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.accentGreen,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live AI Console ────────────────────────────────────────────────────────────

class _LiveConsole extends StatelessWidget {
  final dynamic genState;
  const _LiveConsole({required this.genState});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentAmber.withOpacity(0.25)),
        boxShadow: const [
          BoxShadow(color: AppColors.glowAmber, blurRadius: 12),
        ],
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
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.accentAmber.withOpacity(0.3)),
                ),
                child: Text('LIVE',
                    style: AppTextStyles.labelSmall
                        .copyWith(fontSize: 8, color: AppColors.accentAmber)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
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
