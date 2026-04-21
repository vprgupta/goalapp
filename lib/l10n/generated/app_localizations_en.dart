// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'GoalApp';

  @override
  String get tabRoadmaps => 'Roadmaps';

  @override
  String get tabActiveGoal => 'Active Goal';

  @override
  String get todaysTasks => 'Today\'s Tasks';

  @override
  String get taskTypeLearn => 'LEARN';

  @override
  String get taskTypeRevise => 'REVISE';

  @override
  String get designNewRoadmap => 'Design New Roadmap';

  @override
  String get goalCompleteTitle => 'Goal Complete!';

  @override
  String get startNewGoal => 'Start a New Goal';

  @override
  String get exploreHub => 'Explore Learning Hub';

  @override
  String get generateBlueprint => 'GENERATE ATOMIC BLUEPRINT';

  @override
  String get blueprinting => 'BLUEPRINTING...';

  @override
  String get focusOnRecall => 'Focus on Recall';

  @override
  String get keyConcepts => 'KEY CONCEPTS';

  @override
  String get vaultEmpty => 'Vault is Empty';

  @override
  String get vaultEmptySubtitle =>
      'Architect your first learning\nroadmap with AI intelligence.';

  @override
  String get archiveRoadmap => 'Archive Roadmap?';

  @override
  String get deleteConfirm => 'DELETE';

  @override
  String get cancel => 'CANCEL';

  @override
  String get blueprintReady => 'BLUEPRINT READY';

  @override
  String get enterGoalHint => 'e.g. Learn Java, Master SQL...';

  @override
  String get goalValidatorEmpty => 'Please enter a learning goal';

  @override
  String get goalValidatorTooShort => 'Goal must be at least 3 characters';

  @override
  String widgetTasksToday(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tasks today',
      one: '1 task today',
      zero: 'No tasks today',
    );
    return '$_temp0';
  }
}
