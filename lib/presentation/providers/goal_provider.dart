import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/day_plan_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/goal_repository.dart';
import '../../domain/engines/topic_generator.dart';
import 'generation_provider.dart';
import 'service_providers.dart';
import '../../domain/engines/task_distributor.dart';
import '../../domain/engines/revision_scheduler.dart';

// ── Goal Creation State ────────────────────────────────────────────────────────
/// Immutable state for the goal creation flow (per managing-state skill: expose
/// structured isLoading + error from the ViewModel instead of bare booleans).
class GoalCreationState {
  final bool isCreating;
  final String? error;

  const GoalCreationState({this.isCreating = false, this.error});

  GoalCreationState copyWith({bool? isCreating, String? error}) {
    return GoalCreationState(
      isCreating: isCreating ?? this.isCreating,
      error: error,
    );
  }

  GoalCreationState get loading => copyWith(isCreating: true, error: null);
  GoalCreationState get idle => const GoalCreationState();
}

const _uuid = Uuid();

// ── Search Provider ─────────────────────────────────────────────────────────
final goalSearchProvider = StateProvider<String>((ref) => "");

// ── Repository Provider ──────────────────────────────────────────────────────
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository();
});

// ── Goal List Provider (The source of truth for reactivity) ──────────────────
final goalListProvider = StateNotifierProvider<GoalListNotifier, List<GoalModel>>((ref) {
  return GoalListNotifier(ref.read(goalRepositoryProvider), ref);
});

class GoalListNotifier extends StateNotifier<List<GoalModel>> {
  final GoalRepository _repo;
  final Ref _ref;

  GoalListNotifier(this._repo, this._ref) : super([]) {
    _load();
  }

  // Track creation state so the UI can react without local booleans
  GoalCreationState _creationState = const GoalCreationState();
  GoalCreationState get creationState => _creationState;
  void _setCreation(GoalCreationState s) => _creationState = s;

  void _load() {
    state = _repo.getAllGoals();
  }

  /// Sets the selected goal ID and refreshes state.
  Future<void> switchGoal(String id) async {
    await _repo.setSelectedGoalId(id);
    _load();
  }

  /// Creates a brand-new Roadmap (Syllabus), does NOT distribute tasks yet.
  Future<void> createGoal({
    required String name,
    required String level,
    required int totalDays,
    List<Map<String, dynamic>>? customMetadata,
  }) async {
    _setCreation(_creationState.loading);
    final goalId = _uuid.v4();
    final goal = GoalModel(
      id: goalId,
      name: name,
      level: level,
      totalDays: totalDays,
      createdAt: DateTime.now(),
      status: GoalStatus.roadmap,
    );

    // 1. Generate topics
    List<TopicModel> topics = [];
    
    if (customMetadata != null) {
      topics = TopicGenerator.generateFromMetadata(
        goalId: goalId,
        metadata: customMetadata,
        totalDays: totalDays,
      );
    } else {
      // Architecture fix: read injected service instead of instantiating directly
      final aiService = _ref.read(aiServiceProvider);
      
      _ref.read(generationProvider.notifier).start();
      _ref.read(generationProvider.notifier).append("--- IDENTIFYING MASTER PILLARS ---\n");

      // Stage 1: Get Master Pillars (Discovery)
      final masterPillars = await aiService.generateSyllabus(
        goal: name,
        level: level,
        days: totalDays,
        onProgress: (chunk) => _ref.read(generationProvider.notifier).append(chunk),
      );

      _ref.read(generationProvider.notifier).append("\n\n--- MASTER ROADMAP SECURED ---\n");
      _ref.read(generationProvider.notifier).complete();

      // Ensure chronological ordering
      TopicGenerator.sortMetadata(masterPillars);

      int sortIdx = 0;
      topics = masterPillars.map((pillar) {
        final nodeId = _uuid.v4(); // Unique ID for the pillar
        return TopicModel(
          id: '${goalId}_$nodeId',
          goalId: goalId,
          name: pillar['title'] as String,
          tier: int.tryParse(pillar['rank']?.toString() ?? '1') ?? 1,
          estimatedLearnMinutes: (pillar['duration_sec'] as num? ?? 3600).toInt() ~/ 60,
          moduleName: pillar['chapter'] as String,
          isBoss: pillar['is_boss'] as bool? ?? false,
          weight: 0.8,
          prerequisites: [],
          subTopics: (pillar['subtopics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          isBlueprintGenerated: false,
          sortOrder: sortIdx++, // Fixed: Assigning sort index!
        );
      }).toList();
    }

    // 2. Assign topic IDs to roadmap
    goal.topicIds = topics.map((t) => t.id).toList();
    goal.topicStrengths = {for (final t in topics) t.id: 0.0};

    // 3. Save roadmap and its pillars
    await _repo.saveGoal(goal);
    await _repo.saveTopics(topics);
    
    _setCreation(_creationState.idle);
    // Refresh the list
    _load();
  }

  /// Retrieves a specific phase from a Roadmap and converts it into a scheduled Action Plan.
  Future<void> importPhaseToActiveGoal(TopicModel pillar, int studyDays) async {
    // 1. Get all topics generated for this roadmap
    final allRoadmapTopics = _repo.getTopicsForGoal(pillar.goalId);
    
    // We want the pillar itself, plus any atomic topics belonging to it
    final syllabusTopics = allRoadmapTopics
        .where((t) => t.id == pillar.id || t.moduleName == pillar.name)
        .toList();

    // 2. Create the new Active Goal (The Sprint)
    final newGoalId = _uuid.v4();
    final activeGoal = GoalModel(
      id: newGoalId,
      name: pillar.name,
      level: 'intermediate',
      totalDays: studyDays, // User chooses how many days they want to spend on this phase
      createdAt: DateTime.now(),
      status: GoalStatus.active,
    );

    // Fetch parent roadmap to inherit its difficulty level
    final parentRoadmap = _repo.getGoal(pillar.goalId);
    if (parentRoadmap != null) {
      activeGoal.level = parentRoadmap.level;
    }

    // 3. Clone the topics to the new Goal (so the original Roadmap remains intact)
    int sortIdx = 0;
    final List<TopicModel> clonedTopics = syllabusTopics.map((t) {
      return TopicModel(
        id: '${newGoalId}_${_uuid.v4()}', // Generate fresh ID
        goalId: newGoalId,
        name: t.name,
        tier: t.tier,
        estimatedLearnMinutes: t.estimatedLearnMinutes,
        moduleName: t.moduleName,
        isBoss: t.isBoss,
        weight: t.weight,
        prerequisites: [], // Removed for the sprint to allow flexible scheduling
        subTopics: List.from(t.subTopics),
        isBlueprintGenerated: t.isBlueprintGenerated,
        sortOrder: sortIdx++, // Maintain sequence
      );
    }).toList();

    // 4. Run the Task Distributor (this is where the schedule is created!)
    final dayPlans = TaskDistributor.distribute(goal: activeGoal, topics: clonedTopics);

    // 5. Update goal state
    activeGoal.topicIds = clonedTopics.map((t) => t.id).toList();
    activeGoal.topicStrengths = {for (final t in clonedTopics) t.id: 0.0};

    // 6. Save everything to the database
    await _repo.saveGoal(activeGoal);
    await _repo.saveTopics(clonedTopics);
    await _repo.saveDayPlans(dayPlans);

    // 7. Auto-switch to this new active sprint
    await switchGoal(newGoalId);
  }

  /// Deletes a specific goal and refreshes state if it was the active one.
  Future<void> deleteGoalById(String id) async {
    await _repo.deleteGoal(id);
    _load();
  }

  void refresh() {
    _load();
  }
}

// ── Active Goal Provider (Computed focus) ────────────────────────────────────
final activeGoalProvider = Provider<GoalModel?>((ref) {
  final list = ref.watch(goalListProvider);
  final repo = ref.read(goalRepositoryProvider);
  final selectedId = repo.getSelectedGoalId();
  
  if (selectedId == null) {
    if (list.isEmpty) return null;
    // Fallback to first active goal if none selected
    try {
      return list.firstWhere((g) => g.status == GoalStatus.active);
    } catch (_) {
      return null;
    }
  }

  try {
    return list.firstWhere((g) => g.id == selectedId);
  } catch (_) {
    return null;
  }
});

// ── Roadmaps Provider (List of blueprints) ───────────────────────────────────
final roadmapsProvider = Provider<List<GoalModel>>((ref) {
  final list = ref.watch(goalListProvider);
  final query = ref.watch(goalSearchProvider).toLowerCase();
  
  final filtered = list.where((g) => g.status == GoalStatus.roadmap).toList();
  if (query.isEmpty) return filtered;
  
  return filtered.where((g) => g.name.toLowerCase().contains(query)).toList();
});

// ── Active Goals Provider (Sprints in progress) ──────────────────────────────
final activeGoalsProvider = Provider<List<GoalModel>>((ref) {
  final list = ref.watch(goalListProvider);
  final query = ref.watch(goalSearchProvider).toLowerCase();

  final filtered = list.where((g) => g.status == GoalStatus.active || g.status == GoalStatus.completed).toList();
  if (query.isEmpty) return filtered;

  return filtered.where((g) => g.name.toLowerCase().contains(query)).toList();
});

// ── Current Day Plan Provider ────────────────────────────────────────────────
final currentDayPlanProvider =
    StateNotifierProvider<DayPlanNotifier, DayPlanModel?>((ref) {
  final goal = ref.watch(activeGoalProvider);
  final repo = ref.read(goalRepositoryProvider);
  return DayPlanNotifier(repo, goal?.id);
});

class DayPlanNotifier extends StateNotifier<DayPlanModel?> {
  final GoalRepository _repo;
  final String? _goalId;

  DayPlanNotifier(this._repo, this._goalId) : super(null) {
    _load();
  }

  void _load() {
    if (_goalId == null) {
      state = null;
      return;
    }
    state = _repo.getCurrentDayPlan(_goalId!);
  }

  /// Complete a task. If all tasks done, trigger day completion.
  Future<bool> completeTask(
    String taskId, {
    bool? recallCorrect,
    required String topicId,
    List<String>? subTopics,
  }) async {
    if (state == null || _goalId == null) return false;

    // 0. Save sub-topics if provided (Reflection phase)
    if (subTopics != null && subTopics.isNotEmpty) {
      final topic = _repo.getTopic(topicId);
      if (topic != null) {
        topic.subTopics = subTopics;
        await _repo.saveTopic(topic);
      }
    }

    // 1. Mark task done
    await _repo.completeTask(
      _goalId!,
      state!.id,
      taskId,
      recallCorrect: recallCorrect,
    );

    // 2. Update topic strength if recall answered
    if (recallCorrect != null) {
      final topic = _repo.getTopic(topicId);
      if (topic != null) {
        // Build a temp revision queue (not used here but needed by updateStrength)
        final Map<int, List<String>> tempQueue = {};
        final goal = _repo.getGoal(_goalId!);
        if (goal != null) {
          RevisionScheduler.updateStrength(
            topic: topic,
            correct: recallCorrect,
            currentDay: state!.dayNumber,
            totalDays: goal.totalDays,
            revisionQueue: tempQueue,
          );
          await _repo.saveTopic(topic);

          // Insert any emergency revision tasks
          if (tempQueue.isNotEmpty) {
            _insertEmergencyRevisions(tempQueue, topic, goal);
          }

          // Update goal strength map
          goal.topicStrengths[topicId] = topic.strengthScore;
          await _repo.saveGoal(goal);
        }
      }
    }

    // 3. Reload and check completion
    _load();
    final allDone = state?.allTasksDone ?? false;
    return allDone;
  }

  void _insertEmergencyRevisions(
    Map<int, List<String>> queue,
    TopicModel topic,
    GoalModel goal,
  ) {
    const uuid = Uuid();

    for (final entry in queue.entries) {
      final targetDay = entry.key;
      final dayPlan = _repo.getDayPlanByNumber(goal.id, targetDay);
      if (dayPlan == null || dayPlan.isCompleted) continue;

      // Don't double-insert if a revise task for this topic already exists
      final alreadyScheduled = dayPlan.tasks
          .any((t) => t.topicId == topic.id && t.type == TaskType.revise);
      if (alreadyScheduled) continue;

      // Build and insert the emergency revision task
      final recall = RevisionScheduler.buildRecallPrompt(topic);
      final emergencyTask = TaskModel(
        id: uuid.v4(),
        dayPlanId: dayPlan.id,
        type: TaskType.revise,
        topicId: topic.id,
        title: '⚠️ Reinforce: ${topic.name}',
        description: 'You struggled with this — a quick recall session now '
            'will prevent forgetting.',
        estimatedMinutes: RevisionScheduler.reviseEstimate(topic),
        recallPrompt: recall,
        sortOrder: dayPlan.tasks.length,
        videoId: topic.videoId,
        startSeconds: topic.startSeconds,
      );

      dayPlan.tasks = [...dayPlan.tasks, emergencyTask];
      _repo.saveDayPlan(dayPlan);
    }
  }

  /// Advances to next day after completion animation.
  Future<void> advanceToNextDay() async {
    if (state == null || _goalId == null) return;

    final currentDayNum = state!.dayNumber;

    try {
      await _repo.markDayComplete(state!.id);

      final goal = _repo.getGoal(_goalId!);
      if (goal == null) {
        // Goal record missing — just reload so UI isn't stuck
        return;
      }

      if (currentDayNum >= goal.totalDays) {
        await _repo.updateGoalComplete(_goalId!);
      } else {
        await _repo.unlockNextDay(_goalId!, currentDayNum + 1);
      }
    } finally {
      // Always reload — even if something above threw or returned early,
      // the UI must never stay frozen on the completed day.
      _load();
    }
  }

  void refresh() => _load();
}

// ── Day Plans List Provider ──────────────────────────────────────────────────
final dayPlansProvider = Provider.family<List<DayPlanModel>, String>(
  (ref, goalId) {
    ref.watch(currentDayPlanProvider); // update when day plan changes
    return ref.read(goalRepositoryProvider).getDayPlansForGoal(goalId);
  },
);

// ── Topics Provider ──────────────────────────────────────────────────────────
final topicsProvider = Provider.family<List<TopicModel>, String>(
  (ref, goalId) => ref.read(goalRepositoryProvider).getTopicsForGoal(goalId),
);
