import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/topic_model.dart';
import '../providers/goal_provider.dart';
import '../providers/generation_provider.dart';
import '../providers/service_providers.dart';
import '../../domain/engines/task_distributor.dart';

final deepDiveProvider = StateNotifierProvider<DeepDiveNotifier, Set<String>>((ref) {
  return DeepDiveNotifier(ref);
});

class DeepDiveNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  DeepDiveNotifier(this._ref) : super({});

  Future<void> expandPillar(TopicModel pillar) async {
    if (pillar.isBlueprintGenerated || state.contains(pillar.id)) return;

    state = {...state, pillar.id}; // Add to expanding set
    final repo = _ref.read(goalRepositoryProvider);
    final goal = repo.getGoal(pillar.goalId);
    if (goal == null) {
      state = {...state}..remove(pillar.id);
      return;
    }

    try {
      _ref.read(generationProvider.notifier).start();
      _ref.read(generationProvider.notifier).append("--- INITIATING ATOMIC DEEP-DIVE: ${pillar.name} ---\n");

      // Architecture fix: inject service via provider instead of instantiating
      final dynamicService = _ref.read(dynamicLearningServiceProvider);
      
      // Stage 2: Atomic Blueprinting
      final graphNodes = await dynamicService.generateKnowledgeGraph(
        goal: goal.name,
        pillarName: pillar.name,
        level: goal.level,
        days: goal.totalDays,
        onProgress: (chunk) => _ref.read(generationProvider.notifier).append(chunk),
      );

      _ref.read(generationProvider.notifier).append("\n\n--- BLUEPRINT CAPTURED ---\n");
      _ref.read(generationProvider.notifier).append("Integrating atomic nodes into your roadmap...\n");

      // Convert nodes to TopicModels
      final List<TopicModel> newSubTopics = graphNodes.map((node) {
        return TopicModel(
          id: '${goal.id}_${node['id']}',
          goalId: goal.id,
          name: node['concept'] as String,
          tier: node['tier'] as int,
          estimatedLearnMinutes: node['estimated_time_minutes'] as int,
          moduleName: pillar.name, // Link to the parent pillar
          isBoss: node['is_boss'] as bool,
          weight: node['weight'] as double,
          prerequisites: (node['prerequisites'] as List<dynamic>).map((p) => '${goal.id}_$p').toList(),
          subTopics: (node['subtopics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          isBlueprintGenerated: true,
        );
      }).toList();

      // Update the repository
      await repo.saveTopics(newSubTopics);
      
      // Update the parent pillar
      pillar.isBlueprintGenerated = true;
      await repo.saveTopic(pillar);

      // Link the new atomic topics to this Roadmap
      final updatedTopicIds = [...goal.topicIds, ...newSubTopics.map((t) => t.id)];
      goal.topicIds = updatedTopicIds.toSet().toList(); // Ensure uniqueness
      await repo.saveGoal(goal);

      // (No TaskDistributor here! Roadmaps don't have day plans)

      _ref.read(generationProvider.notifier).complete();
      _ref.read(goalListProvider.notifier).refresh();

    } catch (e) {
      _ref.read(generationProvider.notifier).append("\n\n[ERROR] Deep-dive failed: $e\n");
    } finally {
      state = {...state}..remove(pillar.id);
    }
  }
}
