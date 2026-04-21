package com.goalapp.goalapp

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TasksWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.tasks_widget).apply {
                val activeGoal = widgetData.getString("active_goal_name", "No Active Goal")
                setTextViewText(R.id.widget_goal, activeGoal)

                val tasksCount = widgetData.getInt("pending_tasks", 0)
                val taskText = if (tasksCount > 0) "$tasksCount tasks remaining today" else "You're all done for today!"
                setTextViewText(R.id.widget_count, taskText)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
