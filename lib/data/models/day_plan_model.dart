import 'package:hive/hive.dart';
import 'task_model.dart';

part 'day_plan_model.g.dart';

@HiveType(typeId: 3)
class DayPlanModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String goalId;

  @HiveField(2)
  late int dayNumber; // 1-indexed

  @HiveField(3)
  late List<TaskModel> tasks;

  @HiveField(4)
  late bool isUnlocked;

  @HiveField(5)
  late bool isCompleted;

  @HiveField(6)
  late DateTime? completedAt;

  @HiveField(7)
  late DateTime? startedAt;

  DayPlanModel({
    required this.id,
    required this.goalId,
    required this.dayNumber,
    List<TaskModel>? tasks,
    this.isUnlocked = false,
    this.isCompleted = false,
    this.completedAt,
    this.startedAt,
  }) : tasks = tasks ?? [];

  bool get allTasksDone => tasks.every((t) => t.status != TaskStatus.pending);

  int get completedCount => tasks.where((t) => t.status == TaskStatus.completed).length;

  int get pendingCount => tasks.where((t) => t.status == TaskStatus.pending).length;

  double get completionPercent => tasks.isEmpty ? 0 : completedCount / tasks.length;

  List<TaskModel> get learnTasks => tasks.where((t) => t.type == TaskType.learn).toList();

  List<TaskModel> get reviseTasks => tasks.where((t) => t.type == TaskType.revise).toList();
}
