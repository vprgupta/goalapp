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

    // Trim topics to a realistic count (ensure enough days for revision too)
    // Target: max 60% of days used for learning (40% headroom for revisions)
    final maxTopics = (totalDays * 0.65).floor().clamp(1, topics.length);
    final activeTopics = topics.sublist(0, maxTopics);

    // Revision queue: {dayNumber -> [topicId]}
    final Map<int, List<String>> revisionQueue = {};

    // Initialize day plans
    final List<DayPlanModel> dayPlans = List.generate(totalDays, (i) {
      return DayPlanModel(
        id: _uuid.v4(),
        goalId: goalId,
        dayNumber: i + 1,
        isUnlocked: i == 0, // only day 1 is unlocked initially
      );
    });

    int topicPointer = 0;

    for (int d = 1; d <= totalDays; d++) {
      final dayPlan = dayPlans[d - 1];
      final dayId = dayPlan.id;
      final List<TaskModel> tasks = [];
      int sortOrder = 0;

      // ── Step 1: Add revision tasks due this day ─────────────────────
      final revDue = List<String>.from(revisionQueue[d] ?? []);
      int revCount = 0;
      for (final topicId in revDue) {
        if (revCount >= _maxRevisePerDay) {
          // Overflow: push to next available day
          _pushRevisionForward(topicId, d + 1, totalDays, revisionQueue);
          continue;
        }
        final topicIdx = activeTopics.indexWhere((t) => t.id == topicId);
        if (topicIdx == -1) continue;
        final topic = activeTopics[topicIdx];

        final recall = RevisionScheduler.buildRecallPrompt(topic);
        tasks.add(TaskModel(
          id: _uuid.v4(),
          dayPlanId: dayId,
          type: TaskType.revise,
          topicId: topicId,
          title: 'Revise: ${topic.name}',
          description: topic.subTopics.isNotEmpty 
              ? 'Recall focus: ${topic.subTopics.join(", ")}'
              : recall.prompt,
          estimatedMinutes: _reviseEstimate(topic),
          recallPrompt: recall,
          sortOrder: sortOrder++,
          videoId: topic.videoId,
          startSeconds: topic.startSeconds,
        ));
        revCount++;
      }

      // ── Step 2: Fill learn tasks (up to 2, or until topic list exhausted) ─
      int learnCount = 0;
      while (
        topicPointer < activeTopics.length &&
        learnCount < _maxLearnPerDay &&
        tasks.length < _maxTasksPerDay
      ) {
        final topic = activeTopics[topicPointer];
        tasks.add(
          TaskModel(
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
          ),
        );

        // Schedule Ebbinghaus revisions
        RevisionScheduler.scheduleRevisions(
          topic: topic,
          learnDay: d,
          totalDays: totalDays,
          revisionQueue: revisionQueue,
        );

        topicPointer++;
        learnCount++;
      }

      // ── Step 3: If still no tasks today (revision-only or gap day) ──
      // Add a "review strength" placeholder if we have weak topics
      if (tasks.isEmpty) {
        tasks.add(TaskModel(
          id: _uuid.v4(),
          dayPlanId: dayId,
          type: TaskType.revise,
          topicId: activeTopics.isNotEmpty ? activeTopics.first.id : '',
          title: 'Free Review Day',
          description: 'Revisit any topic you found challenging. Strengthen your weakest concept.',
          estimatedMinutes: 15,
          sortOrder: 0,
        ));
      }

      dayPlan.tasks = tasks;
    }

    return dayPlans;
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

  static int _reviseEstimate(TopicModel topic) {
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
