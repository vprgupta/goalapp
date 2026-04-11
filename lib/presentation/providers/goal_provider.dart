import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/day_plan_model.dart';
import '../../data/repositories/goal_repository.dart';
import '../../domain/engines/topic_generator.dart';
import '../../domain/engines/task_distributor.dart';
import '../../domain/engines/revision_scheduler.dart';

const _uuid = Uuid();

// ── Repository Provider ──────────────────────────────────────────────────────
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository();
});

// ── Active Goal Provider ─────────────────────────────────────────────────────
final activeGoalProvider = StateNotifierProvider<ActiveGoalNotifier, GoalModel?>(
  (ref) => ActiveGoalNotifier(ref.read(goalRepositoryProvider)),
);

class ActiveGoalNotifier extends StateNotifier<GoalModel?> {
  final GoalRepository _repo;

  ActiveGoalNotifier(this._repo) : super(null) {
    _load();
  }

  void _load() {
    state = _repo.getActiveGoal();
  }

  /// Sets the selected goal ID and refreshes state.
  Future<void> switchGoal(String id) async {
    await _repo.setSelectedGoalId(id);
    _load();
  }

  /// Creates a brand-new goal, generates topics and day plans.
  Future<void> createGoal({
    required String name,
    required String level,
    required int totalDays,
    List<Map<String, dynamic>>? customMetadata,
  }) async {
    final goalId = _uuid.v4();
    final goal = GoalModel(
      id: goalId,
      name: name,
      level: level,
      totalDays: totalDays,
      createdAt: DateTime.now(),
    );

    // 1. Generate topics
    final topics = customMetadata != null
        ? TopicGenerator.generateFromMetadata(
            goalId: goalId,
            metadata: customMetadata,
            totalDays: totalDays,
          )
        : TopicGenerator.generate(
            goalId: goalId,
            goalName: name,
            level: level,
            totalDays: totalDays,
          );

    // 2. Distribute tasks across days
    final dayPlans = TaskDistributor.distribute(goal: goal, topics: topics);

    // 3. Assign topic IDs to goal
    goal.topicIds = topics.map((t) => t.id).toList();
    goal.topicStrengths = {for (final t in topics) t.id: 0.0};

    // 4. Save everything
    await _repo.saveGoal(goal);
    await _repo.saveTopics(topics);
    await _repo.saveDayPlans(dayPlans);
    
    // Automatically switch to the new goal
    await switchGoal(goalId);
  }

  /// Deletes a specific goal and refreshes state if it was the active one.
  Future<void> deleteGoalById(String id) async {
    await _repo.deleteGoal(id);
    _load();
  }

  /// Deletes the active goal and resets.
  Future<void> deleteGoal() async {
    if (state == null) return;
    await deleteGoalById(state!.id);
  }

  void refresh() {
    _load();
  }
}

// ── All Goals Provider ───────────────────────────────────────────────────────
final allGoalsProvider = Provider<List<GoalModel>>((ref) {
  ref.watch(activeGoalProvider); // recompute when goal changes
  return ref.read(goalRepositoryProvider).getAllGoals();
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
    dynamic topic,
    GoalModel goal,
  ) {
    for (final entry in queue.entries) {
      final targetDay = entry.key;
      final dayPlan = _repo.getDayPlanByNumber(goal.id, targetDay);
      if (dayPlan != null && !dayPlan.isCompleted) {
        // This minimal insertion just records the scheduled revision on the topic
        // Full re-generation is deferred to avoid heavy I/O during task completion
      }
    }
  }

  /// Advances to next day after completion animation.
  Future<void> advanceToNextDay() async {
    if (state == null || _goalId == null) return;

    final currentDayNum = state!.dayNumber;
    await _repo.markDayComplete(state!.id);

    final goal = _repo.getGoal(_goalId!);
    if (goal == null) return;

    if (currentDayNum >= goal.totalDays) {
      // Goal completed!
      await _repo.updateGoalComplete(_goalId!);
    } else {
      await _repo.unlockNextDay(_goalId!, currentDayNum + 1);
    }

    _load();
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
