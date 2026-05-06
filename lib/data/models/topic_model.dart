import 'package:hive/hive.dart';

part 'topic_model.g.dart';

@HiveType(typeId: 2)
class TopicModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String goalId;

  @HiveField(2)
  late String name;

  @HiveField(3)
  late int learnedOnDay; // plan-day it was first learned (0 = not yet)

  @HiveField(4)
  late double strengthScore; // 0.0–1.0

  @HiveField(5)
  late int revisionCount;

  @HiveField(6)
  late List<int> scheduledRevisions; // plan-day numbers

  @HiveField(7)
  late List<int> completedRevisions; // plan-day numbers

  @HiveField(8)
  late DateTime? lastRevisedAt;

  @HiveField(9)
  late int tier; // 1 | 2 | 3 (difficulty)

  @HiveField(10)
  late int estimatedLearnMinutes;

  @HiveField(11)
  late int incorrectAnswers; // consecutive wrong recall answers

  @HiveField(12)
  late String? videoId;

  @HiveField(13)
  late String? thumbnailUrl;

  @HiveField(14)
  late int startSeconds;

  @HiveField(15)
  late List<String> subTopics;

  @HiveField(16)
  late String? moduleName; // e.g. "World 1: Fundamentals"

  @HiveField(17)
  late bool isBoss; // Marks the end-of-chapter milestone

  @HiveField(18)
  late List<String> resources; // JSON-encoded curated resources

  @HiveField(19)
  late List<String> prerequisites; // DAG dependencies

  @HiveField(20)
  late double weight; // Importance 0.0 - 1.0

  @HiveField(21)
  late double retentionScore; // 0.0 - 100.0

  @HiveField(22)
  late Map<String, int> errorTypes; // e.g. {"conceptual": 1, "careless": 2}

  @HiveField(23)
  late bool isBlueprintGenerated;

  // ── FSRS Mathematical Parameters ──
  @HiveField(24)
  late double stability; // Interval growth rate

  @HiveField(25)
  late double difficulty; // How inherently hard the topic is

  @HiveField(26)
  late int sortOrder; // Logical sequence index

  @HiveField(27, defaultValue: 5)
  late int cognitiveLoad; // 1-10

  TopicModel({
    required this.id,
    required this.goalId,
    required this.name,
    this.learnedOnDay = 0,
    this.strengthScore = 0.0,
    this.revisionCount = 0,
    List<int>? scheduledRevisions,
    List<int>? completedRevisions,
    this.lastRevisedAt,
    required this.tier,
    required this.estimatedLearnMinutes,
    this.incorrectAnswers = 0,
    this.videoId,
    this.thumbnailUrl,
    this.startSeconds = 0,
    List<String>? subTopics,
    this.moduleName,
    this.isBoss = false,
    List<String>? resources,
    List<String>? prerequisites,
    this.weight = 0.5,
    this.retentionScore = 0.0,
    Map<String, int>? errorTypes,
    this.isBlueprintGenerated = false,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.sortOrder = 0,
    this.cognitiveLoad = 5,
  })  : scheduledRevisions = scheduledRevisions ?? [],
        completedRevisions = completedRevisions ?? [],
        subTopics = subTopics ?? [],
        resources = resources ?? [],
        prerequisites = prerequisites ?? [],
        errorTypes = errorTypes ?? {};

  bool get isLearned => learnedOnDay > 0;
  bool get isStruggling => incorrectAnswers >= 3;

  String get strengthLabel {
    if (strengthScore < 0.3) return 'Weak';
    if (strengthScore < 0.6) return 'Fair';
    if (strengthScore < 0.85) return 'Strong';
    return 'Mastered';
  }
}
