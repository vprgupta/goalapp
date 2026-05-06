import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// UserProgressService — persists streak, XP, and level without touching GoalModel.
/// Uses a dedicated Hive box so no adapter regeneration is needed.
class UserProgressService {
  static const _boxName = 'user_progress';
  static const _streakKey = 'current_streak';
  static const _longestStreakKey = 'longest_streak';
  static const _lastActivityKey = 'last_activity_date';
  static const _totalXpKey = 'total_xp';
  static const _levelKey = 'level';

  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    assert(_box != null, 'Call UserProgressService.init() first');
    return _box!;
  }

  // ── Streak ────────────────────────────────────────────────────────────────

  static int get currentStreak => _b.get(_streakKey, defaultValue: 0) as int;
  static int get longestStreak => _b.get(_longestStreakKey, defaultValue: 0) as int;
  static DateTime? get lastActivityDate {
    final stored = _b.get(_lastActivityKey) as String?;
    return stored != null ? DateTime.tryParse(stored) : null;
  }

  /// Call this every time a task is completed.
  /// Returns the new streak count.
  static Future<int> recordActivity() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = lastActivityDate;

    int streak = currentStreak;

    if (lastDate == null) {
      // First ever activity
      streak = 1;
    } else {
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 0) {
        // Same day — streak unchanged
      } else if (diff == 1) {
        // Consecutive day — increment streak
        streak += 1;
      } else {
        // Missed days — reset streak
        streak = 1;
      }
    }

    await _b.put(_streakKey, streak);
    await _b.put(_lastActivityKey, now.toIso8601String());

    // Update longest streak
    if (streak > longestStreak) {
      await _b.put(_longestStreakKey, streak);
    }

    return streak;
  }

  /// Returns true if a streak was active but broken (missed yesterday).
  static bool get isStreakBroken {
    final lastDate = lastActivityDate;
    if (lastDate == null || currentStreak == 0) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
    return today.difference(lastDay).inDays > 1;
  }

  // ── XP & Level ────────────────────────────────────────────────────────────

  static int get totalXp => _b.get(_totalXpKey, defaultValue: 0) as int;
  static int get level => _b.get(_levelKey, defaultValue: 1) as int;

  /// XP required to reach next level (progressive: each level needs 100 more XP)
  static int xpForNextLevel(int currentLevel) => currentLevel * 100;

  /// XP within the current level (0 → xpForNextLevel)
  static int get xpInCurrentLevel {
    int xp = totalXp;
    int lvl = 1;
    while (xp >= xpForNextLevel(lvl)) {
      xp -= xpForNextLevel(lvl);
      lvl++;
    }
    return xp;
  }

  static double get levelProgress {
    final needed = xpForNextLevel(level);
    return (xpInCurrentLevel / needed).clamp(0.0, 1.0);
  }

  static String get levelTitle {
    final lvl = level;
    if (lvl <= 2) return 'Newcomer';
    if (lvl <= 5) return 'Apprentice';
    if (lvl <= 10) return 'Scholar';
    if (lvl <= 20) return 'Expert';
    if (lvl <= 35) return 'Master';
    return 'Legend';
  }

  /// Awards XP and updates level. Returns (newTotalXp, didLevelUp, newLevel).
  static Future<({int xp, bool leveledUp, int newLevel})> awardXp(int amount) async {
    final oldLevel = level;
    final newTotal = totalXp + amount;
    await _b.put(_totalXpKey, newTotal);

    // Recalculate level
    int xp = newTotal;
    int lvl = 1;
    while (xp >= xpForNextLevel(lvl)) {
      xp -= xpForNextLevel(lvl);
      lvl++;
    }
    await _b.put(_levelKey, lvl);

    return (xp: newTotal, leveledUp: lvl > oldLevel, newLevel: lvl);
  }

  /// XP amounts for different actions
  static const int xpLearnTopic = 10;
  static const int xpReviseTopic = 5;
  static const int xpCorrectMcq = 3;
  static const int xpBossTopic = 25;
  static const int xpPerfectDay = 15; // All tasks done in a day

  // ── Catch-Up Detection ────────────────────────────────────────────────────

  /// Checks if the user has incomplete tasks from past days.
  /// [goalCurrentDay] is `GoalModel.currentDay` — passed in by the caller.
  static bool hasPendingCatchUp(List<dynamic> allDayPlans, {required int goalCurrentDay}) {
    for (final plan in allDayPlans) {
      try {
        if (!(plan.isCompleted as bool) && (plan.dayNumber as int) < goalCurrentDay) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
