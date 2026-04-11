import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 4)
enum TaskType {
  @HiveField(0)
  learn,
  @HiveField(1)
  revise,
}

@HiveType(typeId: 5)
enum TaskStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  completed,
  @HiveField(2)
  skipped,
}

@HiveType(typeId: 6)
enum PromptType {
  @HiveField(0)
  question,
  @HiveField(1)
  flashcard,
  @HiveField(2)
  miniQuiz,
}

@HiveType(typeId: 7)
class RecallPrompt extends HiveObject {
  @HiveField(0)
  late PromptType type;

  @HiveField(1)
  late String prompt;

  @HiveField(2)
  late List<String>? options; // for miniQuiz

  @HiveField(3)
  late String? answer;

  @HiveField(4)
  late bool? answeredCorrectly;

  @HiveField(5)
  late int? selectedOptionIndex;

  RecallPrompt({
    required this.type,
    required this.prompt,
    this.options,
    this.answer,
    this.answeredCorrectly,
    this.selectedOptionIndex,
  });
}

@HiveType(typeId: 8)
class TaskModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String dayPlanId;

  @HiveField(2)
  late TaskType type;

  @HiveField(3)
  late String topicId;

  @HiveField(4)
  late String title;

  @HiveField(5)
  late String description;

  @HiveField(6)
  late int estimatedMinutes;

  @HiveField(7)
  late TaskStatus status;

  @HiveField(8)
  late RecallPrompt? recallPrompt; // only for revise tasks

  @HiveField(9)
  late DateTime? completedAt;

  @HiveField(10)
  late int sortOrder;

  @HiveField(11)
  late String? videoId;

  @HiveField(12)
  late int startSeconds;

  TaskModel({
    required this.id,
    required this.dayPlanId,
    required this.type,
    required this.topicId,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    this.status = TaskStatus.pending,
    this.recallPrompt,
    this.completedAt,
    required this.sortOrder,
    this.videoId,
    this.startSeconds = 0,
  });

  bool get isLearn => type == TaskType.learn;
  bool get isRevise => type == TaskType.revise;
  bool get isDone => status == TaskStatus.completed;
}
