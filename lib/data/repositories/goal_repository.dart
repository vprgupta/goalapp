import '../local/hive_service.dart';
import '../models/goal_model.dart';
import '../models/topic_model.dart';
import '../models/day_plan_model.dart';
import '../models/task_model.dart';

class GoalRepository {
  static const String _selectedGoalKey = 'selected_goal_id';

  // ── Goals ──────────────────────────────────────────────
  Future<void> saveGoal(GoalModel goal) async {
    await HiveService.goalsBox.put(goal.id, goal);
    // If it's the only goal, select it by default
    if (HiveService.goalsBox.length == 1) {
      await setSelectedGoalId(goal.id);
    }
  }

  String? getSelectedGoalId() {
    return HiveService.settingsBox.get(_selectedGoalKey) as String?;
  }

  Future<void> setSelectedGoalId(String id) async {
    await HiveService.settingsBox.put(_selectedGoalKey, id);
  }

  GoalModel? getGoal(String id) {
    return HiveService.goalsBox.get(id);
  }

  List<GoalModel> getAllGoals() {
    return HiveService.goalsBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  GoalModel? getActiveGoal() {
    final selectedId = getSelectedGoalId();
    if (selectedId != null) {
      final goal = HiveService.goalsBox.get(selectedId);
      if (goal != null && goal.status == GoalStatus.active) {
        return goal;
      }
    }

    try {
      // Fallback to the first active goal if selection is invalid or missing
      return HiveService.goalsBox.values
          .firstWhere((g) => g.status == GoalStatus.active);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteGoal(String id) async {
    await HiveService.goalsBox.delete(id);

    // Clear selection if this was the selected goal
    if (getSelectedGoalId() == id) {
      await HiveService.settingsBox.delete(_selectedGoalKey);
    }

    // Also delete all related data
    final topicsToDelete = HiveService.topicsBox.values
        .where((t) => t.goalId == id)
        .map((t) => t.id)
        .toList();
    for (final tid in topicsToDelete) {
      await HiveService.topicsBox.delete(tid);
    }
    final daysToDelete = HiveService.dayPlansBox.values
        .where((d) => d.goalId == id)
        .map((d) => d.id)
        .toList();
    for (final did in daysToDelete) {
      await HiveService.dayPlansBox.delete(did);
    }
  }

  // ── Topics ─────────────────────────────────────────────
  Future<void> saveTopic(TopicModel topic) async {
    await HiveService.topicsBox.put(topic.id, topic);
  }

  Future<void> saveTopics(List<TopicModel> topics) async {
    final map = {for (final t in topics) t.id: t};
    await HiveService.topicsBox.putAll(map);
  }

  TopicModel? getTopic(String id) {
    return HiveService.topicsBox.get(id);
  }

  List<TopicModel> getTopicsForGoal(String goalId) {
    return HiveService.topicsBox.values
        .where((t) => t.goalId == goalId)
        .toList()
      ..sort((a, b) => a.learnedOnDay.compareTo(b.learnedOnDay));
  }

  // ── Day Plans ──────────────────────────────────────────
  Future<void> saveDayPlan(DayPlanModel dayPlan) async {
    await HiveService.dayPlansBox.put(dayPlan.id, dayPlan);
  }

  Future<void> saveDayPlans(List<DayPlanModel> plans) async {
    final map = {for (final p in plans) p.id: p};
    await HiveService.dayPlansBox.putAll(map);
  }

  DayPlanModel? getDayPlan(String id) {
    return HiveService.dayPlansBox.get(id);
  }

  List<DayPlanModel> getDayPlansForGoal(String goalId) {
    return HiveService.dayPlansBox.values
        .where((d) => d.goalId == goalId)
        .toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
  }

  DayPlanModel? getCurrentDayPlan(String goalId) {
    final plans = getDayPlansForGoal(goalId);
    try {
      return plans.firstWhere((p) => p.isUnlocked && !p.isCompleted);
    } catch (_) {
      return null;
    }
  }

  DayPlanModel? getDayPlanByNumber(String goalId, int dayNumber) {
    try {
      return HiveService.dayPlansBox.values
          .firstWhere((d) => d.goalId == goalId && d.dayNumber == dayNumber);
    } catch (_) {
      return null;
    }
  }

  // ── Task Operations ────────────────────────────────────
  Future<void> completeTask(
    String goalId,
    String dayPlanId,
    String taskId, {
    bool? recallCorrect,
  }) async {
    final dayPlan = HiveService.dayPlansBox.get(dayPlanId);
    if (dayPlan == null) return;

    final taskIndex = dayPlan.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = dayPlan.tasks[taskIndex];
    task.status = TaskStatus.completed;
    task.completedAt = DateTime.now();

    if (task.recallPrompt != null && recallCorrect != null) {
      task.recallPrompt!.answeredCorrectly = recallCorrect;
    }

    await HiveService.dayPlansBox.put(dayPlanId, dayPlan);
  }

  Future<void> unlockNextDay(String goalId, int nextDayNumber) async {
    final nextPlan = getDayPlanByNumber(goalId, nextDayNumber);
    if (nextPlan != null) {
      nextPlan.isUnlocked = true;
      nextPlan.startedAt = DateTime.now();
      await HiveService.dayPlansBox.put(nextPlan.id, nextPlan);
    }

    final goal = getGoal(goalId);
    if (goal != null) {
      goal.currentDay = nextDayNumber;
      await HiveService.goalsBox.put(goalId, goal);
    }
  }

  Future<void> markDayComplete(String dayPlanId) async {
    final dayPlan = HiveService.dayPlansBox.get(dayPlanId);
    if (dayPlan == null) return;
    dayPlan.isCompleted = true;
    dayPlan.completedAt = DateTime.now();
    await HiveService.dayPlansBox.put(dayPlanId, dayPlan);
  }

  Future<void> updateGoalComplete(String goalId) async {
    final goal = getGoal(goalId);
    if (goal != null) {
      goal.status = GoalStatus.completed;
      await HiveService.goalsBox.put(goalId, goal);
    }
  }
}
