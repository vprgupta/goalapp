import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goalapp/data/models/task_model.dart';
import 'package:goalapp/presentation/screens/dashboard/task_card_widget.dart';
import 'package:goalapp/l10n/generated/app_localizations.dart';

void main() {
  group('TaskCardWidget Widget Tests', () {
    testWidgets('renders LEARN badge for non-revision tasks', (WidgetTester tester) async {
      // 1. Arrange 
      final TaskModel learnTask = TaskModel(
        id: 'task_1',
        dayPlanId: 'plan_1',
        type: TaskType.learn,
        topicId: 'topic_1',
        title: 'Learn Variables',
        description: 'Mock desc',
        estimatedMinutes: 10,
        sortOrder: 0,
      );

      // 2. Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskCardWidget(
                task: learnTask, 
                topicName: 'Variables', 
                onComplete: ({bool? recallCorrect}) {}, 
                isCompleted: false,
                isExpanded: true,
                isExpanding: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 3. Assert
      expect(find.text('LEARN'), findsOneWidget);
      expect(find.text('REVISE'), findsNothing);
      expect(find.text('Learn Variables'), findsOneWidget);
    });

    testWidgets('renders REVISE badge for revision tasks', (WidgetTester tester) async {
      final TaskModel reviseTask = TaskModel(
        id: 'task_2',
        dayPlanId: 'plan_1',
        type: TaskType.revise,
        topicId: 'topic_2',
        title: 'Review Loops',
        description: 'Mock desc',
        estimatedMinutes: 5,
        sortOrder: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskCardWidget(
                task: reviseTask, 
                topicName: 'Loops', 
                onComplete: ({bool? recallCorrect}) {}, 
                isCompleted: false,
                isExpanded: true,
                isExpanding: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('REVISE'), findsOneWidget);
      expect(find.text('LEARN'), findsNothing);
    });
  });
}
