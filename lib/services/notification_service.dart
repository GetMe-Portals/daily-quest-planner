import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/planner_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Debug mode flag - set to true to enable detailed logging
  static const bool DEBUG_MODE = true;
  
  // Track initialization status
  bool _isInitialized = false;
  bool _isInitializing = false;

  void _log(String message) {
    if (DEBUG_MODE) {
      print('🔔 [NotificationService] $message');
    }
  }

  Future<void> initialize() async {
    // Prevent multiple initialization attempts
    if (_isInitialized || _isInitializing) {
      _log('⚠️ NotificationService already initialized or initializing, skipping...');
      return;
    }
    
    _isInitializing = true;
    _log('🚀 Initializing NotificationService with awesome_notifications...');
    
    try {
      // Initialize timezone
      tz.initializeTimeZones();
      _log('✅ Timezone initialized');

      // Initialize awesome_notifications
      await AwesomeNotifications().initialize(
        null, // null for default app icon
        [
          NotificationChannel(
            channelKey: 'task_reminders',
            channelName: 'Task Reminders',
            channelDescription: 'Reminders for scheduled tasks',
            defaultColor: const Color(0xFF4A5A75), // App's primary color
            ledColor: Colors.white,
            importance: NotificationImportance.High,
            channelShowBadge: true,
            enableVibration: true,
            enableLights: true,
            playSound: true,
            // Removed problematic soundSource reference
          ),
        ],
        debug: DEBUG_MODE,
      );
      _log('✅ AwesomeNotifications initialized');

      // Set up notification action listeners
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: _onNotificationAction,
        onNotificationCreatedMethod: _onNotificationCreated,
      );
      _log('✅ Notification listeners set up');

      _isInitialized = true;
      _log('✅ NotificationService initialized successfully');
    } catch (e, stackTrace) {
      _log('❌ Error initializing NotificationService: $e');
      _log('❌ Stack trace: $stackTrace');
      // Don't rethrow - let the app continue without notifications
      print('🔔 [NotificationService] Initialization failed, but app will continue: $e');
    } finally {
      _isInitializing = false;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationAction(ReceivedAction receivedAction) async {
    print('🔔 [NotificationService] 👆 Notification action received: ${receivedAction.buttonKeyPressed}');
    print('🔔 [NotificationService] 👆 Notification payload: ${receivedAction.payload}');
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreated(ReceivedNotification receivedNotification) async {
    print('🔔 [NotificationService] 📱 Notification created: ${receivedNotification.title}');
  }

  Future<void> scheduleReminder(PlannerItem item) async {
    _log('📅 === SCHEDULING REMINDER ===');
    _log('📋 Item: "${item.name}"');
    _log('📋 Item ID: ${item.id}');
    _log('📋 Reminder enabled: ${item.reminder}');
    _log('📋 Start time: ${item.startTime}');
    _log('📋 Date: ${item.date}');
    _log('📋 Reminder offset: ${item.reminderOffset} minutes');

    try {
      if (item.reminder != true) {
        _log('❌ Reminder is disabled for this item');
        return;
      }

      if (item.startTime == null) {
        _log('❌ No start time set for this item');
        return;
      }

      // Check permissions first
      final isAllowed = await _checkAndRequestPermissions();
      if (!isAllowed) {
        _log('❌ Notification permissions not granted');
        return;
      }

      final notificationId = item.hashCode;
      final title = 'Task Reminder';
      final body = '${item.name} starts in ${_getReminderOffsetText(item.reminderOffset)}';
      
      _log('📋 Notification ID: $notificationId');
      _log('📋 Notification title: "$title"');
      _log('📋 Notification body: "$body"');
      
      // Calculate reminder time
      final reminderTime = _calculateReminderTime(item);
      final now = DateTime.now();
      
      _log('📋 Current time: ${now.toString()}');
      _log('📋 Calculated reminder time: ${reminderTime.toString()}');
      _log('📋 Time difference: ${reminderTime.difference(now).inMinutes} minutes');
      
      if (reminderTime.isBefore(now)) {
        _log('❌ Reminder time is in the past - skipping');
        return;
      }

      // Schedule the notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'task_reminders',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          payload: {
            'item_id': item.id,
            'item_name': item.name,
            'item_type': item.type,
          },
        ),
        schedule: NotificationCalendar.fromDate(
          date: reminderTime,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      _log('✅ Successfully scheduled reminder for "${item.name}"');
      _log('✅ Reminder will trigger at: ${reminderTime.toString()}');
      
      // Log pending notifications for verification
      await _logPendingNotifications();
      
    } catch (e) {
      _log('❌ Failed to schedule reminder for "${item.name}": $e');
      
      // Try fallback scheduling without precise alarm
      try {
        _log('🔄 Trying fallback scheduling without precise alarm...');
        
        final reminderTime = _calculateReminderTime(item);
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: item.hashCode,
            channelKey: 'task_reminders',
            title: 'Task Reminder',
            body: '${item.name} starts in ${_getReminderOffsetText(item.reminderOffset)}',
            notificationLayout: NotificationLayout.Default,
            payload: {
              'item_id': item.id,
              'item_name': item.name,
              'item_type': item.type,
            },
          ),
          schedule: NotificationCalendar.fromDate(
            date: reminderTime,
            allowWhileIdle: true,
            preciseAlarm: false,
          ),
        );
        
        _log('✅ Scheduled fallback reminder for "${item.name}"');
        _log('✅ Fallback reminder will trigger around: ${reminderTime.toString()}');
        
      } catch (fallbackError) {
        _log('❌ Failed to schedule fallback reminder for "${item.name}": $fallbackError');
      }
    }
  }

  Future<void> cancelReminder(PlannerItem item) async {
    final notificationId = item.hashCode;
    _log('🗑️ Cancelling reminder for "${item.name}" (ID: $notificationId)');
    
    try {
      await AwesomeNotifications().cancel(notificationId);
      _log('✅ Successfully cancelled reminder for "${item.name}"');
    } catch (e) {
      _log('❌ Error cancelling reminder for "${item.name}": $e');
    }
  }

  Future<void> cancelAllReminders() async {
    _log('🗑️ Cancelling all reminders...');
    try {
      await AwesomeNotifications().cancelAll();
      _log('✅ Successfully cancelled all reminders');
    } catch (e) {
      _log('❌ Error cancelling all reminders: $e');
    }
  }

  DateTime _calculateReminderTime(PlannerItem item) {
    final taskDateTime = DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      item.startTime!.hour,
      item.startTime!.minute,
    );

    final reminderOffset = item.reminderOffset ?? 15; // Default 15 minutes
    final reminderTime = taskDateTime.subtract(Duration(minutes: reminderOffset));
    
    _log('📅 Task "${item.name}" scheduled for: ${taskDateTime.toString()}');
    _log('📅 Reminder offset: $reminderOffset minutes');
    _log('📅 Reminder will trigger at: ${reminderTime.toString()}');
    
    return reminderTime;
  }

  String _getReminderOffsetText(int? offset) {
    final minutes = offset ?? 15;
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes == 60) {
      return '1 hour';
    } else {
      final hours = minutes ~/ 60;
      return '$hours hours';
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    _log('🔐 === CHECKING AND REQUESTING PERMISSIONS ===');
    
    try {
      // Check if notifications are allowed
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      _log('📱 Notifications allowed: $isAllowed');
      
      if (!isAllowed) {
        _log('🔐 Requesting notification permissions...');
        final granted = await AwesomeNotifications().requestPermissionToSendNotifications();
        _log('📱 Permission granted: $granted');
        return granted;
      }
      
      return true;
    } catch (e) {
      _log('❌ Error checking/requesting permissions: $e');
      return false;
    }
  }

  Future<void> requestPermissions() async {
    _log('🔐 === REQUESTING PERMISSIONS ===');
    
    try {
      final granted = await AwesomeNotifications().requestPermissionToSendNotifications();
      _log('📱 Notification permission granted: $granted');
      
      if (granted) {
        _log('✅ Permissions requested successfully');
      } else {
        _log('⚠️ Permission denied - reminders may not work!');
      }
    } catch (e) {
      _log('❌ Error requesting permissions: $e');
    }
  }

  Future<void> _logPendingNotifications() async {
    _log('📋 === PENDING NOTIFICATIONS ===');
    try {
      final pending = await AwesomeNotifications().listScheduledNotifications();
      _log('📋 Total pending notifications: ${pending.length}');
      
      for (final notification in pending) {
        _log('📋 Pending - ID: ${notification.content?.id}, Title: "${notification.content?.title}"');
        if (notification.schedule is NotificationCalendar) {
          _log('📋 Scheduled notification found');
        }
      }
      
      if (pending.isEmpty) {
        _log('⚠️ No pending notifications found');
      }
    } catch (e) {
      _log('❌ Error getting pending notifications: $e');
    }
  }

  Future<List<NotificationModel>> getPendingNotifications() async {
    _log('📋 Getting pending notifications...');
    try {
      final pending = await AwesomeNotifications().listScheduledNotifications();
      _log('📋 Found ${pending.length} pending notifications');
      for (final notification in pending) {
        _log('📋 Pending - ID: ${notification.content?.id}, Title: ${notification.content?.title}');
      }
      return pending;
    } catch (e) {
      _log('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  // Enhanced test method with detailed logging
  Future<void> testNotification() async {
    _log('🧪 === TESTING NOTIFICATION SYSTEM ===');
    
    try {
      // Check permissions first
      final isAllowed = await _checkAndRequestPermissions();
      if (!isAllowed) {
        _log('❌ Cannot test notification - permissions not granted');
        return;
      }

      final testTime = DateTime.now().add(const Duration(seconds: 10));
      _log('🧪 Scheduling test notification for: ${testTime.toString()}');
      
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999999,
          channelKey: 'task_reminders',
          title: 'Test Reminder',
          body: 'This is a test notification - if you see this, notifications are working!',
          notificationLayout: NotificationLayout.Default,
          payload: {
            'test': 'true',
            'timestamp': DateTime.now().toString(),
          },
        ),
        schedule: NotificationCalendar.fromDate(
          date: testTime,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );
      
      _log('✅ Test notification scheduled successfully');
      _log('✅ Test notification will appear in 10 seconds');
      
      // Log pending notifications to verify
      await _logPendingNotifications();
      
    } catch (e) {
      _log('❌ Test notification failed: $e');
      
      // Try fallback test notification
      try {
        _log('🔄 Trying fallback test notification...');
        
        final testTime = DateTime.now().add(const Duration(seconds: 10));
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 999998,
            channelKey: 'task_reminders',
            title: 'Test Reminder (Fallback)',
            body: 'This is a fallback test notification',
            notificationLayout: NotificationLayout.Default,
            payload: {
              'test': 'fallback',
              'timestamp': DateTime.now().toString(),
            },
          ),
          schedule: NotificationCalendar.fromDate(
            date: testTime,
            allowWhileIdle: true,
            preciseAlarm: false,
          ),
        );
        
        _log('✅ Fallback test notification scheduled successfully');
        _log('✅ Fallback test notification will appear in ~10 seconds');
        
        // Log pending notifications to verify
        await _logPendingNotifications();
        
      } catch (fallbackError) {
        _log('❌ Fallback test notification failed: $fallbackError');
      }
    }
  }

  // New method to diagnose reminder issues
  Future<void> diagnoseReminderIssues() async {
    _log('🔍 === REMINDER DIAGNOSIS ===');
    
    try {
      // Check permissions
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      _log('📱 Notifications allowed: $isAllowed');
      
      // Check pending notifications
      await _logPendingNotifications();
      
      // Check notification channels
      _log('📱 Checking notification channels...');
      _log('📱 Channel: task_reminders - Task Reminders - High importance');
      
      _log('🔍 Diagnosis complete');
    } catch (e) {
      _log('❌ Error during diagnosis: $e');
    }
  }

  // Dispose method for cleanup
  void dispose() {
    _log('🧹 Disposing NotificationService...');
    try {
      // Remove listeners by setting them to empty functions
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: (ReceivedAction action) async {},
        onNotificationCreatedMethod: (ReceivedNotification notification) async {},
      );
      _log('✅ NotificationService disposed successfully');
    } catch (e) {
      _log('❌ Error disposing NotificationService: $e');
    }
  }
} 