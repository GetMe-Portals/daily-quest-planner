import 'package:shared_preferences/shared_preferences.dart';
import '../models/planner_item.dart';
import 'package:flutter/material.dart';

class WidgetService {
  static const String _appWidgetId = 'home_widget';
  static const String _upNextKey = 'up_next_items';
  static const String _todayKey = 'today_items';

  /// Initialize the widget service
  static Future<void> initialize() async {
    try {
      // Widget initialization will be handled by the Android broadcast receiver
      print('Widget service initialized');
    } catch (e) {
      print('Failed to initialize widget service: $e');
    }
  }

  /// Update the home widget with current planner data
  static Future<void> updateWidget(List<PlannerItem> items) async {
    try {
      print('WidgetService: Updating widget with ${items.length} total items');
      
      // Get today's items
      final today = DateTime.now();
      print('WidgetService: Today is ${today.year}-${today.month}-${today.day}');
      
      final todayItems = items.where((item) {
        final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
        final todayDate = DateTime(today.year, today.month, today.day);
        final isToday = itemDate.isAtSameMomentAs(todayDate);
        print('WidgetService: Item "${item.name}" date: ${item.date.year}-${item.date.month}-${item.date.day}, isToday: $isToday');
        return isToday;
      }).toList();

      print('WidgetService: Found ${todayItems.length} items for today');

      // Sort items by time
      todayItems.sort((a, b) {
        final aTime = a.startTime ?? const TimeOfDay(hour: 23, minute: 59);
        final bTime = b.startTime ?? const TimeOfDay(hour: 23, minute: 59);
        return (aTime.hour * 60 + aTime.minute).compareTo(bTime.hour * 60 + bTime.minute);
      });

      // Create a simple format for the Android widget
      final widgetItems = todayItems.take(3).map((item) => {
        'text': item.startTime != null 
          ? '${item.startTime!.hour.toString().padLeft(2, '0')}:${item.startTime!.minute.toString().padLeft(2, '0')} ${item.name}'
          : item.name,
        'isTask': item.type == 'task',
        'done': item.done,
      }).toList();
      
      print('WidgetService: Widget items: $widgetItems');
      
      // Save data to shared preferences for widget access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_data', widgetItems.toString());
      
      print('WidgetService: Saved widget data to SharedPreferences');

      print('Widget updated successfully with ${widgetItems.length} items');
    } catch (e) {
      print('Failed to update widget: $e');
    }
  }

  /// Get the current widget data
  static Future<Map<String, dynamic>?> getWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('widget_data');
      if (data != null) {
        // Simple parsing - in a real app, you'd use proper JSON
        return {'data': data};
      }
      return null;
    } catch (e) {
      print('Failed to get widget data: $e');
      return null;
    }
  }

  /// Handle widget tap to open the app
  static Future<void> handleWidgetTap() async {
    try {
      // The widget tap is handled by the Android broadcast receiver
      // which launches the app directly
    } catch (e) {
      print('Failed to launch app from widget: $e');
    }
  }

  /// Force update the widget with current data
  static Future<void> forceUpdateWidget(List<PlannerItem> items) async {
    try {
      print('WidgetService: Force updating widget...');
      await updateWidget(items);
      
      // Also trigger Android widget update
      final prefs = await SharedPreferences.getInstance();
      final widgetData = prefs.getString('widget_data');
      print('WidgetService: Current widget data: $widgetData');
    } catch (e) {
      print('Failed to force update widget: $e');
    }
  }

  /// Serialize items for storage
  static String _serializeItems(List<PlannerItem> items) {
    return items.map((item) => {
      'name': item.name,
      'type': item.type,
      'time': item.startTime != null ? '${item.startTime!.hour.toString().padLeft(2, '0')}:${item.startTime!.minute.toString().padLeft(2, '0')}' : null,
      'done': item.done,
    }).toString();
  }

  /// Deserialize items from storage
  static List<Map<String, dynamic>> _deserializeItems(String data) {
    try {
      // Simple deserialization - in a real app, you'd use proper JSON
      return [];
    } catch (e) {
      return [];
    }
  }
} 