import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'dashboard_screen.dart';
import '../goal_list/goal_list_screen.dart';

class MainScreen extends StatefulWidget {
  /// 0 = Roadmap Vault, 1 = Active Sprint Dashboard
  final int initialTab;

  const MainScreen({super.key, this.initialTab = 1});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  final List<Widget> _screens = [
    const GoalListScreen(),   // Tab 0 — Roadmap Library Vault
    const DashboardScreen(),  // Tab 1 — Active Sprint
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
