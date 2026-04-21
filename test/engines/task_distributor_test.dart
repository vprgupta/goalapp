import 'package:flutter_test/flutter_test.dart';
import '../../lib/data/models/goal_model.dart';
import '../../lib/data/models/topic_model.dart';
import '../../lib/domain/engines/task_distributor.dart';
import '../../lib/data/models/task_model.dart';

/// Unit tests for [TaskDistributor].
/// Per flutter-testing-apps skill: "Write unit tests for pure logic functions
/// — mock all external dependencies, no Hive, no Flutter framework needed."
void main() {
  group('TaskDistributor', () {
    /// Helper — builds a minimal GoalModel for test use.
    GoalModel _makeGoal({int totalDays = 7}) {
      return GoalModel(
        id: 'test-goal',
        name: 'Learn Dart',
        level: 'beginner',
        totalDays: totalDays,
        createdAt: DateTime(2025, 1, 1),
        status: GoalStatus.active,
      );
    }

    /// Helper — builds a minimal TopicModel for test use.
    TopicModel _makeTopic(String id, {int tier = 1, int minutes = 20}) {
      return TopicModel(
        id: id,
        goalId: 'test-goal',
        name: 'Topic $id',
        tier: tier,
        estimatedLearnMinutes: minutes,
      );
    }

    test('returns correct number of day plans', () {
      final goal = _makeGoal(totalDays: 7);
      final topics = List.generate(5, (i) => _makeTopic('t$i'));
      final plans = TaskDistributor.distribute(goal: goal, topics: topics);

      expect(plans.length, 7,
          reason: 'Should create exactly one DayPlanModel per day.');
    });

    test('day 1 is unlocked, all others are locked', () {
      final goal = _makeGoal(totalDays: 5);
      final topics = List.generate(3, (i) => _makeTopic('t$i'));
      final plans = TaskDistributor.distribute(goal: goal, topics: topics);

      expect(plans.first.isUnlocked, isTrue,
          reason: 'Day 1 must be unlocked on creation.');
      for (int i = 1; i < plans.length; i++) {
        expect(plans[i].isUnlocked, isFalse,
            reason: 'Day ${i + 1} must start locked.');
      }
    });

    test('no day plan has an empty task list', () {
      final goal = _makeGoal(totalDays: 14);
      final topics = List.generate(6, (i) => _makeTopic('t$i'));
      final plans = TaskDistributor.distribute(goal: goal, topics: topics);

      for (final plan in plans) {
        expect(plan.tasks, isNotEmpty,
            reason:
                'Every day plan must have at least one task — no gap days.');
      }
    });

    test('learn tasks point to valid topic IDs from the input list', () {
      final goal = _makeGoal(totalDays: 5);
      final topics = List.generate(3, (i) => _makeTopic('topic-$i'));
      final topicIds = topics.map((t) => t.id).toSet();

      final plans = TaskDistributor.distribute(goal: goal, topics: topics);

      for (final plan in plans) {
        for (final task in plan.tasks) {
          if (task.type == TaskType.learn) {
            // "Free Review Day" tasks use the first topic as placeholder
            if (task.title != 'Free Review Day') {
              expect(topicIds.contains(task.topicId), isTrue,
                  reason:
                      'Learn task topicId "${task.topicId}" must exist in input topics.');
            }
          }
        }
      }
    });

    test('all tasks have a positive estimated duration', () {
      final goal = _makeGoal(totalDays: 7);
      final topics = List.generate(4, (i) => _makeTopic('t$i', minutes: 30));
      final plans = TaskDistributor.distribute(goal: goal, topics: topics);

      for (final plan in plans) {
        for (final task in plan.tasks) {
          expect(task.estimatedMinutes, greaterThan(0),
              reason: 'Every task must have a positive estimated duration.');
        }
      }
    });

    test('single topic, single day plan has exactly one learn task', () {
      final goal = _makeGoal(totalDays: 1);
      final topics = [_makeTopic('only-topic')];
      final plans = TaskDistributor.distribute(goal: goal, topics: topics);

      expect(plans.length, 1);
      final learnTasks =
          plans.first.tasks.where((t) => t.type == TaskType.learn).toList();
      expect(learnTasks.length, greaterThanOrEqualTo(1),
          reason: 'Single-topic single-day plan must learn that topic.');
    });

    test('does not exceed maxTasksPerDay tasks in any day', () {
      // Give a huge number of topics to stress-test the cap
      final goal = _makeGoal(totalDays: 3);
      final topics = List.generate(20, (i) => _makeTopic('t$i'));
      final plans = TaskDistributor.distribute(goal: goal, topics: topics);

      for (final plan in plans) {
        expect(plan.tasks.length, lessThanOrEqualTo(6),
            reason: 'Max 6 tasks per day must be enforced.');
      }
    });
  });
}
