import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application name
  ///
  /// In en, this message translates to:
  /// **'GoalApp'**
  String get appName;

  /// Bottom nav label for roadmaps tab
  ///
  /// In en, this message translates to:
  /// **'Roadmaps'**
  String get tabRoadmaps;

  /// Bottom nav label for active goal tab
  ///
  /// In en, this message translates to:
  /// **'Active Goal'**
  String get tabActiveGoal;

  /// Section header for daily task list
  ///
  /// In en, this message translates to:
  /// **'Today\'s Tasks'**
  String get todaysTasks;

  /// Badge for learn-type tasks
  ///
  /// In en, this message translates to:
  /// **'LEARN'**
  String get taskTypeLearn;

  /// Badge for revision tasks
  ///
  /// In en, this message translates to:
  /// **'REVISE'**
  String get taskTypeRevise;

  /// FAB label on roadmap list
  ///
  /// In en, this message translates to:
  /// **'Design New Roadmap'**
  String get designNewRoadmap;

  /// Title shown on goal completion screen
  ///
  /// In en, this message translates to:
  /// **'Goal Complete!'**
  String get goalCompleteTitle;

  /// Button on goal complete screen
  ///
  /// In en, this message translates to:
  /// **'Start a New Goal'**
  String get startNewGoal;

  /// Button to open topic resource hub
  ///
  /// In en, this message translates to:
  /// **'Explore Learning Hub'**
  String get exploreHub;

  /// Button to trigger deep-dive blueprint
  ///
  /// In en, this message translates to:
  /// **'GENERATE ATOMIC BLUEPRINT'**
  String get generateBlueprint;

  /// Loading state for blueprint generation
  ///
  /// In en, this message translates to:
  /// **'BLUEPRINTING...'**
  String get blueprinting;

  /// Hint shown on revision tasks
  ///
  /// In en, this message translates to:
  /// **'Focus on Recall'**
  String get focusOnRecall;

  /// Section label for sub-topic chips
  ///
  /// In en, this message translates to:
  /// **'KEY CONCEPTS'**
  String get keyConcepts;

  /// Empty state title on roadmap list
  ///
  /// In en, this message translates to:
  /// **'Vault is Empty'**
  String get vaultEmpty;

  /// Empty state subtitle on roadmap list
  ///
  /// In en, this message translates to:
  /// **'Architect your first learning\nroadmap with AI intelligence.'**
  String get vaultEmptySubtitle;

  /// Delete confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Archive Roadmap?'**
  String get archiveRoadmap;

  /// Confirm delete button label
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteConfirm;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancel;

  /// Status tag on roadmap card
  ///
  /// In en, this message translates to:
  /// **'BLUEPRINT READY'**
  String get blueprintReady;

  /// Hint text for goal name input
  ///
  /// In en, this message translates to:
  /// **'e.g. Learn Java, Master SQL...'**
  String get enterGoalHint;

  /// Validation error when goal is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a learning goal'**
  String get goalValidatorEmpty;

  /// Validation error when goal is too short
  ///
  /// In en, this message translates to:
  /// **'Goal must be at least 3 characters'**
  String get goalValidatorTooShort;

  /// Home screen widget task count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tasks today} =1{1 task today} other{{count} tasks today}}'**
  String widgetTasksToday(num count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
