import 'package:uuid/uuid.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/day_plan_model.dart';
import '../../data/models/task_model.dart';
import 'revision_scheduler.dart';

/// Core engine that distributes topics and revision tasks across all plan days.
class TaskDistributor {
  static const _uuid = Uuid();

  /// Max tasks per day and slot allocations
  static const int _maxTasksPerDay = 6;
  static const int _maxLearnPerDay = 2;
  static const int _maxRevisePerDay = 4;

  static List<DayPlanModel> distribute({
    required GoalModel goal,
    required List<TopicModel> topics,
  }) {
    final totalDays = goal.totalDays;
    final goalId = goal.id;

    final activeTopics = List<TopicModel>.from(topics);

    // ── Day capacity in minutes ───────────────────────────────────────────
    // Each day targets ~60 min of learning. Hard topics cost more capacity.
    const int dayCapacityMin = 60;

    // Revision queue: {dayNumber → [topicId]}
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
      final dayPlan = dayPlans[d - 1];
      final dayId = dayPlan.id;
      final List<TaskModel> tasks = [];
      int sortOrder = 0;
      int minutesUsed = 0;

      // ── Step 1: Add revision tasks due this day ─────────────────────────
      final revDue = List<String>.from(revisionQueue[d] ?? []);
      int revCount = 0;
      for (final topicId in revDue) {
        if (revCount >= _maxRevisePerDay) {
          _pushRevisionForward(topicId, d + 1, totalDays, revisionQueue);
          continue;
        }
        final topicIdx = activeTopics.indexWhere((t) => t.id == topicId);
        if (topicIdx == -1) continue;
        final topic = activeTopics[topicIdx];

        final recall = RevisionScheduler.buildRecallPrompt(topic);
        final revMin = RevisionScheduler.reviseEstimate(topic);
        tasks.add(TaskModel(
          id: _uuid.v4(),
          dayPlanId: dayId,
          type: TaskType.revise,
          topicId: topicId,
          title: 'Revise: ${topic.name}',
          description: topic.subTopics.isNotEmpty
              ? 'Recall focus: ${topic.subTopics.join(", ")}'
              : recall.prompt,
          estimatedMinutes: revMin,
          recallPrompt: recall,
          sortOrder: sortOrder++,
          videoId: topic.videoId,
          startSeconds: topic.startSeconds,
        ));
        minutesUsed += revMin;
        revCount++;
      }

      // ── Step 2: Fill learn tasks up to day capacity ─────────────────────
      // Hard topics (rank A/S or tier 3) cost extra capacity — they get 1
      // slot but consume 2× minutes, preventing overloading on hard days.
      while (
        topicPointer < activeTopics.length &&
        minutesUsed < dayCapacityMin &&
        tasks.length < _maxTasksPerDay
      ) {
        final topic = activeTopics[topicPointer];
        final cost = _topicCost(topic); // minutes this topic "costs"

        // If adding this topic would exceed capacity AND we already have 1
        // learn task today, defer it to tomorrow.
        if (minutesUsed > 0 && minutesUsed + cost > dayCapacityMin + 15) break;

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
        minutesUsed += cost;

        // Hard topics (tier 3) get a rapid-fire revision the very next day
        final isHard = topic.tier >= 3;
        RevisionScheduler.scheduleRevisions(
          topic: topic,
          learnDay: d,
          totalDays: totalDays,
          revisionQueue: revisionQueue,
          forceEarlyRevision: isHard, // next-day revision for hard topics
        );

        topicPointer++;
      }

      // ── Step 3: Ensure at least 1 task per day ──────────────────────────
      if (tasks.isEmpty && topicPointer < activeTopics.length) {
        final topic = activeTopics[topicPointer];
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
        RevisionScheduler.scheduleRevisions(
          topic: topic,
          learnDay: d,
          totalDays: totalDays,
          revisionQueue: revisionQueue,
        );
        topicPointer++;
      }

      // ── Step 4: Gap day — add smart free review ──────────────────────────
      if (tasks.isEmpty) {
        // Pick the weakest topic (lowest strengthScore) for the free review
        final weakTopic = activeTopics.isNotEmpty
            ? activeTopics.reduce((a, b) => a.strengthScore < b.strengthScore ? a : b)
            : null;
        tasks.add(TaskModel(
          id: _uuid.v4(),
          dayPlanId: dayId,
          type: TaskType.revise,
          topicId: weakTopic?.id ?? '',
          title: weakTopic != null
              ? 'Strengthen: ${weakTopic.name}'
              : 'Free Review Day',
          description: 'Revisit your weakest concept. Re-read notes, redo exercises.',
          estimatedMinutes: 20,
          sortOrder: 0,
        ));
      }

      dayPlan.tasks = tasks;
    }

    return dayPlans;
  }

  static int _topicCost(TopicModel topic) {
    // Tier 3 topics cost 2× capacity to give them breathing room in the schedule
    return topic.tier >= 3
        ? topic.estimatedLearnMinutes * 2
        : topic.estimatedLearnMinutes;
  }

  static void _pushRevisionForward(
    String topicId,
    int fromDay,
    int totalDays,
    Map<int, List<String>> queue,
  ) {
    for (int d = fromDay; d <= totalDays; d++) {
      final existing = queue[d]?.where((id) => id == topicId).length ?? 0;
      if (existing == 0) {
        queue.putIfAbsent(d, () => []).add(topicId);
        return;
      }
    }
    // If no room found, just drop it (totalDays exceeded)
  }

  static int reviseEstimate(TopicModel topic) {
    // Shorter revision if strong, longer if weak
    if (topic.strengthScore > 0.7) return 8;
    if (topic.strengthScore > 0.4) return 12;
    return 18;
  }

  static String _buildLearnDescription(TopicModel topic) {
    final tierLabel = topic.tier == 1
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
    // Keep all completed days
    final completed = existingPlans.where((p) => p.isCompleted).toList();
    final lastCompletedDay = completed.isEmpty ? 0 : completed.last.dayNumber;

    // Regenerate from lastCompletedDay+1 onward
    final remainingTopics = allTopics.where((t) => t.learnedOnDay == 0).toList();
    final adjustedGoal = GoalModel(
      id: goal.id,
      name: goal.name,
      level: goal.level,
      totalDays: newTotalDays - lastCompletedDay,
      createdAt: goal.createdAt,
    );

    final newDays = distribute(goal: adjustedGoal, topics: remainingTopics);
    // Renumber days
    for (int i = 0; i < newDays.length; i++) {
      newDays[i].goalId = goal.id;
      newDays[i].isUnlocked = i == 0;
    }

    return [...completed, ...newDays];
  }
}
