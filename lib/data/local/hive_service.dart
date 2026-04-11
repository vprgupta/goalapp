import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/goal_model.dart';
import '../models/topic_model.dart';
import '../models/day_plan_model.dart';
import '../models/task_model.dart';

class HiveService {
  static const String _goalsBox = 'goals';
  static const String _topicsBox = 'topics';
  static const String _dayPlansBox = 'day_plans';
  static const String _settingsBox = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register all adapters
    Hive.registerAdapter(GoalStatusAdapter());
    Hive.registerAdapter(GoalModelAdapter());
    Hive.registerAdapter(TopicModelAdapter());
    Hive.registerAdapter(DayPlanModelAdapter());
    Hive.registerAdapter(TaskTypeAdapter());
    Hive.registerAdapter(TaskStatusAdapter());
    Hive.registerAdapter(PromptTypeAdapter());
    Hive.registerAdapter(RecallPromptAdapter());
    Hive.registerAdapter(TaskModelAdapter());

    // Open boxes with resilience
    debugPrint('Database: Initializing Hive...');
    await _openResilientBox<GoalModel>(_goalsBox);
    await _openResilientBox<TopicModel>(_topicsBox);
    await _openResilientBox<DayPlanModel>(_dayPlansBox);
    await _openResilientBox(_settingsBox);
    debugPrint('Database: Hive Initialized.');
  }

  static Future<Box<T>> _openResilientBox<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (e) {
      debugPrint('Database: Error opening box $name, wiping... $e');
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      return await Hive.openBox<T>(name);
    }
  }

  static bool isBoxOpen(String name) => Hive.isBoxOpen(name);

  static Box<GoalModel> get goalsBox => Hive.box<GoalModel>(_goalsBox);
  static Box<TopicModel> get topicsBox => Hive.box<TopicModel>(_topicsBox);
  static Box<DayPlanModel> get dayPlansBox => Hive.box<DayPlanModel>(_dayPlansBox);
  static Box get settingsBox => Hive.box(_settingsBox);
}
