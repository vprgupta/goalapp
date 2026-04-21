import '../../lib/data/models/goal_model.dart';
import '../../lib/data/models/topic_model.dart';
import '../../lib/data/models/day_plan_model.dart';
import '../../lib/data/models/task_model.dart';

/// In-memory fake implementation of GoalRepository.
/// Per flutter-testing-apps skill: "Prefer Fakes over Mocks" — gives clean,
/// predictable inputs/outputs without a mocking library.
class FakeGoalRepository {
  // In-memory stores
  final Map<String, GoalModel> _goals = {};
  final Map<String, TopicModel> _topics = {};
  final Map<String, DayPlanModel> _dayPlans = {};
  String? _selectedGoalId;

  // ── Goals ──────────────────────────────────────────────
  Future<void> saveGoal(GoalModel goal) async {
    _goals[goal.id] = goal;
    _selectedGoalId ??= goal.id;
  }

  GoalModel? getGoal(String id) => _goals[id];

  List<GoalModel> getAllGoals() => _goals.values.toList();

  String? getSelectedGoalId() => _selectedGoalId;

  Future<void> setSelectedGoalId(String id) async {
    _selectedGoalId = id;
  }

  Future<void> deleteGoal(String id) async {
    _goals.remove(id);
    if (_selectedGoalId == id) _selectedGoalId = null;
  }

  GoalModel? getActiveGoal() {
    try {
      return _goals.values.firstWhere((g) => g.status == GoalStatus.active);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateGoalComplete(String goalId) async {
    final g = _goals[goalId];
    if (g != null) g.status = GoalStatus.completed;
  }

  // ── Topics ─────────────────────────────────────────────
  Future<void> saveTopic(TopicModel topic) async => _topics[topic.id] = topic;

  Future<void> saveTopics(List<TopicModel> topics) async {
    for (final t in topics) {
      _topics[t.id] = t;
    }
  }

  TopicModel? getTopic(String id) => _topics[id];

  List<TopicModel> getTopicsForGoal(String goalId) =>
      _topics.values.where((t) => t.goalId == goalId).toList();

  // ── Day Plans ──────────────────────────────────────────
  Future<void> saveDayPlan(DayPlanModel dayPlan) async =>
      _dayPlans[dayPlan.id] = dayPlan;

  Future<void> saveDayPlans(List<DayPlanModel> plans) async {
    for (final p in plans) {
      _dayPlans[p.id] = p;
    }
  }

  DayPlanModel? getDayPlan(String id) => _dayPlans[id];

  List<DayPlanModel> getDayPlansForGoal(String goalId) =>
      _dayPlans.values.where((d) => d.goalId == goalId).toList()
        ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

  DayPlanModel? getCurrentDayPlan(String goalId) {
    try {
      return getDayPlansForGoal(goalId).firstWhere(
        (p) => p.isUnlocked && !p.isCompleted,
      );
    } catch (_) {
      return null;
    }
  }

  DayPlanModel? getDayPlanByNumber(String goalId, int dayNumber) {
    try {
      return _dayPlans.values.firstWhere(
        (d) => d.goalId == goalId && d.dayNumber == dayNumber,
      );
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
    final dayPlan = _dayPlans[dayPlanId];
    if (dayPlan == null) return;

    final taskIndex = dayPlan.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = dayPlan.tasks[taskIndex];
    task.status = TaskStatus.completed;
    task.completedAt = DateTime.now();

    if (task.recallPrompt != null && recallCorrect != null) {
      task.recallPrompt!.answeredCorrectly = recallCorrect;
    }
  }

  Future<void> markDayComplete(String dayPlanId) async {
    final dayPlan = _dayPlans[dayPlanId];
    if (dayPlan == null) return;
    dayPlan.isCompleted = true;
    dayPlan.completedAt = DateTime.now();
  }

  Future<void> unlockNextDay(String goalId, int nextDayNumber) async {
    final next = getDayPlanByNumber(goalId, nextDayNumber);
    if (next != null) {
      next.isUnlocked = true;
      next.startedAt = DateTime.now();
    }
    final goal = _goals[goalId];
    if (goal != null) goal.currentDay = nextDayNumber;
  }
}
