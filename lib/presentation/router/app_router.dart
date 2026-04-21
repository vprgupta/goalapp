import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/onboarding/goal_setup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/roadmap_detail_screen.dart';
import '../screens/dashboard/main_screen.dart';
import '../screens/goal_list/goal_list_screen.dart';
import '../screens/task/recall_screen.dart';
import '../screens/stats/stats_screen.dart';
import '../screens/task/topic_resource_screen.dart';
import '../../data/models/task_model.dart';
import '../../data/local/hive_service.dart';
import '../../data/models/goal_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Safety check: ensure boxes are open before access
      if (!HiveService.isBoxOpen('goals') || !HiveService.isBoxOpen('settings')) {
        debugPrint('Router: Boxes not ready yet...');
        return null;
      }

      final goals = HiveService.goalsBox.values.toList();
      final hasGoals = goals.isNotEmpty;
      final selectedId = HiveService.settingsBox.get('selected_goal_id') as String?;
      final hasSelection = selectedId != null && HiveService.goalsBox.containsKey(selectedId);

      final loc = state.matchedLocation;

      // 1. If no goals exist at all, force /onboard
      if (!hasGoals) {
        if (loc == '/onboard') return null;
        return '/onboard';
      }

      // No forced redirects if goals exist, let the MainScreen handle the tabs
      return null;
    },
  routes: [
    GoRoute(
      path: '/onboard',
      builder: (ctx, state) => const GoalSetupScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (ctx, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/create',
      builder: (ctx, state) => const GoalSetupScreen(),
    ),
    GoRoute(
      path: '/roadmap/:roadmapId',
      builder: (ctx, state) {
        final id = state.pathParameters['roadmapId']!;
        return RoadmapDetailScreen(roadmapId: id);
      },
    ),
    GoRoute(
      path: '/recall',
      builder: (ctx, state) {
        final extra = state.extra;
        // Support both old-style (TaskModel directly) and new-style (map with task + subTopics)
        if (extra is Map) {
          final task = extra['task'] as TaskModel;
          final subTopics = (extra['subTopics'] as List?)?.cast<String>() ?? [];
          final revisionCount = (extra['revisionCount'] as int?) ?? 0;
          return RecallScreen(task: task, subTopics: subTopics, revisionCount: revisionCount);
        }
        // Fallback: plain TaskModel (backwards compat)
        return RecallScreen(task: extra as TaskModel);
      },
    ),
    GoRoute(
      path: '/stats',
      builder: (ctx, state) => const StatsScreen(),
    ),
    GoRoute(
      path: '/topic-resources/:topicId',
      builder: (ctx, state) {
        final topicId = state.pathParameters['topicId']!;
        return TopicResourceScreen(topicId: topicId);
      },
    ),
    GoRoute(
      path: '/complete',
      builder: (ctx, state) => const _GoalCompleteScreen(),
    ),
  ],
  );
});

class _GoalCompleteScreen extends StatelessWidget {
  const _GoalCompleteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFA726), Color(0xFFFF6B35)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFA726).withOpacity(0.4),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              const Text(
                'Goal Complete!',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You built real knowledge through consistent,\nscientifically-backed practice.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  color: Color(0xFF94A3B8),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Start a New Goal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
