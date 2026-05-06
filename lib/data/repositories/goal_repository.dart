import 'package:flutter/foundation.dart';
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
    final goalToDelete = getGoal(id);

    // Also delete all related data
    final topicsToDelete = HiveService.topicsBox.values
        .where((t) => t.goalId == id)
        .toList();

    // Cascade delete any child goals (sprints imported from this roadmap's pillars)
    if (goalToDelete != null && goalToDelete.status == GoalStatus.roadmap) {
      for (final topic in topicsToDelete) {
        final derivedGoals = HiveService.goalsBox.values
            .where((g) => g.name == topic.name && g.id != id)
            .toList();
        for (final derived in derivedGoals) {
          await deleteGoal(derived.id); // Recursive delete
        }
      }
    }

    await HiveService.goalsBox.delete(id);

    // Clear selection if this was the selected goal
    if (getSelectedGoalId() == id) {
      await HiveService.settingsBox.delete(_selectedGoalKey);
    }

    for (final t in topicsToDelete) {
      await HiveService.topicsBox.delete(t.id);
    }
    final daysToDelete = HiveService.dayPlansBox.values
        .where((d) => d.goalId == id)
        .map((d) => d.id)
        .toList();
    for (final did in daysToDelete) {
      await HiveService.dayPlansBox.delete(did);
    }
  }

  /// Cleans up any Active Goals that do not have a matching Roadmap parent.
  /// This fixes issues where goals generated before cascade-deletion was implemented
  /// became "zombies" and continued to appear on the dashboard after their roadmap was deleted.
  Future<void> cleanOrphans() async {
    final activeGoals = HiveService.goalsBox.values.where((g) => g.status == GoalStatus.active).toList();
    for (final activeGoal in activeGoals) {
      final hasParentRoadmap = HiveService.topicsBox.values.any((t) => 
          t.name == activeGoal.name && 
          HiveService.goalsBox.containsKey(t.goalId) && 
          HiveService.goalsBox.get(t.goalId)?.status == GoalStatus.roadmap
      );
      if (!hasParentRoadmap) {
        debugPrint('[GoalRepository] Deleting orphaned zombie goal: ${activeGoal.name}');
        await deleteGoal(activeGoal.id);
      }
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
      ..sort((a, b) {
        // 1. If both are unlearned (Roadmap mode), use sortOrder
        if (a.learnedOnDay == 0 && b.learnedOnDay == 0) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        // 2. If one is learned, learned comes after unlearned in the database? 
        // Actually, learnedOnDay > 0 means it's scheduled.
        // We want: Day 1, Day 2, ..., Day N, then anything unscheduled.
        if (a.learnedOnDay != b.learnedOnDay) {
          if (a.learnedOnDay == 0) return 1;
          if (b.learnedOnDay == 0) return -1;
          return a.learnedOnDay.compareTo(b.learnedOnDay);
        }
        // 3. Fallback to sortOrder for topics scheduled on the same day
        return a.sortOrder.compareTo(b.sortOrder);
      });
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
    final plans = getDayPlansForGoal(goalId); // already sorted by dayNumber

    // ── Primary: find explicitly unlocked + incomplete plan ──────────────
    for (final p in plans) {
      if (p.isUnlocked && !p.isCompleted) return p;
    }

    // ── Fallback: unlockNextDay may have failed silently.
    // Find the next sequential plan after the last completed one,
    // auto-unlock it, and return it so the user is never stuck.
    DayPlanModel? lastCompleted;
    for (final p in plans) {
      if (p.isCompleted) lastCompleted = p;
    }

    if (lastCompleted != null) {
      final nextIndex = plans.indexWhere((p) => p.dayNumber == lastCompleted!.dayNumber + 1);
      if (nextIndex != -1) {
        final next = plans[nextIndex];
        // Auto-unlock: compensate for any missed unlockNextDay call
        next.isUnlocked = true;
        next.startedAt ??= DateTime.now();
        HiveService.dayPlansBox.put(next.id, next);
        return next;
      }
    }

    // ── Last resort: no completed days yet — return day 1 if it exists
    if (plans.isNotEmpty && !plans.first.isCompleted) {
      final first = plans.first;
      if (!first.isUnlocked) {
        first.isUnlocked = true;
        HiveService.dayPlansBox.put(first.id, first);
      }
      return first;
    }

    return null; // All days completed or no plans exist
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
