import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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

    // Only get the Pillars (Top level topics where parent/module rules don't exist, or just use the topicIds on Goal)
    // Actually, deep-dive adds subtopics with moduleName = pillar.name.
    // The master pillars themselves have moduleName = chapter (e.g. 'Phase 1').
    // To identify pillars vs subtopics: Pillars have subtopics list, or we just rely on `isBlueprintGenerated`.
    final allTopics = repo.getTopicsForGoal(roadmapId);
    // Find master pillars: They are the ones originally added when generated (tier 1..n).
    // An easy way: we only want to show the high-level pillars here.
    final pillars = allTopics.where((t) => (t.moduleName?.startsWith('Phase') == true) || t.moduleName == 'Core Journey' || t.moduleName == roadmap.name || !t.isBlueprintGenerated || t.id.split('_').length == 2).toList();
    // (Assuming unique UUIDs have length 2 split by `_` based on generation: `goalId_nodeId`).

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text('${roadmap.name} Syllabus'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: pillars.length,
        itemBuilder: (ctx, idx) {
          final pillar = pillars[idx];
          final isExpanded = pillar.isBlueprintGenerated;
          final isExpanding = ref.watch(deepDiveProvider).contains(pillar.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pillar.name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                if (!isExpanded)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isExpanding 
                        ? null 
                        : () => ref.read(deepDiveProvider.notifier).expandPillar(pillar),
                      icon: isExpanding 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.backgroundDark, strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded),
                      label: Text(isExpanding ? 'BLUEPRINTING...' : 'GENERATE ATOMIC BLUEPRINT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExpanding ? AppColors.textMuted : AppColors.accentAmber,
                        foregroundColor: AppColors.backgroundDark,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Import this phase to active goals
                        await ref.read(goalListProvider.notifier).importPhaseToActiveGoal(pillar, 10); // Default 10 days
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sprint Created! Go to Dashboard.')),
                          );
                          context.go('/');
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('START LEARNING PHASE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (isExpanding) ...[
                  const SizedBox(height: 16),
                  _buildLiveConsole(ref),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveConsole(WidgetRef ref) {
    final genState = ref.watch(generationProvider);
    if (!genState.isGenerating && genState.buffer.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, size: 16, color: AppColors.accentAmber),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'STREAMING',
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 8, color: AppColors.accentAmber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              reverse: true, // Auto-scroll to bottom
              child: Text(
                genState.buffer,
                style: const TextStyle(
                  color: Color(0xFFADFF2F), // Greenish terminal color
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
}
