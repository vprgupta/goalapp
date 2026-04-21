import 'package:flutter_test/flutter_test.dart';
import 'package:goalapp/data/models/goal_model.dart';
import 'package:goalapp/data/models/topic_model.dart';
import 'package:goalapp/domain/engines/task_distributor.dart';

void main() {
  group('TaskDistributor Unit Tests', () {
    test('distribute correctly allocations topics into days and schedules revisions', () {
      final goal = GoalModel(
        id: 'test_goal_1',
        name: 'Test Goal',
        level: 'beginner',
        totalDays: 5,
        createdAt: DateTime.now(),
      );

      final topics = List<TopicModel>.generate(4, (i) => TopicModel(
        id: 'topic_\$i',
        goalId: 'test_goal_1',
        name: 'Topic \$i',
        sortOrder: i,
        moduleName: 'Test Module',
        tier: 1,
        estimatedLearnMinutes: 15,
      ));

      // Act
      final dayPlans = TaskDistributor.distribute(goal: goal, topics: topics);

      // Assert Basics
      expect(dayPlans.length, 5, reason: 'Should generate exactly 5 day plans based on totalDays.');
      expect(dayPlans.first.isUnlocked, true, reason: 'First day must always be unlocked.');
      expect(dayPlans.last.isUnlocked, false, reason: 'Future days should be locked initially.');

      // Assert Tasks
      int totalLearnTasks = 0;
      int totalReviseTasks = 0;
      
      for (var plan in dayPlans) {
        totalLearnTasks += plan.tasks.where((t) => t.isLearn).length;
        totalReviseTasks += plan.tasks.where((t) => t.isRevise).length;
      }

      // We supplied 4 topics, but distributor takes clamp of 85% days. 
      // 5 days * 0.85 = 4.25 -> 4 active topics
      expect(totalLearnTasks, 4, reason: 'Should distribute all 4 learning tasks.');
      
      // With spaced repetition (days 1, 3, 7 offsets), a 5-day plan will have some revisions scheduled.
      expect(totalReviseTasks, greaterThan(0), reason: 'Should schedule revision tasks based on the spaced repetition algorithm.');
      
      // Check maximum tasks limit (limit is 6 max tasks per day, max 2 learn, max 4 revise)
      for (var plan in dayPlans) {
        expect(plan.tasks.length, lessThanOrEqualTo(6));
        expect(plan.tasks.where((t) => t.isLearn).length, lessThanOrEqualTo(2));
        expect(plan.tasks.where((t) => t.isRevise).length, lessThanOrEqualTo(4));
      }
    });
  });
}
