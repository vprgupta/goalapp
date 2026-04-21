import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String appGroupId = 'group.com.goalapp.app'; // Optional for Android, mandatory for iOS
  static const String androidWidgetName = 'TasksWidgetProvider';
  static const String iosWidgetName = 'TasksWidget';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  static Future<void> updateTasksWidget({
    required int pendingTasksCount,
    required String goalName,
  }) async {
    // Save data for the native side to pick up
    await HomeWidget.saveWidgetData<int>('pending_tasks', pendingTasksCount);
    await HomeWidget.saveWidgetData<String>('active_goal_name', goalName);
    
    // Trigger the update
    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      iOSName: iosWidgetName,
    );
  }
}
