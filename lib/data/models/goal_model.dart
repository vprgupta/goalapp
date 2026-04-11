import 'package:hive/hive.dart';

part 'goal_model.g.dart';

@HiveType(typeId: 0)
enum GoalStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  completed,
  @HiveField(2)
  paused,
}

@HiveType(typeId: 1)
class GoalModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String level; // beginner | intermediate | advanced

  @HiveField(3)
  late int totalDays;

  @HiveField(4)
  late int currentDay; // 1-indexed progress pointer

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late GoalStatus status;

  @HiveField(7)
  late List<String> topicIds;

  @HiveField(8)
  late Map<String, double> topicStrengths; // topicId -> 0.0–1.0

  GoalModel({
    required this.id,
    required this.name,
    required this.level,
    required this.totalDays,
    this.currentDay = 1,
    required this.createdAt,
    this.status = GoalStatus.active,
    List<String>? topicIds,
    Map<String, double>? topicStrengths,
  })  : topicIds = topicIds ?? [],
        topicStrengths = topicStrengths ?? {};

  double get overallStrength {
    if (topicStrengths.isEmpty) return 0.0;
    final sum = topicStrengths.values.fold(0.0, (a, b) => a + b);
    return sum / topicStrengths.length;
  }

  double get progressPercent => currentDay / totalDays;
}
