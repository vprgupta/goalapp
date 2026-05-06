import 'package:uuid/uuid.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/day_plan_model.dart';
import '../../data/models/task_model.dart';
import 'revision_scheduler.dart';

/// Core engine that distributes topics and revision tasks across all plan days.
///
/// DESIGN PRINCIPLES:
/// 1. Topics are spread EVENLY — never front-loaded. Each day gets at most
///    [_learnPerDay] learn tasks, derived from totalDays ÷ totalTopics.
/// 2. Revision intervals are scaled to the plan length so they always fire
///    within the available days.
/// 3. Every day has a meaningful task — no silent empty days.
/// 4. Later days feel lighter (more revision, fewer new topics) by design.
class TaskDistributor {
  static const _uuid = Uuid();

  /// Absolute max tasks a user sees in one day (learn + revise combined).
  static const int _maxTasksPerDay = 5;

  static List<DayPlanModel> distribute({
    required GoalModel goal,
    required List<TopicModel> topics,
  }) {
    final int totalDays = goal.totalDays;
    final String goalId = goal.id;
    final List<TopicModel> activeTopics = List<TopicModel>.from(topics);

    if (activeTopics.isEmpty || totalDays <= 0) return [];

    // ── 1. Compute HOW MANY new topics to teach per day ─────────────────────
    // Formula: spread topics as evenly as possible.
    // If 8 topics over 8 days → 1/day. 6 topics over 8 days → 1/day (last 2 = review days).
    // If more topics than days → allow up to 2/day for short plans.
    final int learnPerDay = _computeLearnPerDay(
      totalTopics: activeTopics.length,
      totalDays: totalDays,
    );

    // ── 2. Scale revision intervals to the plan length ────────────────────
    // For short plans (≤10 days), use tighter intervals so revisions fire
    // before the plan ends. For longer plans, use Ebbinghaus intervals.
    final List<int> easyIntervals = _scaledIntervals(totalDays, isHard: false);
    final List<int> hardIntervals = _scaledIntervals(totalDays, isHard: true);

    // Revision queue: { dayNumber → [topicId] }
    final Map<int, List<String>> revisionQueue = {};

    // Initialize day plans
    final List<DayPlanModel> dayPlans = List.generate(totalDays, (i) {
      return DayPlanModel(
        id: _uuid.v4(),
        goalId: goalId,
        dayNumber: i + 1,
        isUnlocked: i == 0,
      );
    });

    int topicPointer = 0;

    for (int d = 1; d <= totalDays; d++) {
      final DayPlanModel dayPlan = dayPlans[d - 1];
      final String dayId = dayPlan.id;
      final List<TaskModel> tasks = [];
      int sortOrder = 0;

      // ── Step A: Add revision tasks scheduled for today ──────────────────
      final List<String> revDue = List<String>.from(revisionQueue[d] ?? []);
      // Cap revisions: leave room for at least 1 learn slot if topics remain
      final int maxRevToday = (topicPointer < activeTopics.length)
          ? (_maxTasksPerDay - learnPerDay).clamp(1, 3)
          : _maxTasksPerDay; // Pure revision day when all topics learned

      int revCount = 0;
      for (final String topicId in revDue) {
        if (revCount >= maxRevToday) {
          // Push overflow to the next available day
          _pushRevisionForward(topicId, d + 1, totalDays, revisionQueue);
          continue;
        }
        final int topicIdx = activeTopics.indexWhere((t) => t.id == topicId);
        if (topicIdx == -1) continue;
        final TopicModel topic = activeTopics[topicIdx];

        final RecallPrompt recall = RevisionScheduler.buildRecallPrompt(topic);
        tasks.add(TaskModel(
          id: _uuid.v4(),
          dayPlanId: dayId,
          type: TaskType.revise,
          topicId: topicId,
          title: 'Revise: ${topic.name}',
          description: topic.subTopics.isNotEmpty
              ? 'Recall focus: ${topic.subTopics.take(3).join(', ')}'
              : recall.prompt,
          estimatedMinutes: RevisionScheduler.reviseEstimate(topic),
          recallPrompt: recall,
          sortOrder: sortOrder++,
          videoId: topic.videoId,
          startSeconds: topic.startSeconds,
        ));
        revCount++;
      }

      // ── Step B: Add learn tasks for today ──────────────────────────────
      // How many learn slots do we still have today?
      final int learnSlotsToday = (learnPerDay).clamp(1, _maxTasksPerDay - tasks.length);
      int learnCount = 0;

      while (
        topicPointer < activeTopics.length &&
        learnCount < learnSlotsToday &&
        tasks.length < _maxTasksPerDay
      ) {
        final TopicModel topic = activeTopics[topicPointer];

        tasks.add(TaskModel(
          id: _uuid.v4(),
          dayPlanId: dayId,
          type: TaskType.learn,
          topicId: topic.id,
          title: topic.name,
          description: _buildLearnDescription(topic),
          estimatedMinutes: topic.estimatedLearnMinutes,
          sortOrder: sortOrder++,
          videoId: topic.videoId,
          startSeconds: topic.startSeconds,
        ));

        // Schedule revisions using plan-aware scaled intervals
        final bool isHard = topic.tier >= 3 || topic.isBoss;
        final List<int> intervals = isHard ? hardIntervals : easyIntervals;
        _scheduleRevisions(
          topic: topic,
          learnDay: d,
          totalDays: totalDays,
          intervals: intervals,
          revisionQueue: revisionQueue,
        );

        topicPointer++;
        learnCount++;
      }

      // ── Step C: Ensure every day has at least 1 task ───────────────────
      if (tasks.isEmpty) {
        // Pick the weakest-retention topic for a free review session
        final TopicModel? weakTopic = activeTopics.isNotEmpty
            ? activeTopics.reduce((a, b) =>
                a.strengthScore < b.strengthScore ? a : b)
            : null;

        tasks.add(TaskModel(
          id: _uuid.v4(),
          dayPlanId: dayId,
          type: TaskType.revise,
          topicId: weakTopic?.id ?? '',
          title: weakTopic != null
              ? '🔁 Strengthen: ${weakTopic.name}'
              : '📖 Free Review Day',
          description: weakTopic != null
              ? 'You haven\'t fully retained "${weakTopic.name}" — revisit notes and do one exercise.'
              : 'Revisit your notes from this phase. Re-read, quiz yourself, and consolidate.',
          estimatedMinutes: 15,
          sortOrder: 0,
        ));
      }

      // ── Step D: Sort — revise first (warm-up), then learn by difficulty ─
      tasks.sort((a, b) {
        // Revise tasks always first (quick warm-up before new material)
        if (a.type == TaskType.revise && b.type != TaskType.revise) return -1;
        if (b.type == TaskType.revise && a.type != TaskType.revise) return 1;
        // Among learn tasks, easier topics first (lower cognitive load)
        final int aLoad = activeTopics
            .where((t) => t.id == a.topicId)
            .map((t) => t.cognitiveLoad)
            .firstOrNull ?? 5;
        final int bLoad = activeTopics
            .where((t) => t.id == b.topicId)
            .map((t) => t.cognitiveLoad)
            .firstOrNull ?? 5;
        return aLoad.compareTo(bLoad);
      });

      // Re-number sortOrders after sorting
      for (int i = 0; i < tasks.length; i++) {
        tasks[i].sortOrder = i;
      }

      dayPlan.tasks = tasks;
    }

    return dayPlans;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Computes how many new learn topics to assign per day.
  /// Ensures topics are spread evenly, never front-loaded.
  static int _computeLearnPerDay({
    required int totalTopics,
    required int totalDays,
  }) {
    if (totalDays <= 0) return 1;
    // We want to finish learning all topics by 70% of the plan
    // so the last 30% of days are primarily consolidation/revision days.
    final int learningWindowDays = (totalDays * 0.70).ceil().clamp(1, totalDays);
    // How many per day in the learning window
    final int perDay = (totalTopics / learningWindowDays).ceil().clamp(1, 2);
    return perDay;
  }

  /// Returns revision intervals scaled to the plan length.
  /// For a 7-day plan: [2, 4, 6] for easy, [1, 3, 5] for hard.
  /// For a 30-day plan: [3, 7, 14] for easy, [1, 3, 7, 14] for hard.
  static List<int> _scaledIntervals(int totalDays, {required bool isHard}) {
    if (totalDays <= 7) {
      // Very short plan: tight intervals to guarantee at least 2 reviews
      return isHard ? [1, 3, 5] : [2, 4, 6];
    } else if (totalDays <= 14) {
      // Short plan: moderate intervals
      return isHard ? [1, 3, 7] : [2, 5, 10];
    } else if (totalDays <= 30) {
      // Medium plan: Ebbinghaus-based
      return isHard ? [1, 3, 7, 14] : [3, 7, 14];
    } else {
      // Long plan: full spaced repetition
      return isHard ? [1, 3, 7, 14, 21] : [3, 7, 14, 21];
    }
  }

  /// Schedules revision tasks for a topic using the given intervals.
  static void _scheduleRevisions({
    required TopicModel topic,
    required int learnDay,
    required int totalDays,
    required List<int> intervals,
    required Map<int, List<String>> revisionQueue,
  }) {
    topic.scheduledRevisions.clear();
    for (final int interval in intervals) {
      final int targetDay = learnDay + interval;
      if (targetDay <= totalDays) {
        topic.scheduledRevisions.add(targetDay);
        revisionQueue.putIfAbsent(targetDay, () => []).add(topic.id);
      }
    }
  }

  /// Pushes an overflowed revision to the next available slot.
  static void _pushRevisionForward(
    String topicId,
    int fromDay,
    int totalDays,
    Map<int, List<String>> queue,
  ) {
    for (int d = fromDay; d <= totalDays; d++) {
      final bool alreadyQueued = queue[d]?.contains(topicId) ?? false;
      if (!alreadyQueued) {
        queue.putIfAbsent(d, () => []).add(topicId);
        return;
      }
    }
    // If no slot found within the plan, silently drop (plan finished)
  }

  static String _buildLearnDescription(TopicModel topic) {
    final String tierLabel = topic.tier == 1
        ? 'Foundational concept'
        : topic.tier == 2
            ? 'Intermediate concept'
            : 'Advanced concept';
    return '$tierLabel — Study this topic, take notes, and practice with at least one example.';
  }

  /// Rebalances remaining day plans when duration changes mid-plan.
  static List<DayPlanModel> rebalance({
    required GoalModel goal,
    required List<TopicModel> allTopics,
    required List<DayPlanModel> existingPlans,
    required int newTotalDays,
  }) {
    final List<DayPlanModel> completed =
        existingPlans.where((p) => p.isCompleted).toList();
    final int lastCompletedDay =
        completed.isEmpty ? 0 : completed.last.dayNumber;

    final List<TopicModel> remainingTopics =
        allTopics.where((t) => t.learnedOnDay == 0).toList();

    final GoalModel adjustedGoal = GoalModel(
      id: goal.id,
      name: goal.name,
      level: goal.level,
      totalDays: newTotalDays - lastCompletedDay,
      createdAt: goal.createdAt,
    );

    final List<DayPlanModel> newDays =
        distribute(goal: adjustedGoal, topics: remainingTopics);
    for (int i = 0; i < newDays.length; i++) {
      newDays[i].goalId = goal.id;
      newDays[i].isUnlocked = i == 0;
    }

    return [...completed, ...newDays];
  }
}
