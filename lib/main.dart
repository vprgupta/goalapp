import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/local/hive_service.dart';
import 'domain/services/notification_service.dart';
import 'domain/services/user_progress_service.dart';
import 'presentation/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    // Init local database
    await HiveService.init();
    // Init user progress (streak, XP, level)
    await UserProgressService.init();
  } catch (e) {
    debugPrint('FATAL: Database failed to initialize: $e');
  }

  // Init notifications
  await NotificationService.instance.init();

  // Restore saved reminder on cold start
  final prefs = await SharedPreferences.getInstance();
  final reminderEnabled = prefs.getBool('study_reminder_enabled') ?? false;
  if (reminderEnabled) {
    final h = prefs.getInt('study_reminder_hour') ?? 9;
    final m = prefs.getInt('study_reminder_minute') ?? 0;
    await NotificationService.instance
        .scheduleDailyReminder(hour: h, minute: m);
  }

  runApp(const ProviderScope(child: GoalApp()));
}

class GoalApp extends ConsumerWidget {
  const GoalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'GoalApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
