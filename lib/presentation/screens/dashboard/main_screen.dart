import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'dashboard_screen.dart';
import '../goal_list/goal_list_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GoalListScreen(), // Will act as Roadmap Library
    const DashboardScreen(), // The Active Sprint Execution
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.borderCard,
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.backgroundDark,
          selectedItemColor: AppColors.accentAmber,
          unselectedItemColor: AppColors.textMuted,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_rounded),
              label: 'Roadmaps',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_rounded),
              label: 'Active Goal',
            ),
          ],
        ),
      ),
    );
  }
}
