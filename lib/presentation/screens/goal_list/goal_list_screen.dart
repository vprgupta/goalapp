import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/goal_provider.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/local/hive_service.dart';

class GoalListScreen extends ConsumerWidget {
  const GoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmaps = ref.watch(roadmapsProvider);
    final activeCount = ref.watch(activeGoalsProvider).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/create'),
          backgroundColor: AppColors.accentAmber,
          foregroundColor: AppColors.backgroundDark,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'New Roadmap',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIBRARY VAULT',
                          style: AppTextStyles.tagStyle.copyWith(
                            color: AppColors.accentAmber,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Roadmap Library',
                          style: AppTextStyles.headlineLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${roadmaps.length} roadmaps  ·  $activeCount active',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) =>
                    ref.read(goalSearchProvider.notifier).state = v,
                decoration: const InputDecoration(
                  hintText: 'Search roadmaps...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(indent: 20, endIndent: 20),
            const SizedBox(height: 4),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: roadmaps.isEmpty
                  ? _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                      itemCount: roadmaps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final r = roadmaps[i];
                        return _RoadmapTile(
                          key: ValueKey(r.id),
                          roadmap: r,
                          onTap: () => context.push('/roadmap/${r.id}'),
                          onDelete: () => _confirmDelete(context, ref, r),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, GoalModel goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Roadmap?'),
        content: Text('Delete "${goal.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(goalListProvider.notifier).deleteGoalById(goal.id);
    }
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No Roadmaps Yet', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Tap the button below to get started.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Roadmap tile — uses the app's Card theme directly ───────────────────────

class _RoadmapTile extends StatelessWidget {
  final GoalModel roadmap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RoadmapTile({
    super.key,
    required this.roadmap,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date =
        '${roadmap.createdAt.day}/${roadmap.createdAt.month}/${roadmap.createdAt.year}';
    int completedPhases = 0;
    int totalPhases = 0;
    
    if (HiveService.isBoxOpen('topics') && HiveService.isBoxOpen('goals')) {
      final allGoals = HiveService.goalsBox.values.toList();
      final roadmapTopics = HiveService.topicsBox.values.where((t) => t.goalId == roadmap.id).toList();
      final pillars = roadmapTopics.where((t) => t.moduleName?.toUpperCase().startsWith('PHASE') == true || t.moduleName?.toUpperCase().startsWith('MILESTONE') == true || (t.moduleName == null && !t.isBlueprintGenerated)).toList();
      totalPhases = pillars.length;
      
      for (final pillar in pillars) {
        if (allGoals.any((g) => g.status.name == 'completed' && g.name == pillar.name)) {
          completedPhases++;
        }
      }
    }
    
    final progress = totalPhases > 0 ? (completedPhases / totalPhases).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (progress * 100).round();
    final isActive = roadmap.status.name == 'active';
    final isCompleted = roadmap.status.name == 'completed';

    final statusColor = isCompleted
        ? AppColors.accentGreen
        : isActive
            ? AppColors.accentAmber
            : AppColors.textMuted;
    final statusLabel = isCompleted
        ? 'COMPLETED'
        : isActive
            ? 'ACTIVE'
            : 'IDLE';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderCard),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: icon + title + delete ────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderCard),
                      ),
                      child: const Icon(Icons.map_rounded,
                          color: AppColors.accentAmber, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roadmap.name,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: statusColor.withOpacity(0.35)),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${roadmap.level}  ·  ${roadmap.totalDays}d  ·  $date',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Progress bar ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                totalPhases > 0 ? '$completedPhases of $totalPhases Phases  ·  $progressPercent%' : 'Day ${roadmap.currentDay} of ${roadmap.totalDays}  ·  $progressPercent%',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                // Track
                                Container(
                                  height: 7,
                                  color: AppColors.progressTrack,
                                ),
                                // Fill
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    height: 7,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isCompleted
                                            ? [
                                                AppColors.accentGreen,
                                                AppColors.accentGreen,
                                              ]
                                            : [
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted, size: 22),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
