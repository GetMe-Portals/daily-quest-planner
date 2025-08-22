package com.example.daily_quest_planner

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.content.Intent
import android.app.PendingIntent
import android.net.Uri

class HomeWidgetBroadcastReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

        private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            android.util.Log.d("WidgetProvider", "Starting widget update for ID: $appWidgetId")
            val views = RemoteViews(context.packageName, R.layout.home_widget)
            
                    // Create intent to open the app when widget is clicked
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            
            // Update widget with current data
            updateWidgetContent(context, views)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            android.util.Log.d("WidgetProvider", "Widget updated successfully for ID: $appWidgetId")
        } catch (e: Exception) {
            android.util.Log.e("WidgetProvider", "Error updating widget: ${e.message}")
            e.printStackTrace()
            // If there's an error, create a simple fallback widget
            val fallbackViews = RemoteViews(context.packageName, android.R.layout.simple_list_item_1)
            fallbackViews.setTextViewText(android.R.id.text1, "Daily Quest Planner")
            appWidgetManager.updateAppWidget(appWidgetId, fallbackViews)
        }
    }

    private fun updateWidgetContent(context: Context, views: RemoteViews) {
        try {
            // Read widget data from SharedPreferences
            val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val widgetData = sharedPrefs.getString("flutter.widget_data", null)
            
            android.util.Log.d("WidgetProvider", "Raw widget data: $widgetData")
            
            if (widgetData != null && widgetData != "null") {
                android.util.Log.d("WidgetProvider", "Found widget data: $widgetData")
                
                // Parse the widget data
                val items = parseWidgetData(widgetData)
                
                android.util.Log.d("WidgetProvider", "Parsed ${items.size} items")
                
                if (items.isNotEmpty()) {
                    // Update the widget with real data
                    views.setTextViewText(R.id.widget_title, "UP NEXT TODAY")
                    
                    // Show up to 3 items
                    for (i in 0 until minOf(3, items.size)) {
                        val item = items[i]
                        android.util.Log.d("WidgetProvider", "Setting item $i: ${item.text}")
                        when (i) {
                            0 -> views.setTextViewText(R.id.task_1, item.text)
                            1 -> views.setTextViewText(R.id.task_2, item.text)
                            2 -> views.setTextViewText(R.id.task_3, item.text)
                        }
                    }
                    
                    // Hide remaining items if less than 3
                    if (items.size < 3) {
                        if (items.size < 2) views.setTextViewText(R.id.task_2, "")
                        if (items.size < 3) views.setTextViewText(R.id.task_3, "")
                    }
                } else {
                    // Show empty state
                    android.util.Log.d("WidgetProvider", "No items found, showing empty state")
                    views.setTextViewText(R.id.widget_title, "UP NEXT TODAY")
                    views.setTextViewText(R.id.task_1, "No tasks for today")
                    views.setTextViewText(R.id.task_2, "")
                    views.setTextViewText(R.id.task_3, "")
                }
            } else {
                // Show empty state if no data
                android.util.Log.d("WidgetProvider", "No widget data found, showing empty state")
                views.setTextViewText(R.id.widget_title, "UP NEXT TODAY")
                views.setTextViewText(R.id.task_1, "No tasks for today")
                views.setTextViewText(R.id.task_2, "")
                views.setTextViewText(R.id.task_3, "")
            }
        } catch (e: Exception) {
            // Log the error but don't crash the widget
            android.util.Log.e("WidgetProvider", "Error updating widget content: ${e.message}")
            e.printStackTrace()
            // Show fallback content
            views.setTextViewText(R.id.widget_title, "UP NEXT TODAY")
            views.setTextViewText(R.id.task_1, "10:00 Meeting with Mark")
            views.setTextViewText(R.id.task_2, "Email meeting notes to Anna")
            views.setTextViewText(R.id.task_3, "11:45 Lunch with Anna")
        }
    }
    
    private fun parseWidgetData(data: String): List<WidgetItem> {
        val items = mutableListOf<WidgetItem>()
        try {
            android.util.Log.d("WidgetProvider", "Parsing widget data: $data")
            
            // Parse the Flutter data format
            // Data format: [{text: "10:00 Meeting with Mark", isTask: false, done: false}, ...]
            val cleanData = data.trim()
            if (cleanData.startsWith("[") && cleanData.endsWith("]")) {
                val content = cleanData.substring(1, cleanData.length - 1)
                
                // Split by "}, {" to get individual items
                val itemStrings = if (content.contains("}, {")) {
                    content.split("}, {")
                } else if (content.isNotEmpty()) {
                    listOf(content)
                } else {
                    emptyList()
                }
                
                android.util.Log.d("WidgetProvider", "Found ${itemStrings.size} item strings")
                
                for (itemString in itemStrings) {
                    val cleanItem = itemString.replace("{", "").replace("}", "")
                    val parts = cleanItem.split(", ")
                    
                    var text = ""
                    var isTask = false
                    
                    for (part in parts) {
                        if (part.startsWith("text: ")) {
                            text = part.substring(6).trim('"')
                        } else if (part.startsWith("isTask: ")) {
                            isTask = part.substring(8).toBoolean()
                        }
                    }
                    
                    if (text.isNotEmpty()) {
                        items.add(WidgetItem(text, isTask))
                        android.util.Log.d("WidgetProvider", "Added item: $text")
                    }
                }
            } else {
                android.util.Log.w("WidgetProvider", "Invalid data format: $data")
            }
            
            android.util.Log.d("WidgetProvider", "Successfully parsed ${items.size} items")
        } catch (e: Exception) {
            android.util.Log.e("WidgetProvider", "Error parsing widget data: ${e.message}")
            e.printStackTrace()
        }
        return items
    }
    
    data class WidgetItem(val text: String, val isTask: Boolean)

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Handle custom actions from Flutter
        when (intent.action) {
            "UPDATE_WIDGET" -> {
                val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (appWidgetIds != null) {
                    onUpdate(context, AppWidgetManager.getInstance(context), appWidgetIds)
                }
            }
        }
    }
} 