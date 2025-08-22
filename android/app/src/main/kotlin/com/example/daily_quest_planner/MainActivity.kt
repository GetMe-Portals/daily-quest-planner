package com.example.daily_quest_planner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.ComponentName

class MainActivity: FlutterActivity() {
    private val CHANNEL = "widget_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    try {
                        // Trigger widget update
                        val intent = Intent(this, HomeWidgetBroadcastReceiver::class.java)
                        intent.action = "UPDATE_WIDGET"
                        
                        // Get all widget IDs
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        val appWidgetIds = appWidgetManager.getAppWidgetIds(
                            ComponentName(this, HomeWidgetBroadcastReceiver::class.java)
                        )
                        
                        if (appWidgetIds.isNotEmpty()) {
                            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                            sendBroadcast(intent)
                            android.util.Log.d("MainActivity", "Widget update triggered for ${appWidgetIds.size} widgets")
                            result.success("Widget update triggered")
                        } else {
                            android.util.Log.d("MainActivity", "No widgets found to update")
                            result.success("No widgets to update")
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error triggering widget update: ${e.message}")
                        result.error("WIDGET_UPDATE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
