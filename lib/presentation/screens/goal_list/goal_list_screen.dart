import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/goal_provider.dart';
import '../../../data/models/goal_model.dart';

class GoalListScreen extends ConsumerWidget {
  const GoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmaps = ref.watch(roadmapsProvider);
    final activeGoalsCount = ref.watch(activeGoalsProvider).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentAmber.withOpacity(0.05),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: const SizedBox()),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              // flutter-caching-data skill: pre-render roadmap cards off-screen
              cacheExtent: 600,
              slivers: [
                _buildSliverHeader(context, ref, roadmaps.length, activeGoalsCount),
                _buildSearchSection(context, ref),
                
                if (roadmaps.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState(context))
                else
                  // Adaptive layout: 1 column on mobile, 2 columns on tablets/desktop
                  // Fix: SliverPadding requires a Sliver child — use SliverLayoutBuilder
                  // not LayoutBuilder (which is a box widget and caused the crash).
                  SliverLayoutBuilder(
                    builder: (ctx, constraints) {
                      // SliverLayoutBuilder works in sliver space; maxWidth from sliver constraints
                      final isWide = constraints.crossAxisExtent > 600;
                      if (isWide) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 0,
                              childAspectRatio: 1.6,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx2, idx) {
                                final roadmap = roadmaps[idx];
                                return _RoadmapCard(
                                  roadmap: roadmap,
                                  onTap: () => context.push('/roadmap/${roadmap.id}'),
                                  onDelete: () =>
                                      _showDeleteConfirmation(context, ref, roadmap),
                                ).animate().fadeIn(delay: (idx * 50).ms).slideY(begin: 0.1, end: 0);
                              },
                              childCount: roadmaps.length,
                            ),
                          ),
                        );
                      }

                      // Mobile: single-column list
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx2, idx) {
                              final roadmap = roadmaps[idx];
                              return _RoadmapCard(
                                roadmap: roadmap,
                                onTap: () => context.push('/roadmap/${roadmap.id}'),
                                onDelete: () =>
                                    _showDeleteConfirmation(context, ref, roadmap),
                              ).animate().fadeIn(delay: (idx * 50).ms).slideY(begin: 0.1, end: 0);
                            },
                            childCount: roadmaps.length,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create'),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Design New Roadmap'),
        backgroundColor: AppColors.accentAmber,
        foregroundColor: AppColors.backgroundDark,
        elevation: 8,
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildSliverHeader(BuildContext context, WidgetRef ref, int total, int active) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ROADMAP', style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentAmber, letterSpacing: 3)),
                    const SizedBox(height: 4),
                    Text('Library Vault', style: AppTextStyles.displayLarge),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderCard),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatItem('TOTAL', '$total'),
                const SizedBox(width: 40),
                _buildStatItem('ACTIVE', '$active'),
                const SizedBox(width: 40),
                _buildStatItem('VERSION', '1.0.4'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.tagStyle.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildSearchSection(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderCard),
          ),
          child: TextField(
            onChanged: (val) => ref.read(goalSearchProvider.notifier).state = val,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search your roadmap vault...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref, GoalModel goal) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderCard),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 48),
              const SizedBox(height: 16),
              Text('Archive Roadmap?', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete "${goal.name}"?\nThis blueprint will be lost forever.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, foregroundColor: Colors.white),
                      child: const Text('DELETE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      ref.read(goalListProvider.notifier).deleteGoalById(goal.id);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_fix_high_rounded, size: 80, color: AppColors.textMuted.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text('Vault is Empty', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('Architect your first learning\nroadmap with AI intelligence.', textAlign: TextAlign.center, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  final GoalModel roadmap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RoadmapCard({
    required this.roadmap,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = '${roadmap.createdAt.day}/${roadmap.createdAt.month}/${roadmap.createdAt.year}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundCard.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderCard),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(roadmap.name, style: AppTextStyles.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('Created on $dateStr', style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onDelete,
                            tooltip: 'Delete roadmap', // flutter-improving-accessibility: readable by screen readers
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildMetaDataPill(context, Icons.bar_chart_rounded, roadmap.level.toUpperCase(), AppColors.accentTeal),
                          const SizedBox(width: 8),
                          _buildMetaDataPill(context, Icons.layers_outlined, '${roadmap.topicIds.length} Phases', AppColors.accentAmber),
                          const SizedBox(width: 8),
                          _buildMetaDataPill(context, Icons.timer_outlined, '${roadmap.totalDays}d', AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: 0.1, // Preview progress
                              backgroundColor: AppColors.progressTrack,
                              valueColor: AlwaysStoppedAnimation(AppColors.accentAmber.withOpacity(0.4)),
                              minHeight: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('BLUEPRINT READY', style: AppTextStyles.tagStyle.copyWith(color: AppColors.accentAmber)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaDataPill(BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // flutter-improving-accessibility: Hide decorative sub-widgets
          ExcludeSemantics(
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.tagStyle.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

