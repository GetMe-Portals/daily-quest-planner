import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/date_card.dart';
import '../widgets/mood_row.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_calendar_card.dart';
import '../models/planner_item.dart';
import '../widgets/sun_checkbox.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:async';

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme.dart' show CustomMaterialColor;
import '../services/widget_service.dart';
import '../services/notification_service.dart';
import '../services/emoji_service.dart';
import '../widgets/dashboard_view.dart';
import '../widgets/emoji_suggestions.dart';
import '../widgets/weekly_view.dart';
import '../widgets/donut_chart.dart';
import '../widgets/task_row_widget.dart';

/// The main home screen for the Daily Quest Planner app.
/// Uses a responsive layout for mobile and tablet.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<PlannerItem> _plannerItems = [];

  String _selectedTimeRange = 'today'; // 'today', 'weekly', 'monthly', 'yearly', 'custom'
  bool _showViewMenu = false;
  GlobalKey<AnimatedListState> _incompleteListKey = GlobalKey<AnimatedListState>();
  GlobalKey<AnimatedListState> _completedListKey = GlobalKey<AnimatedListState>();
  String? _flashKey;

  Map<String, String> _moodsByDate = {};
  Map<String, DateTime> _completionTimestamps = {}; // Track when each date was completed
  Set<String> _confettiShownDates = {}; // Track dates where confetti has been shown
  late ConfettiController _confettiController;
  bool _showCompletionMessage = false;
  double _lastProgress = 0.0;
  Set<String> _expandedDays = {}; // Track which days are expanded
  bool _isNoteExpanded = false; // Track if note is expanded
  String _noteText = ''; // Store the note text
  late TextEditingController _noteController; // Persistent controller for note text field
  bool _showImportantOnly = false; // NEW: filter for important tasks only
  DateTime? _expandedDate; // Track which date should be expanded in weekly view
  bool _isFirstWeeklyEntry = true; // Track if this is the first time entering weekly view
  
  // Separate expansion states for each day box
  bool _isMondayExpanded = false;
  bool _isTuesdayExpanded = false;
  bool _isWednesdayExpanded = false;
  bool _isThursdayExpanded = false;
  bool _isFridayExpanded = false;
  bool _isSaturdayExpanded = false;
  bool _isSundayExpanded = false;
  
  void _saveNote() {
    // Here you can add logic to save the note to persistent storage
    // For now, we'll just close the expanded state
    setState(() {
      _noteText = _noteController.text;
      _isNoteExpanded = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPlannerItems();
    _loadMoods();
    _loadCompletionTimestamps();
    _loadConfettiFlags();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPlannerItems() async {
    final items = await PlannerStorage.load();
    setState(() {
      _plannerItems = items;
    });
    
    // Update the home widget with current data
    await WidgetService.updateWidget(items);
    
    // Schedule reminders for existing items
    await _scheduleExistingReminders(items);
  }

  // Debug method to manually refresh widget
  Future<void> _refreshWidget() async {
    try {
      print('🔄 [HomeScreen] Manual widget refresh requested');
      await WidgetService.refreshWidget();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Widget refresh triggered'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('🔄 [HomeScreen] Failed to refresh widget: $e');
    }
  }
  
  Future<void> _scheduleExistingReminders(List<PlannerItem> items) async {
    print('🔔 [HomeScreen] === SCHEDULING EXISTING REMINDERS ===');
    print('🔔 [HomeScreen] Total items to check: ${items.length}');
    
    final now = DateTime.now();
    int scheduledCount = 0;
    int skippedCount = 0;
    
    for (final item in items) {
      print('🔔 [HomeScreen] Checking item: "${item.name}"');
      print('🔔 [HomeScreen] - Reminder enabled: ${item.reminder}');
      print('🔔 [HomeScreen] - Start time: ${item.startTime}');
      print('🔔 [HomeScreen] - Date: ${item.date}');
      
      if (item.reminder == true && item.startTime != null) {
        // Only schedule reminders for future tasks
        final taskDateTime = DateTime(
          item.date.year,
          item.date.month,
          item.date.day,
          item.startTime!.hour,
          item.startTime!.minute,
        );
        
        print('🔔 [HomeScreen] - Task datetime: ${taskDateTime.toString()}');
        print('🔔 [HomeScreen] - Current time: ${now.toString()}');
        print('🔔 [HomeScreen] - Is future: ${taskDateTime.isAfter(now)}');
        
        if (taskDateTime.isAfter(now)) {
          print('🔔 [HomeScreen] ✅ Scheduling reminder for "${item.name}"');
          await NotificationService().scheduleReminder(item);
          scheduledCount++;
        } else {
          print('🔔 [HomeScreen] ⏰ Skipping past task "${item.name}"');
          skippedCount++;
        }
      } else {
        print('🔔 [HomeScreen] ⏭️ Skipping item "${item.name}" - no reminder or start time');
        skippedCount++;
      }
    }
    
    print('🔔 [HomeScreen] === SCHEDULING COMPLETE ===');
    print('🔔 [HomeScreen] Scheduled: $scheduledCount, Skipped: $skippedCount');
  }

  void _showContextAwareAddForm({DateTime? selectedDate}) {
    // Since we only have routines now, always set to routine type
    int initialType = 1; // Routine

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add Item',
      barrierColor: themeProvider.overlayColor,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 32.0),
            child: AddPlannerItemForm(
              initialDate: selectedDate ?? _selectedDate,
              initialType: initialType, // Pass the context-aware initial type
              existingItems: _plannerItems, // Pass existing items for duplicate validation
              onSave: (item) async {
                print('🔔 [HomeScreen] === CREATING NEW ITEM ===');
                print('🔔 [HomeScreen] Item: "${item.name}"');
                print('🔔 [HomeScreen] - Reminder enabled: ${item.reminder}');
                print('🔔 [HomeScreen] - Start time: ${item.startTime}');
                print('🔔 [HomeScreen] - Date: ${item.date}');
                print('🔔 [HomeScreen] - Reminder offset: ${item.reminderOffset} minutes');
                
                // Add item to the list
                final updatedItems = List<PlannerItem>.from(_plannerItems);
                updatedItems.add(item);
                
                // Reset confetti flag for this date since a new plan was added
                final dateKey = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
                _confettiShownDates.remove(dateKey);
                _saveConfettiFlags();
                
                // Save to storage
                await PlannerStorage.save(updatedItems);
                
                // Update UI
                setState(() {
                  _plannerItems = updatedItems;
                });
                
                // Update home widget
                await WidgetService.updateWidget(updatedItems);
                
                // Schedule reminder if enabled
                if (item.reminder == true && item.startTime != null) {
                  print('🔔 [HomeScreen] ✅ Scheduling reminder for new item "${item.name}"');
                  await NotificationService().scheduleReminder(item);
                } else {
                  print('🔔 [HomeScreen] ⏭️ No reminder scheduled - reminder: ${item.reminder}, startTime: ${item.startTime}');
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Plan added!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: themeProvider.successColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.2),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }





  Future<void> _loadMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final moodsJson = prefs.getString('moods_by_date');
    if (moodsJson != null) {
      final map = Map<String, dynamic>.from(jsonDecode(moodsJson));
      setState(() {
        _moodsByDate = map.map((k, v) => MapEntry(k, v.toString()));
      });
    }
  }

  // Debug method to diagnose reminder issues
  Future<void> _diagnoseReminderIssues() async {
    print('🔔 [HomeScreen] === REMINDER DIAGNOSIS STARTED ===');
    print('🔔 [HomeScreen] Current time: ${DateTime.now().toString()}');
    print('🔔 [HomeScreen] Total planner items: ${_plannerItems.length}');
    
    // Count items with reminders
    final itemsWithReminders = _plannerItems.where((item) => item.reminder == true).length;
    final itemsWithStartTime = _plannerItems.where((item) => item.startTime != null).length;
    final itemsWithBoth = _plannerItems.where((item) => item.reminder == true && item.startTime != null).length;
    
    print('🔔 [HomeScreen] Items with reminders: $itemsWithReminders');
    print('🔔 [HomeScreen] Items with start time: $itemsWithStartTime');
    print('🔔 [HomeScreen] Items with both: $itemsWithBoth');
    
    // List all items with reminders
    print('🔔 [HomeScreen] === ITEMS WITH REMINDERS ===');
    for (final item in _plannerItems) {
      if (item.reminder == true) {
        print('🔔 [HomeScreen] - "${item.name}" (ID: ${item.id})');
        print('🔔 [HomeScreen]   Start time: ${item.startTime}');
        print('🔔 [HomeScreen]   Date: ${item.date}');
        print('🔔 [HomeScreen]   Reminder offset: ${item.reminderOffset} minutes');
        
        if (item.startTime != null) {
          final taskDateTime = DateTime(
            item.date.year,
            item.date.month,
            item.date.day,
            item.startTime!.hour,
            item.startTime!.minute,
          );
          final reminderTime = taskDateTime.subtract(Duration(minutes: item.reminderOffset ?? 15));
          final now = DateTime.now();
          
          print('🔔 [HomeScreen]   Task datetime: ${taskDateTime.toString()}');
          print('🔔 [HomeScreen]   Reminder time: ${reminderTime.toString()}');
          print('🔔 [HomeScreen]   Is reminder in future: ${reminderTime.isAfter(now)}');
          print('🔔 [HomeScreen]   Minutes until reminder: ${reminderTime.difference(now).inMinutes}');
        }
      }
    }
    
    // Run notification service diagnosis
    await NotificationService().diagnoseReminderIssues();
    
    print('🔔 [HomeScreen] === REMINDER DIAGNOSIS COMPLETE ===');
  }

  Future<void> _saveMoods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moods_by_date', jsonEncode(_moodsByDate));
  }

  Future<void> _saveCompletionTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampsMap = _completionTimestamps.map((key, value) => MapEntry(key, value.toIso8601String()));
    await prefs.setString('completion_timestamps', jsonEncode(timestampsMap));
  }

  Future<void> _loadCompletionTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('completion_timestamps');
    if (data != null) {
      final timestampsMap = jsonDecode(data) as Map<String, dynamic>;
      _completionTimestamps = timestampsMap.map((key, value) => MapEntry(key, DateTime.parse(value as String)));
    }
  }

  Future<void> _saveConfettiFlags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('confetti_shown_dates', jsonEncode(_confettiShownDates.toList()));
  }

  Future<void> _loadConfettiFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('confetti_shown_dates');
    if (data != null) {
      final List<dynamic> datesList = jsonDecode(data);
      _confettiShownDates = datesList.map((date) => date as String).toSet();
    }
  }

  void _onMoodSelected(int? moodIndex, String moodType, [DateTime? specificDate]) {
    final dateToUse = specificDate ?? _selectedDate;
    final key = DateFormat('yyyy-MM-dd').format(dateToUse);
    setState(() {
      if (moodIndex == null || moodType.isEmpty) {
        _moodsByDate.remove(key);
      } else {
        // Convert mood type to emoji for storage
        final emoji = _moodTypeToEmoji(moodType);
        _moodsByDate[key] = emoji;
      }
    });
    _saveMoods();
    
    // Show motivational message if mood was selected
    if (moodType.isNotEmpty) {
      _showMotivationalMessage(moodType);
    }
  }

  Map<DateTime, String> _convertMoodDataForDashboard() {
    final Map<DateTime, String> convertedMoodData = {};
    
    for (final entry in _moodsByDate.entries) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(entry.key);
        // Convert emoji to mood type
        final moodType = _emojiToMoodType(entry.value);
        if (moodType.isNotEmpty) {
          convertedMoodData[date] = moodType;
        }
      } catch (e) {
        // Skip invalid date formats
        continue;
      }
    }
    
    return convertedMoodData;
  }

  String _emojiToMoodType(String emoji) {
    switch (emoji) {
      case '😊':
        return 'happy';
      case '😐':
        return 'neutral';
      case '😢':
        return 'sad';
      case '😠':
        return 'angry';
      default:
        return '';
    }
  }

  String _moodTypeToEmoji(String moodType) {
    switch (moodType) {
      case 'happy':
        return '😊';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      default:
        return '';
    }
  }

  String? _getSelectedMoodType() {
    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final emoji = _moodsByDate[key];
    if (emoji != null && emoji.isNotEmpty) {
      return _emojiToMoodType(emoji);
    }
    return null;
  }

  String _getMotivationalMessage(String moodType) {
    switch (moodType) {
      case 'happy':
        return '🌟 Keep that positive energy flowing!';
      case 'neutral':
        return '✨ Every day is a new opportunity!';
      case 'sad':
        return '💙 It\'s okay to feel this way. Tomorrow will be better!';
      case 'angry':
        return '🔥 Take a deep breath. You\'ve got this!';
      default:
        return '💪 You\'re doing great!';
    }
  }

  Color _getMoodBackgroundColor(String moodType) {
    switch (moodType) {
      case 'happy':
        return const Color(0xFFE3F2FD); // Soft light blue
      case 'neutral':
        return const Color(0xFFF3E5F5); // Soft light purple
      case 'sad':
        return const Color(0xFFFCE4EC); // Soft light pink
      case 'angry':
        return const Color(0xFFFFF8E1); // Soft light yellow/cream
      default:
        return const Color(0xFFF0F0F0); // Light gray
    }
  }

  void _showMotivationalMessage(String moodType) {
    final message = _getMotivationalMessage(moodType);
    
    // Show the message at center of screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _getMoodBackgroundColor(moodType),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
    
    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  void _checkForCompletion(double progress) {
    final dateKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    if (progress == 1.0 && _lastProgress < 1.0) {
      // Check if confetti has already been shown for this date
      final confettiAlreadyShown = _confettiShownDates.contains(dateKey);
      
      if (!confettiAlreadyShown) {
        // This is the first time completing all tasks for this date
        _confettiController.play();
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 300);
          }
        });
        setState(() {
          _showCompletionMessage = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showCompletionMessage = false);
        });
        
        // Mark confetti as shown for this date
        _confettiShownDates.add(dateKey);
        _saveConfettiFlags();
      }
      
      // Save the completion timestamp
      _completionTimestamps[dateKey] = DateTime.now();
      _saveCompletionTimestamps();
    } else if (progress < 1.0 && _lastProgress == 1.0) {
      setState(() {
        _showCompletionMessage = false;
      });
      
      // Remove completion timestamp if tasks are uncompleted
      _completionTimestamps.remove(dateKey);
      _saveCompletionTimestamps();
    }
    _lastProgress = progress;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // const Header(),
                      // const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final double cardSize = MediaQuery.of(context).size.width < 600
                              ? (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2
                              : 220;
                          final items = _getItemsForTimeRange(_selectedDate);
                          final total = items.length;
                          final completed = items.where((item) => item.done).length;
                          final progress = total == 0 ? 0.0 : completed / total;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _checkForCompletion(progress);
                          });
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 0,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1,
                                children: [
                                  AspectRatio(
                                  aspectRatio: 1,
                                    child: DateCard(
                                      date: _selectedDate,
                                      progress: progress,
                                      timeRange: _selectedTimeRange,
                                    ),
                                  ),
                                  AspectRatio(
                                  aspectRatio: 1,
                                  child: CustomCalendarCard(
                                    selectedDate: _selectedDate,
                                    focusedDate: _selectedDate,
                                    items: _plannerItems,
                                    onDateSelected: (date) {
                                      setState(() {
                                        _selectedDate = date;
                                        // Preserve current view if already on weekly quest, monthly quest, or mood tracker
                                        if (_selectedTimeRange == 'weekly') {
                                          // Stay in weekly quest view, just update the focused day
                                          _focusedDay = date;
                                          // Set the selected date as expanded
                                          _expandedDate = date;
                                        } else if (_selectedTimeRange == 'monthly') {
                                          // Stay in monthly quest view, just update the selected date
                                          _selectedDate = date;
                                        } else if (_selectedTimeRange == 'yearly') {
                                          // Stay in yearly quest view, just update the selected date
                                          _selectedDate = date;
                                        } else if (_selectedTimeRange == 'dashboard') {
                                          // Stay in mood tracker view, just update the selected date
                                          _selectedDate = date;
                                          _focusedDay = date;
                                        } else {
                                          // Set time range based on selected date for other views
                                        final today = DateTime.now();
                                        final isToday = date.year == today.year && 
                                                       date.month == today.month && 
                                                       date.day == today.day;
                                        if (isToday) {
                                          _selectedTimeRange = 'today';
                                        } else {
                                          _selectedTimeRange = 'custom';
                                          }
                                        }
                                      });
                                    },
                                    onPageChanged: (date) {
                                      setState(() {
                                        _selectedDate = date;
                                        _focusedDay = date; // Update focused day to sync with calendar navigation
                                      });
                                    },
                                  ),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 0,
                                child: ConfettiWidget(
                                  confettiController: _confettiController,
                                  blastDirectionality: BlastDirectionality.explosive,
                                  shouldLoop: false,
                                  colors: [themeProvider.shade400, themeProvider.successColor, themeProvider.warningColor, themeProvider.infoColor, Colors.purple.shade400],
                                  emissionFrequency: 0.08,
                                  numberOfParticles: 20,
                                  maxBlastForce: 20,
                                  minBlastForce: 8,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        child: Column(
                          children: [
                            if (_showCompletionMessage)
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 8),
                                child: Center(
                                  child: AnimatedOpacity(
                                    opacity: _showCompletionMessage ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 400),
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 340),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: themeProvider.successColor,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [BoxShadow(color: themeProvider.shadowColor, blurRadius: 8)],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                                          Icon(Icons.celebration, color: themeProvider.cardColor, size: 24),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              'Well done! All tasks completed!',
                                              style: TextStyle(color: themeProvider.cardColor, fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      MoodRow(
                        selectedMood: _getSelectedMoodType(),
                        onMoodSelected: (mood) => _onMoodSelected(0, mood),
                      ),
                      const SizedBox(height: 10),
                      // Removed snail progress bar
                      
                      Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 4,
                              margin: EdgeInsets.zero,
                              child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  // Time Range Selector
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          _buildCompactTimeRangeSelector(themeProvider),

                                        ],
                                      ),
                                    ),
                                  ),
                                  // Type Filter Tabs removed
                                  
                                  // Show Important Only Toggle
                                  if (_selectedTimeRange != 'dashboard' && _selectedTimeRange != 'mood')
                                    _buildImportantFilterToggle(themeProvider),
                                  
                                  _selectedTimeRange == 'dashboard' 
                                    ? DashboardView(
                                        items: _plannerItems,
                                        selectedDate: _selectedDate,
                                        moodData: _convertMoodDataForDashboard(),
                                        onDateChanged: (date) {
                                          setState(() {
                                            _selectedDate = date;
                                            _focusedDay = date;
                                          });
                                        },
                                        onMonthChanged: (date) {
                                          // This callback is triggered when mood calendar month changes
                                          // We don't need to do anything here as the mood calendar
                                          // already updates the main date via onDateChanged
                                        },
                                        onMoodSelected: (date, moodType) {
                                          _onMoodSelected(0, moodType, date);
                                        },
                                      )
                                    : _buildPlannerItemsForDate(_selectedDate, themeProvider),
                              ],
                              ),
                            ),
                          ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNavigationBar(themeProvider),

        );
      },
        );
      },
    );
      }

  Widget _buildBottomNavigationBar(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu button (left side)
              GestureDetector(
                onTap: () {
                  showGeneralDialog(
                    context: context,
                    barrierLabel: 'Settings',
                    barrierDismissible: true,
                    barrierColor: themeProvider.overlayColor,
                    transitionDuration: const Duration(milliseconds: 350),
                    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
                    transitionBuilder: (context, anim1, anim2, child) {
                      final offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                          .animate(CurvedAnimation(parent: anim1, curve: Curves.easeInOut));
                      return SlideTransition(
                        position: offset,
                        child: const SettingsPanel(left: true),
                      );
                    },
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: themeProvider.shade400,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.shadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.dehaze, size: 20, color: Colors.white),
                  ),
                ),
              ),
              // Logo (center)
              SizedBox(
                height: 40,
                child: Image.asset(
                  _getLogoForTheme(themeProvider),
                  fit: BoxFit.contain,
                ),
              ),
              // FAB button (right side)
              GestureDetector(
                onTap: () => _showContextAwareAddForm(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: themeProvider.shade400,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.shadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.add, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  
  List<PlannerItem> _getItemsForTimeRange(DateTime baseDate) {
    final items = <PlannerItem>[];
    final processedItems = <String, Set<String>>{}; // itemId -> set of processed dates
    
    // Determine the date range based on selected time range
    DateTime startDate, endDate;
    
    switch (_selectedTimeRange) {
      case 'today':
        startDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
        endDate = startDate;
        break;
      case 'weekly':
        startDate = _getStartOfWeek(baseDate);
        endDate = _getEndOfWeek(baseDate);
        break;
      case 'monthly':
        startDate = _getStartOfMonth(baseDate);
        endDate = _getEndOfMonth(baseDate);
        break;
      case 'yearly':
        startDate = _getStartOfYear(baseDate);
        endDate = _getEndOfYear(baseDate);
        break;
      case 'custom':
      default:
        startDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
        endDate = startDate;
    }
    
    // Process all items to handle both regular and recurring items
    for (final item in _plannerItems) {
      // Check each day in the range
      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
        final currentDateKey = '${currentDate.year}-${currentDate.month}-${currentDate.day}';
        
        // Initialize the set for this item if not exists
        processedItems.putIfAbsent(item.id, () => <String>{});
        
        // Check if we've already processed this item for this date
        if (!processedItems[item.id]!.contains(currentDateKey)) {
          bool shouldAdd = false;
          
          // Check if this is a regular item for this exact date
          final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
          final targetDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
          
          if (itemDate.isAtSameMomentAs(targetDate)) {
            // This is a regular item for this exact date
            items.add(item);
            shouldAdd = true;
          } else if (item.recurrence != null && 
                     (item.recurrence!.patterns.isNotEmpty || 
                      (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty)) &&
                     RecurrenceUtils.shouldAppearOnDate(item, currentDate)) {
            // This is a recurring item that should appear on this date
            final virtualItem = RecurrenceUtils.createVirtualInstance(item, currentDate);
            items.add(virtualItem);
            shouldAdd = true;
          }
          
          if (shouldAdd) {
            // Mark this item as processed for this date
            processedItems[item.id]!.add(currentDateKey);
          }
        }
        
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
    
    // Filter by important if toggle is enabled
    if (_showImportantOnly) {
      final filteredItems = items.where((item) => item.isImportant).toList();
      return filteredItems;
    }
    
    return items;
  }

  /// Get items for a specific month range, regardless of the selected time range
  List<PlannerItem> _getItemsForMonth(DateTime monthStart, DateTime monthEnd) {
    final items = <PlannerItem>[];
    final processedItems = <String, Set<String>>{}; // itemId -> set of processed dates
    
    // Process all items to handle both regular and recurring items
    for (final item in _plannerItems) {
      // Check each day in the month range
      DateTime currentDate = monthStart;
      while (currentDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
        final currentDateKey = '${currentDate.year}-${currentDate.month}-${currentDate.day}';
        
        // Initialize the set for this item if not exists
        processedItems.putIfAbsent(item.id, () => <String>{});
        
        // Check if we've already processed this item for this date
        if (!processedItems[item.id]!.contains(currentDateKey)) {
          bool shouldAdd = false;
          
          // Check if this is a regular item for this exact date
          final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
          final targetDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
          
          if (itemDate.isAtSameMomentAs(targetDate)) {
            // This is a regular item for this exact date
            items.add(item);
            shouldAdd = true;
          } else if (item.recurrence != null && 
                     (item.recurrence!.patterns.isNotEmpty || 
                      (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty)) &&
                     RecurrenceUtils.shouldAppearOnDate(item, currentDate)) {
            // This is a recurring item that should appear on this date
            final virtualItem = RecurrenceUtils.createVirtualInstance(item, currentDate);
            items.add(virtualItem);
            shouldAdd = true;
          }
          
          if (shouldAdd) {
            // Mark this item as processed for this date
            processedItems[item.id]!.add(currentDateKey);
          }
        }
        
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
    
    // Filter by important if toggle is enabled
    if (_showImportantOnly) {
      final filteredItems = items.where((item) => item.isImportant).toList();
      return filteredItems;
    }
    
    return items;
  }

  List<PlannerItem> _getItemsForDate(DateTime date) {
    final items = <PlannerItem>[];
    final processedIds = <String>{};
    
    // Normalize the target date to compare only year/month/day
    final targetDate = DateTime(date.year, date.month, date.day);
    
    // Process all items and handle both regular and recurring items
    for (final item in _plannerItems) {
      // Normalize item date to compare only year/month/day
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      
      // Check if this item should appear on the target date
      bool shouldAppear = false;
      
      if (itemDate.isAtSameMomentAs(targetDate)) {
        // This is a regular item for this exact date
        shouldAppear = true;
      } else if (item.recurrence != null && 
                 (item.recurrence!.patterns.isNotEmpty || 
                  (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty)) &&
                 RecurrenceUtils.shouldAppearOnDate(item, date)) {
        // This is a recurring item that should appear on this date
        shouldAppear = true;
      }
      
      if (shouldAppear && !processedIds.contains(item.id)) {
        // Add the item (either original or virtual instance)
        if (itemDate.isAtSameMomentAs(targetDate)) {
          // Use the original item for the exact date match
          items.add(item);
        } else {
          // Create a virtual instance for recurring items
          final virtualItem = RecurrenceUtils.createVirtualInstance(item, date);
          items.add(virtualItem);
        }
        
        // Mark this item as processed to avoid duplicates
        processedIds.add(item.id);
      }
    }
    
    return items;
  }



  // Helper method to find the original recurring task
  PlannerItem? _findOriginalRecurringTask(PlannerItem virtualItem) {
    if (virtualItem.recurrence == null || virtualItem.recurrence!.patterns.isEmpty) {
      return null;
    }
    
    // Check if this is a virtual instance by looking at the ID format
    if (virtualItem.id.contains('_virtual_')) {
      // Extract the original ID from the virtual instance ID
      final originalId = virtualItem.id.split('_virtual_')[0];
      
      // Find the original item by ID
      return _plannerItems.firstWhere(
        (original) => original.id == originalId,
        orElse: () => virtualItem,
      );
    }
    
    // For non-virtual instances, find by matching properties
    return _plannerItems.firstWhere(
      (original) => original.recurrence != null && 
                   original.recurrence!.patterns.isNotEmpty &&
                   original.name == virtualItem.name &&
                   original.type == virtualItem.type &&
                   original.date.isBefore(virtualItem.date),
      orElse: () => virtualItem,
    );
  }

  // Helper method to handle editing items (including recurring ones)
  Future<void> _handleEditItem(PlannerItem item) async {
    // Find the original task if this is a recurring task
    final originalItem = _findOriginalRecurringTask(item);
    final targetItem = originalItem ?? item;
    
    final updatedItem = await showDialog<PlannerItem>(
                              context: context,
      builder: (context) => Center(
                                    child: AddPlannerItemForm(
          onSave: (updated) => Navigator.of(context).pop(updated),
          initialDate: targetItem.date,
          initialItem: targetItem,
          existingItems: _plannerItems, // Pass existing items for duplicate validation
        ),
      ),
      barrierDismissible: true,
    );
    
    if (updatedItem != null && mounted) {
      // Find the item by ID instead of by reference
      final idx = _plannerItems.indexWhere((existingItem) => existingItem.id == targetItem.id);
      if (idx != -1) {
        try {
          // Update the items list first
          final updatedItems = List<PlannerItem>.from(_plannerItems);
          updatedItems[idx] = updatedItem;
          
          // Save to storage with updated items
          await PlannerStorage.save(updatedItems);
          
          // Defer UI update to next frame to avoid conflicts
          if (mounted) {
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  _plannerItems = updatedItems;
                  
                  // Update selected date if needed
                  if (updatedItem.date.year != _selectedDate.year || 
                      updatedItem.date.month != _selectedDate.month || 
                      updatedItem.date.day != _selectedDate.day) {
                    _selectedDate = DateTime(updatedItem.date.year, updatedItem.date.month, updatedItem.date.day);
                  }
                });
              }
            });
          }
          
          // Show success message after a short delay
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Item updated!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: themeProvider.successColor,
                  ),
                );
              }
            });
          }
        } catch (e) {
          // Handle errors gracefully
          print('Error updating item: $e');
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Error updating item. Please try again.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: themeProvider.errorColor,
                  ),
                );
              }
            });
          }
        }
      } else {
        // Show error to user
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Error: Could not find item to update'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: themeProvider.errorColor,
                ),
              );
            }
          });
        }
      }
    }
  }

  // Helper method to handle deleting items
  Future<void> _handleDeleteItem(PlannerItem item) async {
    print('🔔 [HomeScreen] === DELETING ITEM ===');
    print('🔔 [HomeScreen] Item: "${item.name}"');
    print('🔔 [HomeScreen] - Reminder enabled: ${item.reminder}');
    print('🔔 [HomeScreen] - Start time: ${item.startTime}');
    
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    final removedItem = item;
    final removedIndex = _plannerItems.indexWhere((existingItem) => existingItem.id == item.id);
    
    // Cancel reminder if it exists
    print('🔔 [HomeScreen] 🗑️ Cancelling reminder for "${item.name}"');
    await NotificationService().cancelReminder(item);
    
    setState(() {
      _plannerItems.removeAt(removedIndex);
    });
    PlannerStorage.save(_plannerItems);
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: const Text('Plan deleted'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: themeProvider.errorColor,
        action: SnackBarAction(
          label: 'Undo',
          textColor: themeProvider.textColor,
          onPressed: () {
            setState(() {
              _plannerItems.insert(removedIndex, removedItem);
            });
            PlannerStorage.save(_plannerItems);
            scaffold.showSnackBar(
              SnackBar(
                content: const Text('Undo successful'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: themeProvider.successColor,
                                  ),
                                );
                              },
        ),
      ),
    );
  }

  Widget _buildWeeklyView(DateTime baseDate, ThemeProvider themeProvider) {
    return WeeklyView(
      selectedDate: _focusedDay,
      allItems: _plannerItems,
      themeProvider: themeProvider,
      onDaySelected: (date) {
        setState(() {
          _selectedDate = date;
          _focusedDay = date;
        });
      },
      onAddTask: (selectedDate) {
        _showContextAwareAddForm(selectedDate: selectedDate);
      },
      onWeekChanged: (date) {
        setState(() {
          _selectedDate = date;
          _focusedDay = date;
        });
      },
      onToggleTask: (item) => _toggleWeeklyItem(item, themeProvider),
      onDeleteTask: (item) => _handleDeleteItem(item),
      onEditTask: (item) => _handleEditItem(item),
      onToggleImportantTask: (item) => _toggleImportantStatus(item),
      showImportantOnly: _showImportantOnly,
      expandedDate: _expandedDate,
    );
  }



  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.assignment;
      case 'routine':
        return Icons.repeat;
      case 'event':
        return Icons.event;
      case 'shopping':
        return Icons.shopping_cart;
      default:
        return Icons.assignment;
    }
  }

  Widget _buildMonthlyView(DateTime baseDate, ThemeProvider themeProvider) {
    // Check if a specific date is selected in monthly view
    final isDateSelected = _selectedDate.year == baseDate.year && 
                          _selectedDate.month == baseDate.month && 
                          _selectedDate.day != baseDate.day;
    
    // Get items for the selected date or the entire month
    final items = isDateSelected ? _getItemsForDate(_selectedDate) : _getItemsForTimeRange(baseDate);
    
    // Calculate statistics
    final totalItems = items.length;
    final completedItems = items.where((item) => item.done).length;
    final pendingItems = totalItems - completedItems;
    final progress = totalItems > 0 ? completedItems / totalItems : 0.0;
    
    return Column(
      children: [
        // Month navigation header
        _buildMonthNavigation(baseDate, themeProvider),
        const SizedBox(height: 8),
        // Calendar grid
        _buildCalendarGrid(baseDate, themeProvider),
        const SizedBox(height: 16),
        // Month summary
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: themeProvider.themeMode == ThemeMode.dark 
                    ? Colors.white.withOpacity(0.1)  // Light shadow for dark mode
                    : Colors.black.withOpacity(0.12), // Dark shadow for light mode
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Month Summary',
                style: GoogleFonts.dancingScript(
                  color: themeProvider.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
                children: [
                  DonutChart(
                    total: totalItems,
                    completed: completedItems,
                    pending: pendingItems,
                    label: 'Total',
                    size: 60,
                    completedColor: themeProvider.shade400.withOpacity(0.8),
                    pendingColor: themeProvider.shade400.withOpacity(0.8),
                    totalColor: themeProvider.shade400.withOpacity(0.8),
                  ),
                  DonutChart(
                    total: totalItems,
                    completed: completedItems,
                    pending: pendingItems,
                    label: 'Completed',
                    size: 60,
                    completedColor: Colors.green.shade400.withOpacity(0.8),
                    pendingColor: Colors.green.shade400.withOpacity(0.8),
                    totalColor: Colors.green.shade400.withOpacity(0.8),
                  ),
                  DonutChart(
                    total: totalItems,
                    completed: completedItems,
                    pending: pendingItems,
                    label: 'Pending',
                    size: 60,
                    completedColor: Colors.orange.shade400.withOpacity(0.8),
                    pendingColor: Colors.orange.shade400.withOpacity(0.8),
                    totalColor: Colors.orange.shade400.withOpacity(0.8),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Show selected date's tasks if a date is selected
        if (isDateSelected) ...[
          const SizedBox(height: 16),
          _buildSelectedDateTasks(themeProvider),
        ],
      ],
    );
  }

  Widget _buildSelectedDateTasks(ThemeProvider themeProvider) {
    final items = _getItemsForDate(_selectedDate);
    
    // Filter by important if toggle is enabled
    final filteredItems = _showImportantOnly 
        ? items.where((item) => item.isImportant).toList()
        : items;
    
    // Separate into unchecked and checked
    final unchecked = <PlannerItem>[];
    final checked = <PlannerItem>[];
    for (final item in filteredItems) {
      if (item.done) {
        checked.add(item);
      } else {
        unchecked.add(item);
      }
    }
    
    // Sort by time
    unchecked.sort((a, b) {
      final aMinutes = (a.startTime?.hour ?? 0) * 60 + (a.startTime?.minute ?? 0);
      final bMinutes = (b.startTime?.hour ?? 0) * 60 + (b.startTime?.minute ?? 0);
      return aMinutes.compareTo(bMinutes);
    });
    checked.sort((a, b) {
      final aMinutes = (a.startTime?.hour ?? 0) * 60 + (a.startTime?.minute ?? 0);
      final bMinutes = (b.startTime?.hour ?? 0) * 60 + (b.startTime?.minute ?? 0);
      return aMinutes.compareTo(bMinutes);
    });
    
    if (filteredItems.isEmpty) {
      return EmptyStateWidget(timeRange: 'today', selectedDate: _selectedDate);
    }
    
    final hasSeparator = unchecked.isNotEmpty && checked.isNotEmpty;
    
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: unchecked.length,
          itemBuilder: (context, index) {
            final item = unchecked[index];
            final itemKey = item.hashCode.toString() + item.name;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Dismissible(
                key: ValueKey(itemKey),
                direction: DismissDirection.horizontal,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                confirmDismiss: null,
                onDismissed: (direction) async {
                  await _handleDeleteItem(item);
                },
                child: GestureDetector(
                  onTap: () async {
                    await _handleEditItem(item);
                  },
                  child: _buildPlannerItemRow(
                    item,
                    () => _onToggleItem(item, true, index, false, themeProvider),
                    themeProvider,
                  ),
                ),
              ),
            );
          },
        ),
        if (hasSeparator)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Divider(thickness: 1, color: themeProvider.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Completed', style: TextStyle(color: themeProvider.textColorSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                Expanded(child: Divider(thickness: 1, color: themeProvider.dividerColor)),
              ],
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: checked.length,
          itemBuilder: (context, index) {
            final item = checked[index];
            final itemKey = item.hashCode.toString() + item.name;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Dismissible(
                key: ValueKey(itemKey),
                direction: DismissDirection.horizontal,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                confirmDismiss: null,
                onDismissed: (direction) async {
                  await _handleDeleteItem(item);
                },
                child: GestureDetector(
                  onTap: () async {
                    await _handleEditItem(item);
                  },
                  child: _buildPlannerItemRow(
                    item,
                    () => _onToggleItem(item, true, index, true, themeProvider),
                    themeProvider,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildYearlyView(DateTime baseDate, ThemeProvider themeProvider) {
    final startOfYear = _getStartOfYear(baseDate);
    final endOfYear = _getEndOfYear(baseDate);
    
    // Get items for the year
    final yearItems = _getItemsForTimeRange(baseDate);
    
    // Calculate year statistics
    final totalItems = yearItems.length;
    final completedItems = yearItems.where((item) => item.done).length;
    final pendingItems = totalItems - completedItems;
    final progress = totalItems > 0 ? completedItems / totalItems : 0.0;
    
    return Column(
      children: [
        // Year navigation header
        _buildYearNavigation(baseDate, themeProvider),
        const SizedBox(height: 20),
        // Month grid
        SizedBox(
          height: 320, // Further increased height to ensure all 12 months are fully visible
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildMonthCard('January', 1, baseDate, themeProvider),
              _buildMonthCard('February', 2, baseDate, themeProvider),
              _buildMonthCard('March', 3, baseDate, themeProvider),
              _buildMonthCard('April', 4, baseDate, themeProvider),
              _buildMonthCard('May', 5, baseDate, themeProvider),
              _buildMonthCard('June', 6, baseDate, themeProvider),
              _buildMonthCard('July', 7, baseDate, themeProvider),
              _buildMonthCard('August', 8, baseDate, themeProvider),
              _buildMonthCard('September', 9, baseDate, themeProvider),
              _buildMonthCard('October', 10, baseDate, themeProvider),
              _buildMonthCard('November', 11, baseDate, themeProvider),
              _buildMonthCard('December', 12, baseDate, themeProvider),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Year summary
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: themeProvider.themeMode == ThemeMode.dark 
                    ? Colors.white.withOpacity(0.1)  // Light shadow for dark mode
                    : Colors.black.withOpacity(0.12), // Dark shadow for light mode
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Year Summary',
                style: GoogleFonts.dancingScript(
                  color: themeProvider.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
                children: [
                  DonutChart(
                    total: totalItems,
                    completed: completedItems,
                    pending: pendingItems,
                    label: 'Total',
                    size: 60,
                    completedColor: themeProvider.shade400.withOpacity(0.8),
                    pendingColor: themeProvider.shade400.withOpacity(0.8),
                    totalColor: themeProvider.shade400.withOpacity(0.8),
                  ),
                  DonutChart(
                    total: totalItems,
                    completed: completedItems,
                    pending: pendingItems,
                    label: 'Completed',
                    size: 60,
                    completedColor: Colors.green.shade400.withOpacity(0.8),
                    pendingColor: Colors.green.shade400.withOpacity(0.8),
                    totalColor: Colors.green.shade400.withOpacity(0.8),
                  ),
                  DonutChart(
                    total: totalItems,
                    completed: completedItems,
                    pending: pendingItems,
                    label: 'Pending',
                    size: 60,
                    completedColor: Colors.orange.shade400.withOpacity(0.8),
                    pendingColor: Colors.orange.shade400.withOpacity(0.8),
                    totalColor: Colors.orange.shade400.withOpacity(0.8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekNavigation(DateTime baseDate, ThemeProvider themeProvider) {
    final startOfWeek = _getStartOfWeek(baseDate);
    final endOfWeek = _getEndOfWeek(baseDate);
    final weekRange = '${DateFormat('dd MMM').format(startOfWeek)} - ${DateFormat('dd MMM').format(endOfWeek)}';
    final isCurrentWeek = _isDateInRange(DateTime.now(), startOfWeek, endOfWeek);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.dividerColor),
          ),
          child: Row(
            children: [
          // Previous week button
          GestureDetector(
            onTap: () {
                  setState(() {
                _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                _selectedDate = _focusedDay;
                  });
                },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
              ),
              child: Icon(Icons.chevron_left, color: themeProvider.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Week range
          Expanded(
            child: Text(
              weekRange,
                style: TextStyle(
                fontSize: 12,
                  fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Next week button
          GestureDetector(
            onTap: () {
                  setState(() {
                _focusedDay = _focusedDay.add(const Duration(days: 7));
                _selectedDate = _focusedDay;
                  });
                },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
              ),
              child: Icon(Icons.chevron_right, color: themeProvider.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Today button
          if (!isCurrentWeek)
            GestureDetector(
              onTap: () {
                setState(() {
                  _focusedDay = DateTime.now();
                  _selectedDate = DateTime.now();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: themeProvider.shade400.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYearNavigation(DateTime baseDate, ThemeProvider themeProvider) {
    final yearText = '${baseDate.year}';
    final isCurrentYear = baseDate.year == DateTime.now().year;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.dividerColor),
      ),
      child: Row(
            children: [
          // Previous year button
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime(baseDate.year - 1, baseDate.month, baseDate.day);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
              ),
              child: Icon(Icons.chevron_left, color: themeProvider.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Year
          Expanded(
            child: Text(
              yearText,
                style: TextStyle(
                fontSize: 14,
                  fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Next year button
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
              ),
              child: Icon(Icons.chevron_right, color: themeProvider.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Today button
          if (!isCurrentYear)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: themeProvider.shade400.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildMonthNavigation(DateTime baseDate, ThemeProvider themeProvider) {
    final monthName = DateFormat('MMMM yyyy').format(baseDate);
    final isCurrentMonth = baseDate.year == DateTime.now().year && baseDate.month == DateTime.now().month;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.dividerColor),
      ),
      child: Row(
        children: [
          // Previous month button
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime(baseDate.year, baseDate.month - 1, 1);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
              ),
              child: Icon(Icons.chevron_left, color: themeProvider.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Month and year
          Expanded(
            child: Text(
              monthName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Next month button
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime(baseDate.year, baseDate.month + 1, 1);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeProvider.shade400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
              ),
              child: Icon(Icons.chevron_right, color: themeProvider.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          // Today button
          if (!isCurrentMonth)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: themeProvider.shade400.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: themeProvider.shade400.withOpacity(0.3)),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime baseDate, ThemeProvider themeProvider) {
    final firstDayOfMonth = DateTime(baseDate.year, baseDate.month, 1);
    final lastDayOfMonth = DateTime(baseDate.year, baseDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // Calculate the weekday of the first day (0 = Monday, 1 = Tuesday, etc.)
    final firstWeekday = (firstDayOfMonth.weekday - 1) % 7; // Convert to Monday = 0
    
    // Calculate total cells needed (including empty cells at start)
    final totalCells = firstWeekday + daysInMonth;
    final actualWeeks = (totalCells / 7).ceil();
    
    return Column(
      children: [
        // Day headers
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColorSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        ...List.generate(actualWeeks, (weekIndex) {
          return Row(
            children: List.generate(7, (dayIndex) {
              final cellIndex = weekIndex * 7 + dayIndex;
              final dayOfMonth = cellIndex - firstWeekday + 1;
              
              // Check if this cell represents a valid day
              if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
                return Expanded(
                  child: Container(
                  height: 120,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
              
              final currentDate = DateTime(baseDate.year, baseDate.month, dayOfMonth);
              final isToday = currentDate.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
              final isSelectedDate = currentDate.isAtSameMomentAs(_selectedDate);
              final dayItems = _getItemsForDate(currentDate);
              
              return Expanded(
                child: GestureDetector(
                                    onTap: () {
                    // Navigate to today view immediately
                    setState(() {
                      _selectedDate = currentDate;
                      _selectedTimeRange = 'today';
                    });
                  },
                  child: Container(
                    height: 120,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelectedDate ? themeProvider.shade400.withOpacity(0.2) : 
                             isToday ? themeProvider.shade400.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelectedDate ? themeProvider.shade400 : 
                               isToday ? themeProvider.shade400.withOpacity(0.3) : themeProvider.dividerColor.withOpacity(0.3),
                        width: isSelectedDate ? 2 : isToday ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date number
                          Text(
                            '$dayOfMonth',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelectedDate ? FontWeight.bold : isToday ? FontWeight.bold : FontWeight.normal,
                              color: isSelectedDate ? themeProvider.shade700 : isToday ? themeProvider.shade700 : themeProvider.textColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          // Item previews with smart overflow handling
                          if (dayItems.isNotEmpty) ...[
                            _buildCalendarItemsWithOverflow(dayItems, themeProvider),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildCalendarItemPreview(PlannerItem item, ThemeProvider themeProvider) {
    final typeColor = _getTypeColor(item.type, themeProvider);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: typeColor.withOpacity(0.3), width: 0.5),
      ),
            child: Text(
              item.name.length > 6 ? '${item.name.substring(0, 6)}...' : item.name,
              style: TextStyle(
          fontSize: 10,
                color: typeColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCalendarItemsWithOverflow(List<PlannerItem> items, ThemeProvider themeProvider) {
    // Calculate available space for items (cell height - date number - padding)
    // Cell height: 120px, date number: ~12px, padding: 4px, spacing: 1px
    // Available space: ~103px for items
    const double itemHeight = 8.0; // Height of each item preview
    const double itemSpacing = 1.0; // Spacing between items
    const double overflowIndicatorHeight = 8.0; // Height of "+n more" indicator
    const double availableSpace = 103.0; // Available space for items
    
    // Calculate how many items can fit
    int maxVisibleItems = 4; // Show maximum 4 items to avoid overflow
    int hiddenItemsCount = 0;
    
    if (items.length > maxVisibleItems) {
      hiddenItemsCount = items.length - maxVisibleItems;
    }
    
    // Build the visible items
    final visibleItems = items.take(maxVisibleItems).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleItems.map((item) => _buildCalendarItemPreview(item, themeProvider)),
        if (hiddenItemsCount > 0)
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: themeProvider.dividerColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$hiddenItemsCount more',
              style: TextStyle(
                fontSize: 8,
                color: themeProvider.textColorSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  String _getTypeEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'task':
        return '📝';
      case 'routine':
        return '🧘';
      case 'event':
        return '🗓️';
      case 'shopping':
        return '🛒';
      default:
        return '📋';
    }
  }

  Widget _buildPlannerItemsForDate(DateTime date, ThemeProvider themeProvider) {
    // If weekly view is selected, use the weekly view builder
    if (_selectedTimeRange == 'weekly') {
      return _buildWeeklyView(date, themeProvider);
    }
    
    // If monthly view is selected, use the monthly view builder
    if (_selectedTimeRange == 'monthly') {
      return _buildMonthlyView(date, themeProvider);
    }
    
    // If yearly view is selected, use the yearly view builder
    if (_selectedTimeRange == 'yearly') {
      return _buildYearlyView(date, themeProvider);
    }
    
    // For custom date or today, show single day view
    
            List<PlannerItem> items = _getItemsForTimeRange(date);
    
    // Filter by important if toggle is enabled
    if (_showImportantOnly) {
      items = items.where((item) => item.isImportant).toList();
    }
    
    // Separate into unchecked and checked
    final unchecked = <PlannerItem>[];
    final checked = <PlannerItem>[];
    for (final item in items) {
      if (item.done) {
        checked.add(item);
      } else {
        unchecked.add(item);
      }
    }
    unchecked.sort((a, b) {
      final aMinutes = (a.startTime?.hour ?? 0) * 60 + (a.startTime?.minute ?? 0);
      final bMinutes = (b.startTime?.hour ?? 0) * 60 + (b.startTime?.minute ?? 0);
      return aMinutes.compareTo(bMinutes);
    });
    checked.sort((a, b) {
      final aMinutes = (a.startTime?.hour ?? 0) * 60 + (a.startTime?.minute ?? 0);
      final bMinutes = (b.startTime?.hour ?? 0) * 60 + (b.startTime?.minute ?? 0);
      return aMinutes.compareTo(bMinutes);
    });
    if (items.isEmpty) {
      return EmptyStateWidget(timeRange: _selectedTimeRange, selectedDate: date);
    }
    final hasSeparator = unchecked.isNotEmpty && checked.isNotEmpty;
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: unchecked.length,
          itemBuilder: (context, index) {
            final item = unchecked[index];
            final start = item.startTime;
            final duration = item.duration ?? 0;
            final end = start == null ? null : TimeOfDay(
              hour: (start.hour + ((start.minute + duration) ~/ 60)) % 24,
              minute: (start.minute + duration) % 60,
            );
            final itemKey = item.hashCode.toString() + item.name;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Dismissible(
                key: ValueKey(itemKey),
                direction: DismissDirection.horizontal,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                confirmDismiss: null,
                onDismissed: (direction) async {
                  await _handleDeleteItem(item);
                },
                child: GestureDetector(
                  onTap: () async {
                    await _handleEditItem(item);
                  },
                  child: _buildPlannerItemRow(
                    item,
                    () => _onToggleItem(item, true, index, false, themeProvider),
                    themeProvider,
                    flash: _flashKey == itemKey,
                  ),
                ),
              ),
            );
          },
        ),
        if (hasSeparator)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Divider(thickness: 1, color: themeProvider.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Completed', style: TextStyle(color: themeProvider.textColorSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                Expanded(child: Divider(thickness: 1, color: themeProvider.dividerColor)),
              ],
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: checked.length,
          itemBuilder: (context, index) {
            final item = checked[index];
            final start = item.startTime;
            final duration = item.duration ?? 0;
            final end = start == null ? null : TimeOfDay(
              hour: (start.hour + ((start.minute + duration) ~/ 60)) % 24,
              minute: (start.minute + duration) % 60,
            );
            final itemKey = item.hashCode.toString() + item.name;
                        return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Dismissible(
                key: ValueKey(itemKey),
                direction: DismissDirection.horizontal,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: themeProvider.errorColor,
                  child: Icon(Icons.delete, color: themeProvider.cardColor, size: 28),
                ),
                confirmDismiss: null,
                onDismissed: (direction) async {
                  await _handleDeleteItem(item);
                },
                child: GestureDetector(
                  onTap: () async {
                    await _handleEditItem(item);
                  },
                  child: _buildPlannerItemRow(
                    item,
                    () => _onToggleItem(item, false, index, true, themeProvider),
                    themeProvider,
                    flash: _flashKey == itemKey,
                  ),
                ),
              ),
            );
              },
        ),
      ],
    );
  }

  Widget _buildImportantFilterToggle(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showImportantOnly = !_showImportantOnly;
              });
            },
            child: Row(
              children: [
                Icon(
                  _showImportantOnly ? Icons.star : Icons.star_border,
                  size: 20,
                  color: _showImportantOnly ? Colors.amber : themeProvider.textColorSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Important Only',
                  style: TextStyle(
                    fontSize: 14,
                    color: _showImportantOnly ? Colors.amber : themeProvider.textColorSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTimeRangeSelector(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent, // Removed gray background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.transparent, width: 0), // Removed border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactTimeRangeTab('today', 'T', 'Today\'s Quest', themeProvider),
          _buildViewMenuTab(themeProvider),
          _buildCompactTimeRangeTab('monthly', 'M', 'Monthly Quest', themeProvider),
          _buildCompactTimeRangeTab('yearly', 'Y', 'Yearly Quest', themeProvider),
          _buildCompactTimeRangeTab('dashboard', '😊', 'Mood Tracker', themeProvider),
        ],
                          ),
                        );
                      }

  Widget _buildViewMenuTab(ThemeProvider themeProvider) {
    final bool selected = _selectedTimeRange == 'weekly';
    final displayLabel = selected ? 'Weekly Quest' : 'W';

    return GestureDetector(
      onTap: () {
        setState(() {
          // Always stay in Weekly view when Weekly Quest button is clicked
            _selectedTimeRange = 'weekly';
          
          // Auto-expand today's date on first entry to weekly view
          if (_isFirstWeeklyEntry) {
            final today = DateTime.now();
            _expandedDate = today;
            
            // Navigate to the week that contains today if not already there
            final currentWeekStart = _getStartOfWeek(_focusedDay);
            final todayWeekStart = _getStartOfWeek(today);
            
            if (!_isDateInRange(today, currentWeekStart, _getEndOfWeek(_focusedDay))) {
              _focusedDay = today;
              _selectedDate = today;
            }
            
            _isFirstWeeklyEntry = false;
          }
          
          // Regenerate AnimatedList keys to reset lists and prevent RangeError
          _incompleteListKey = GlobalKey<AnimatedListState>();
          _completedListKey = GlobalKey<AnimatedListState>();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? themeProvider.shade400.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(
            color: themeProvider.shade400.withOpacity(0.3),
            width: 1,
          ) : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? themeProvider.textColor : themeProvider.textColorSecondary,
            fontSize: selected ? 14 : 13,
          ),
          child: Text(
            displayLabel,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildViewMenuOptions(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewOption('weekly', 'Weekly', themeProvider),
          const SizedBox(width: 8),
          _buildViewOption('monthly', 'Monthly', themeProvider),
          const SizedBox(width: 8),
          _buildViewOption('yearly', 'Yearly', themeProvider),
        ],
      ),
    );
  }

  Widget _buildViewOption(String value, String label, ThemeProvider themeProvider) {
    final bool selected = _selectedTimeRange == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeRange = value;
          
          // Auto-expand today's date on first entry to weekly view
          if (value == 'weekly' && _isFirstWeeklyEntry) {
            final today = DateTime.now();
            _expandedDate = today;
            
            // Navigate to the week that contains today if not already there
            final currentWeekStart = _getStartOfWeek(_focusedDay);
            final todayWeekStart = _getStartOfWeek(today);
            
            if (!_isDateInRange(today, currentWeekStart, _getEndOfWeek(_focusedDay))) {
              _focusedDay = today;
              _selectedDate = today;
            }
            
            _isFirstWeeklyEntry = false;
          }
          
          _showViewMenu = true; // Keep menu open when switching views
          // Regenerate AnimatedList keys to reset lists and prevent RangeError
          _incompleteListKey = GlobalKey<AnimatedListState>();
          _completedListKey = GlobalKey<AnimatedListState>();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? themeProvider.shade400.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(
            color: themeProvider.shade400.withOpacity(0.3),
            width: 1,
          ) : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? themeProvider.textColor : themeProvider.textColorSecondary,
            fontSize: selected ? 14 : 13,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
          ),
        ),
                          ),
                        );
                      }

  Widget _buildCompactTimeRangeTab(String value, String shortLabel, String fullLabel, ThemeProvider themeProvider) {
    final bool selected = _selectedTimeRange == value;
    final displayLabel = selected ? fullLabel : shortLabel;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (value == 'today') {
            // Reset to today when "T" is tapped and close view menu
            _selectedDate = DateTime.now();
            _selectedTimeRange = 'today';
            _showViewMenu = false; // Close view menu when switching to Today's Quest
          } else if (value == 'dashboard') {
            // Switch to mood tracker and close view menu
            _selectedTimeRange = 'dashboard';
            _showViewMenu = false; // Close view menu when switching to Mood Tracker
          } else if (value == 'monthly') {
            // Switch to monthly view and close view menu
            _selectedTimeRange = 'monthly';
            _showViewMenu = false; // Close view menu when switching to Monthly View
          } else if (value == 'yearly') {
            // Switch to yearly view and close view menu
            _selectedTimeRange = 'yearly';
            _showViewMenu = false; // Close view menu when switching to Yearly View
          } else {
            _selectedTimeRange = value;
          }
          // Regenerate AnimatedList keys to reset lists and prevent RangeError
          _incompleteListKey = GlobalKey<AnimatedListState>();
          _completedListKey = GlobalKey<AnimatedListState>();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? themeProvider.shade400.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(
            color: themeProvider.shade400.withOpacity(0.3),
            width: 1,
          ) : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? themeProvider.textColor : themeProvider.textColorSecondary,
            fontSize: selected ? 14 : 13,
          ),
          child: Text(
            displayLabel,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }





  // Helper methods for time range calculations
  DateTime _getStartOfWeek(DateTime date) {
    // Get Monday of the current week
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  DateTime _getEndOfWeek(DateTime date) {
    // Get Sunday of the current week
    final daysFromMonday = date.weekday - 1;
    final daysToSunday = 7 - date.weekday;
    return DateTime(date.year, date.month, date.day + daysToSunday);
  }

  DateTime _getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  DateTime _getStartOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  DateTime _getEndOfYear(DateTime date) {
    return DateTime(date.year, 12, 31);
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    
    return normalizedDate.isAfter(normalizedStart.subtract(const Duration(days: 1))) &&
           normalizedDate.isBefore(normalizedEnd.add(const Duration(days: 1)));
  }

  Color _getTypeColor(String type, ThemeProvider themeProvider) {
    switch (type) {
      case 'task':
        return themeProvider.shade400;
      case 'routine':
        return themeProvider.themeMode == ThemeMode.dark ? Colors.white : Colors.black;
      case 'event':
        return Colors.green;
      case 'shopping':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPlannerItemRow(PlannerItem item, VoidCallback onToggle, ThemeProvider themeProvider, {bool flash = false}) {
    return TaskRowWidget(
      item: item,
      themeProvider: themeProvider,
      onToggle: onToggle,
        flash: flash,
      onDelete: () => _handleDeleteItem(item),
      onEdit: () => _handleEditItem(item),
      onToggleImportant: () => _toggleImportantStatus(item),
    );
  }

  // Toggle important status for a task
  void _toggleImportantStatus(PlannerItem item) {
    setState(() {
      item.isImportant = !item.isImportant;
      PlannerStorage.save(_plannerItems);
    });
  }

  // Helper method to capitalize first letter of each word
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Simple toggle for weekly view items
  void _toggleWeeklyItem(PlannerItem item, ThemeProvider themeProvider) async {
    // Check if this is a virtual instance of a recurring task
    bool isVirtualInstance = item.id.contains('_virtual_');
    
    if (isVirtualInstance) {
      // For virtual instances, we need to track completion per date
      // Extract the original item ID and target date from the virtual instance ID
      final parts = item.id.split('_virtual_');
      if (parts.length == 2) {
        final originalId = parts[0];
        final targetDateMillis = int.tryParse(parts[1]);
        
        if (targetDateMillis != null) {
          // Find the original recurring task
          final originalItem = _plannerItems.firstWhere(
            (original) => original.id == originalId,
            orElse: () => item,
          );
          
          if (originalItem != item) {
            // Initialize completion tracking if not exists
            if (originalItem.completionDates == null) {
              originalItem.completionDates = <String>{};
            }
            
            final dateKey = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
            
            setState(() {
              if (item.done) {
                // Mark as incomplete
                originalItem.completionDates!.remove(dateKey);
                item.done = false;
                
                // Reset confetti flag for this date since a plan was unmarked
                _confettiShownDates.remove(dateKey);
                _saveConfettiFlags();
              } else {
                // Mark as complete
                originalItem.completionDates!.add(dateKey);
                item.done = true;
              }
              
              PlannerStorage.save(_plannerItems);
            });
          }
        }
      }
    } else {
      // For non-virtual instances, use the original logic
    setState(() {
      final wasCompleted = item.done;
      item.done = !item.done;
      
      // If marking as completed and it's a routine with steps, mark all steps as completed
      if (item.done && item.type == 'routine' && item.stepChecked != null && item.stepChecked!.isNotEmpty) {
        item.stepChecked = List.filled(item.stepChecked!.length, true);
        item.stepsDone = item.stepChecked!.length;
      }
      // If marking as incomplete and it's a routine with steps, reset all steps to unchecked
      else if (!item.done && item.type == 'routine' && item.stepChecked != null && item.stepChecked!.isNotEmpty) {
        item.stepChecked = List.filled(item.stepChecked!.length, false);
        item.stepsDone = 0;
      }
      
      // Reset confetti flag if unmarking from completed to pending
      if (wasCompleted && !item.done) {
        final dateKey = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
        _confettiShownDates.remove(dateKey);
        _saveConfettiFlags();
      }
      
      PlannerStorage.save(_plannerItems);
    });
    }
    
    // Update the home widget
    await WidgetService.updateWidget(_plannerItems);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item.done 
            ? '${_capitalizeWords(item.name)} completed! 🎉'
            : '${_capitalizeWords(item.name)} marked as incomplete',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: item.done 
          ? themeProvider.successColor 
          : themeProvider.textColorSecondary,
      ),
    );
  }

  // Toggle handler for check/uncheck with animation
  void _onToggleItem(PlannerItem item, bool toCompleted, int index, bool fromCompleted, ThemeProvider themeProvider) async {
    final itemKey = item.hashCode.toString() + item.name;
    
    // Check if this is a virtual instance of a recurring task
    bool isVirtualInstance = item.id.contains('_virtual_');
    
    if (isVirtualInstance) {
      // For virtual instances, we need to track completion per date
      // Extract the original item ID and target date from the virtual instance ID
      final parts = item.id.split('_virtual_');
      if (parts.length == 2) {
        final originalId = parts[0];
        final targetDateMillis = int.tryParse(parts[1]);
        
        if (targetDateMillis != null) {
      // Find the original recurring task
          final originalItem = _plannerItems.firstWhere(
            (original) => original.id == originalId,
        orElse: () => item,
      );
          
          if (originalItem != item) {
            // Initialize completion tracking if not exists
            if (originalItem.completionDates == null) {
              originalItem.completionDates = <String>{};
    }
            
            final dateKey = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
    
    setState(() {
      _flashKey = itemKey;
      if (toCompleted) {
        // Remove from incomplete
        _incompleteListKey.currentState?.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: _buildPlannerItemRow(item, () {}, themeProvider, flash: true),
          ),
          duration: const Duration(milliseconds: 350),
        );
                
                // Mark as complete for this specific date
                originalItem.completionDates!.add(dateKey);
        item.done = true;
        
        // If marking as completed and it's a routine with steps, mark all steps as completed
        if (item.type == 'routine' && item.stepChecked != null && item.stepChecked!.isNotEmpty) {
          item.stepChecked = List.filled(item.stepChecked!.length, true);
          item.stepsDone = item.stepChecked!.length;
        }
        
        // Insert into completed after a short delay
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            _completedListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 350));
          });
        });
      } else {
        // Remove from completed
        _completedListKey.currentState?.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: _buildPlannerItemRow(item, () {}, themeProvider, flash: true),
          ),
          duration: const Duration(milliseconds: 350),
        );
                
                // Mark as incomplete for this specific date
                originalItem.completionDates!.remove(dateKey);
        item.done = false;
        
        // If marking as incomplete and it's a routine with steps, reset all steps to unchecked
        if (item.type == 'routine' && item.stepChecked != null && item.stepChecked!.isNotEmpty) {
          item.stepChecked = List.filled(item.stepChecked!.length, false);
          item.stepsDone = 0;
        }
        
        // Reset confetti flag for this date since a plan was unmarked
        _confettiShownDates.remove(dateKey);
        _saveConfettiFlags();
        
                // Insert into incomplete after a short delay
                Future.delayed(const Duration(milliseconds: 200), () {
                  setState(() {
                    _incompleteListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 350));
                  });
                });
              }
              
              PlannerStorage.save(_plannerItems);
            });
          }
        }
      }
    } else {
      // For non-virtual instances, use the original logic
      setState(() {
        _flashKey = itemKey;
        if (toCompleted) {
          // Remove from incomplete
          _incompleteListKey.currentState?.removeItem(
            index,
            (context, animation) => SizeTransition(
              sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: _buildPlannerItemRow(item, () {}, themeProvider, flash: true),
            ),
            duration: const Duration(milliseconds: 350),
          );
          item.done = true;
          
          // If marking as completed and it's a routine with steps, mark all steps as completed
          if (item.type == 'routine' && item.stepChecked != null && item.stepChecked!.isNotEmpty) {
            item.stepChecked = List.filled(item.stepChecked!.length, true);
            item.stepsDone = item.stepChecked!.length;
          }
          
          // Insert into completed after a short delay
          Future.delayed(const Duration(milliseconds: 200), () {
            setState(() {
              _completedListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 350));
            });
          });
        } else {
          // Remove from completed
          _completedListKey.currentState?.removeItem(
            index,
            (context, animation) => SizeTransition(
              sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: _buildPlannerItemRow(item, () {}, themeProvider, flash: true),
            ),
            duration: const Duration(milliseconds: 350),
          );
          item.done = false;
          
          // If marking as incomplete and it's a routine with steps, reset all steps to unchecked
          if (item.type == 'routine' && item.stepChecked != null && item.stepChecked!.isNotEmpty) {
            item.stepChecked = List.filled(item.stepChecked!.length, false);
            item.stepsDone = 0;
          }
          
          // Reset confetti flag for this date since a plan was unmarked
          final dateKey = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
          _confettiShownDates.remove(dateKey);
          _saveConfettiFlags();
          
        // Insert into incomplete after a short delay
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            _incompleteListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 350));
          });
        });
      }
      PlannerStorage.save(_plannerItems);
    });
    }
    
    // Reset flash after animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _flashKey == itemKey) {
        setState(() {
          _flashKey = null;
        });
      }
    });
  }

  Widget _buildSummaryCard(String label, String value, Color color, ThemeProvider themeProvider) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCard(String monthName, int monthNumber, DateTime baseDate, ThemeProvider themeProvider) {
    // Get items for this specific month
    final monthStart = DateTime(baseDate.year, monthNumber, 1);
    final monthEnd = DateTime(baseDate.year, monthNumber + 1, 0);
    final monthItems = _getItemsForMonth(monthStart, monthEnd);
    
    // Calculate month statistics
    final totalItems = monthItems.length;
    final completedItems = monthItems.where((item) => item.done).length;
    final pendingItems = totalItems - completedItems;
    
    // Check if this is the current month
    final now = DateTime.now();
    final isCurrentMonth = baseDate.year == now.year && monthNumber == now.month;
    
    // Check if this is the selected month
    final isSelectedMonth = _selectedDate.year == baseDate.year && _selectedDate.month == monthNumber;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelectedMonth ? themeProvider.shade400.withOpacity(0.1) : themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeProvider.themeMode == ThemeMode.dark 
                ? Colors.white.withOpacity(0.1)  // Light shadow for dark mode
                : Colors.black.withOpacity(0.12), // Dark shadow for light mode
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isSelectedMonth ? Border.all(
          color: themeProvider.shade400,
          width: 2,
        ) : isCurrentMonth ? Border.all(
          color: themeProvider.shade400.withOpacity(0.3),
          width: 1,
        ) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to monthly view immediately
            setState(() {
              _selectedDate = DateTime(baseDate.year, monthNumber, 1);
              _selectedTimeRange = 'monthly';
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(6), // Further reduced padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  monthName.substring(0, 3), // First 3 letters (Jan, Feb, etc.)
                  style: TextStyle(
                    color: isSelectedMonth ? themeProvider.shade700 : themeProvider.textColor,
                    fontSize: 11, // Minimized font size
                    fontWeight: isSelectedMonth ? FontWeight.bold : FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2), // Minimal spacing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                Text(
                  totalItems.toString(),
                  style: TextStyle(
                    color: themeProvider.shade400,
                        fontSize: 10, // Minimized font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  completedItems.toString(),
                  style: TextStyle(
                    color: themeProvider.successColor,
                    fontSize: 10, // Minimized font size
                    fontWeight: FontWeight.w500,
                  ),
                    ),
                    Text(
                      pendingItems.toString(),
                      style: TextStyle(
                        color: themeProvider.warningColor,
                        fontSize: 10, // Minimized font size
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaySticker(String dayName, DateTime date, ThemeProvider themeProvider, Color backgroundColor) {
    final dayItems = _getItemsForDate(date);
    final dayNumber = date.day.toString();
    
    // Check if this is the current day
    final now = DateTime.now();
    final isCurrentDay = date.year == now.year && 
                        date.month == now.month && 
                        date.day == now.day;
    
    // Get mood emoji for this date
    final moodEmoji = _getMoodEmojiForDate(date);
    
    // Get expansion state for this specific day
    final isDayExpanded = _getDayExpansionState(dayName);
    
    // Use theme-aware background color that's more subtle in dark mode
    final themeAwareBackgroundColor = themeProvider.themeMode == ThemeMode.dark 
        ? backgroundColor.withOpacity(0.15) // Much more subtle in dark mode
        : backgroundColor;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = date;
            _selectedTimeRange = 'today';
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isCurrentDay 
                  ? Border.all(
                      color: themeProvider.shade400.withOpacity(0.6),
                      width: 2,
                    )
                  : !isDayExpanded ? Border.all(
                      color: themeProvider.shade400.withOpacity(0.3),
                      width: 1,
                    ) : null,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isDayExpanded ? 200 : 120,
              decoration: BoxDecoration(
                color: isCurrentDay 
                    ? themeAwareBackgroundColor.withOpacity(0.8) // Slightly more opaque for current day
                    : themeAwareBackgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Cute sticker icon
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _getDayIcon(dayName),
                  ),
                  // Day label in white bubble with mood emoji
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeProvider.themeMode == ThemeMode.dark 
                            ? Colors.white.withOpacity(0.2) // Much more subtle in dark mode
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (moodEmoji.isNotEmpty) ...[
                            Text(
                              moodEmoji,
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            dayName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tasks list
                  Positioned(
                    top: 40,
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dayItems.isNotEmpty) ...[
                          ...dayItems.take(3).map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeProvider.themeMode == ThemeMode.dark 
                                  ? Colors.white.withOpacity(0.1) // Much more subtle in dark mode
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name.length > 8 ? '${item.name.substring(0, 8)}...' : item.name,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                          if (dayItems.length > 3)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                              color: themeProvider.themeMode == ThemeMode.dark 
                                  ? Colors.white.withOpacity(0.1) // Much more subtle in dark mode
                                  : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                              child: Text(
                                '+${dayItems.length - 3} more',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get mood emoji for a specific date
  String _getMoodEmojiForDate(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final moodKey = _moodsByDate[dateKey];
    
    switch (moodKey) {
      case 'happy':
        return '😊';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      default:
        return '';
    }
  }

  Widget _buildNoteSticker(ThemeProvider themeProvider) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isNoteExpanded = !_isNoteExpanded;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: !_isNoteExpanded ? Border.all(
              color: themeProvider.shade400.withOpacity(0.3),
              width: 1,
            ) : null,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isNoteExpanded ? 200 : 120,
            decoration: BoxDecoration(
              color: themeProvider.themeMode == ThemeMode.dark 
                  ? const Color(0xFFE8EAF6).withOpacity(0.15) // Much more subtle in dark mode
                  : const Color(0xFFE8EAF6), // Lavender
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Cute flower icon or Save button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _isNoteExpanded
                      ? GestureDetector(
                          onTap: _saveNote,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeProvider.successColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(), // Removed cute flower emojis
                  ),
                // NOTE label in white bubble
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeProvider.themeMode == ThemeMode.dark 
                          ? Colors.white.withOpacity(0.2) // Much more subtle in dark mode
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Note',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Note content area
                Positioned(
                  top: 40,
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeProvider.themeMode == ThemeMode.dark 
                          ? Colors.white.withOpacity(0.1) // Much more subtle in dark mode
                          : Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isNoteExpanded
                        ? TextField(
                            controller: _noteController..text = _noteText,
                            onChanged: (value) {
                              setState(() {
                                _noteText = value;
                              });
                            },
                            maxLines: null,
                            expands: true,
                            textAlign: TextAlign.start,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Write your notes here...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: themeProvider.textColor.withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              alignLabelWithHint: true,
                            ),
                          )
                        : Text(
                            _noteText.isNotEmpty ? _noteText : 'Add your notes here...',
                            style: TextStyle(
                              fontSize: 10,
                              color: _noteText.isNotEmpty 
                                  ? themeProvider.textColor 
                                  : Colors.black54,
                              fontStyle: _noteText.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getDayIcon(String dayName) {
    // Return empty widget to remove all cute icons
    return const SizedBox.shrink();
  }

  // Helper method to get expansion state for a specific day
  bool _getDayExpansionState(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday':
        return _isMondayExpanded;
      case 'tuesday':
        return _isTuesdayExpanded;
      case 'wednesday':
        return _isWednesdayExpanded;
      case 'thursday':
        return _isThursdayExpanded;
      case 'friday':
        return _isFridayExpanded;
      case 'saturday':
        return _isSaturdayExpanded;
      case 'sunday':
        return _isSundayExpanded;
      default:
        return false;
    }
  }

  // Helper method to set expansion state for a specific day
  void _setDayExpansionState(String dayName, bool expanded) {
    switch (dayName.toLowerCase()) {
      case 'monday':
        _isMondayExpanded = expanded;
        break;
      case 'tuesday':
        _isTuesdayExpanded = expanded;
        break;
      case 'wednesday':
        _isWednesdayExpanded = expanded;
        break;
      case 'thursday':
        _isThursdayExpanded = expanded;
        break;
      case 'friday':
        _isFridayExpanded = expanded;
        break;
      case 'saturday':
        _isSaturdayExpanded = expanded;
        break;
      case 'sunday':
        _isSundayExpanded = expanded;
        break;
    }
  }
}

class AnimatedSnailProgressBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  const AnimatedSnailProgressBar({Key? key, required this.progress}) : super(key: key);

  @override
  State<AnimatedSnailProgressBar> createState() => _AnimatedSnailProgressBarState();
}

class _AnimatedSnailProgressBarState extends State<AnimatedSnailProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(begin: widget.progress, end: widget.progress).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant AnimatedSnailProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != _oldProgress) {
      _animation = Tween<double>(begin: _oldProgress, end: widget.progress).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.forward(from: 0);
      _oldProgress = widget.progress;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const snailSize = 80.0;
    const barHeight = 8.0;
    const barWidth = 220.0 - snailSize / 2; // Make bar shorter by half the snail size
    return SizedBox(
      width: 220.0,
      height: snailSize,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final progress = _animation.value.clamp(0.0, 1.0);
          // When progress is 1.0, move snail so half of it passes the bar
          final snailLeft = progress < 1.0
              ? (barWidth - snailSize) * progress
              : barWidth - snailSize / 2;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Thin progress bar, vertically centered
              Positioned(
                left: 0,
                top: (snailSize - barHeight) / 2,
                child: Container(
                  width: barWidth,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(barHeight),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF38C36B),
                          borderRadius: BorderRadius.circular(barHeight),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Big snail image
              Positioned(
                left: snailLeft,
                top: 0,
                child: Image.asset(
                  'assets/images/snail.png',
                  width: snailSize,
                  height: snailSize,
                ),
              ),
            ],
          );
        },
      ),
    );
  }


}

// Shopping list color
const Color shoppingListColor = Color(0xFF7C4DFF); // Deep purple

// Capitalize the first letter of each word
String _capitalizeWords(String input) {
  return input.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}

class AddPlannerItemForm extends StatefulWidget {
  final void Function(PlannerItem) onSave;
  final DateTime initialDate;
  final PlannerItem? initialItem; // Add support for editing existing items
  final int? initialType; // Add support for setting initial type
  final List<PlannerItem>? existingItems; // Add support for duplicate validation
  const AddPlannerItemForm({
    Key? key, 
    required this.onSave, 
    required this.initialDate, 
    this.initialItem,
    this.initialType,
    this.existingItems,
  }) : super(key: key);
  @override
  State<AddPlannerItemForm> createState() => _AddPlannerItemFormState();
}

class _AddPlannerItemFormState extends State<AddPlannerItemForm> {


  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  // Reminder state for routine
  bool _reminderRoutine = false;
  int _reminderOffsetRoutine = 15;
  bool _hasTime = false;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  int _duration = 0;
  final List<int> _durations = [1, 15, 30, 45, 60, 90];
  late final ScrollController _durationScrollController;
  String? _nameError;
  Recurrence? _recurrence;
  // Routine fields
  List<String> _steps = [];
  List<TextEditingController> _stepControllers = [];
  List<bool> _stepChecked = [];

  // Flag to determine if we're editing an existing item
  late bool _isEditing;
  
  // Selected emoji for user customization
  String? _selectedEmoji;
  // Track if emoji suggestions should be shown when emoji is clicked
  bool _showEmojiSuggestions = false;
  
  // Focus management for emoji suggestions
  late FocusNode _nameFocusNode;
  
  // Important task flag
  bool _isImportant = false;

  // Helper method to calculate end time correctly
  TimeOfDay _calculateEndTime(TimeOfDay startTime, int durationMinutes) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = startMinutes + durationMinutes;
    final endHour = (endMinutes ~/ 60) % 24;
    final endMinute = endMinutes % 60;
    return TimeOfDay(hour: endHour, minute: endMinute);
  }

  // Helper method to update duration based on start and end times
  void _updateDurationFromTimes() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    
    int duration;
    if (endMinutes >= startMinutes) {
      duration = endMinutes - startMinutes;
    } else {
      // Handle overnight duration (e.g., 23:00 to 01:00)
      duration = (24 * 60 - startMinutes) + endMinutes;
    }
    
    // Update duration if it's different
    if (duration != _duration) {
      setState(() {
        _duration = duration;
        // If this duration is not in the list, add it
        if (!_durations.contains(duration)) {
          _durations.add(duration);
          _durations.sort();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _durationScrollController = ScrollController();
    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        setState(() {
          _showEmojiSuggestions = false;
        });
      }
    });
    
    // Set the editing flag based on whether we have an initial item
    _isEditing = widget.initialItem != null;
    
    // If editing an existing item, populate the form
    if (widget.initialItem != null) {
      final item = widget.initialItem!;
      _nameController.text = item.name;
      _selectedEmoji = item.emoji; // Restore the selected emoji when editing
      _date = item.date;
      _isImportant = item.isImportant;
      
      // Set reminder for routine
          _reminderRoutine = item.reminder ?? false;
          _reminderOffsetRoutine = item.reminderOffset ?? 15;
      
      // Set time if available
      if (item.startTime != null) {
        _hasTime = true;
        _startTime = item.startTime!;
        
        // Calculate end time and duration
        if (item.duration != null && item.duration! > 0) {
          final startMinutes = _startTime.hour * 60 + _startTime.minute;
          final endMinutes = startMinutes + item.duration!;
          _endTime = TimeOfDay(hour: (endMinutes ~/ 60) % 24, minute: endMinutes % 60);
          _duration = item.duration!;
        } else {
          // If no duration, set a default 30-minute end time
          _endTime = TimeOfDay(hour: _startTime.hour, minute: (_startTime.minute + 30) % 60);
          _duration = 30;
        }
      } else {
        // If no start time, set default duration
          _duration = item.duration ?? 0;
      }
      
      // Set location for routine
      if (item.location != null) {
        _locationController.text = item.location!;
      }
      
      // Set steps for routine
        if (item.stepNames != null) {
          _steps = List<String>.from(item.stepNames!, growable: true);
        } else if (item.steps != null && item.steps! > 0) {
          _steps = List.filled(item.steps!, '', growable: true);
        }
        if (item.stepChecked != null && item.stepChecked!.length == _steps.length) {
          _stepChecked = List<bool>.from(item.stepChecked!, growable: true);
        } else {
          _stepChecked = List.filled(_steps.length, false, growable: true);
        }
        _stepControllers = List.generate(_steps.length, (i) => TextEditingController(text: _steps[i]));
      
      _recurrence = item.recurrence;
      
      // Position duration scroll controller to the correct duration
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final durationIndex = _durations.indexOf(_duration);
        if (durationIndex != -1) {
          _durationScrollController.animateTo(
            durationIndex * 40.0, // Assuming 40 is the item height
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    } else {
      // For new items, set current time and calculate end time
      final now = TimeOfDay.now();
      _startTime = now;
      _endTime = _calculateEndTime(now, 30);
      _duration = 30; // Set default duration for new items
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _durationScrollController.dispose();
    _nameFocusNode.dispose();
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Helper to get the current reminder value for routine
  bool get _reminder => _reminderRoutine;

  // Helper to get the current reminder offset value for routine
  int get _reminderOffset => _reminderOffsetRoutine;

  // Helper to set the current reminder value for routine
  void _setReminder(bool value) {
    setState(() {
          _reminderRoutine = value;
    });
  }

  // Helper to set the current reminder offset value for routine
  void _setReminderOffset(int value) {
    setState(() {
          _reminderOffsetRoutine = value;
    });
  }



  void _addStep() {
    setState(() {
      _steps.add('');
      _stepControllers.add(TextEditingController());
      _stepChecked.add(false);
    });
  }

  void _removeStep(int i) {
    setState(() {
      _steps.removeAt(i);
      _stepControllers[i].dispose();
      _stepControllers.removeAt(i);
      _stepChecked.removeAt(i);
    });
  }

  void _updateStep(int i, String value) {
    _steps[i] = value;
  }

  void _toggleStepChecked(int i, bool? value) {
    setState(() {
      _stepChecked[i] = value ?? false;
      
      // Check if all steps are completed and automatically mark the plan as done
      final allStepsCompleted = _stepChecked.every((checked) => checked);
      if (allStepsCompleted && _stepChecked.isNotEmpty) {
        // This will be handled when the form is saved
        // For now, we just track the state
      }
    });
  }

  // Helper function to mark all steps as completed for a routine item




  Widget _buildFields(ThemeProvider themeProvider) {
    final themeColor = themeProvider.shade400;
    return _buildRoutineFields(themeColor);
  }

  Widget _buildRoutineFields(Color themeColor) {
    return Column(
      key: const ValueKey('routine'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNameField(themeColor, 'Plan Name'),
        _buildImportantField(themeColor),
        _buildDateTimeFields(themeColor),
        _buildDurationField(themeColor),
        _buildReminderField(themeColor),
        RecurrenceSection(
          initialValue: _recurrence,
          onChanged: (r) => setState(() => _recurrence = r),
        ),
        // Add location field for routines (optional)
        _buildLocationField(themeColor),
        const SizedBox(height: 2),
        Text('Steps', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: Provider.of<ThemeProvider>(context, listen: false).textColor)),
        ...List.generate(_steps.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Checkbox(
                value: _stepChecked.length > i ? _stepChecked[i] : false,
                activeColor: themeColor,
                onChanged: (v) => _toggleStepChecked(i, v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Expanded(
                child: TextField(
                  controller: _stepControllers[i],
                  style: TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Step ${i + 1}',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => _updateStep(i, v),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 16, color: Provider.of<ThemeProvider>(context, listen: false).errorColor),
                onPressed: () => _removeStep(i),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addStep,
            icon: Icon(Icons.add, size: 16, color: themeColor),
            label: Text('Add Step', style: TextStyle(color: Provider.of<ThemeProvider>(context, listen: false).textColor, fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportantField(Color themeColor) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isImportant = !_isImportant;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  _isImportant ? Icons.star : Icons.star_border,
                  size: 20,
                  color: _isImportant ? Colors.amber : themeProvider.textColorSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Mark as Important',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isImportant ? Colors.amber : themeProvider.textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameField(Color themeColor, String label) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmojiSuggestions = !_showEmojiSuggestions;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _showEmojiSuggestions 
                          ? themeProvider.shade400.withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _showEmojiSuggestions 
                            ? themeProvider.shade400.withOpacity(0.3)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                  _selectedEmoji ?? EmojiService.getEmojiForName(_nameController.text), 
                  style: const TextStyle(fontSize: 24)
                    ),
                  ),
                ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _nameController,
                    focusNode: _nameFocusNode,
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: themeProvider.textColor),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: themeColor, fontSize: 13, fontWeight: FontWeight.w400),
              border: const UnderlineInputBorder(),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeColor)),
              errorText: _nameError,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (_) => setState(() {
              _nameError = null;
                      // Reset selected emoji when text changes
                      _selectedEmoji = null;
                      _showEmojiSuggestions = false; // Hide emoji suggestions when text changes
            }),
          ),
                ),
              ],
            ),
            EmojiSuggestions(
              text: _nameController.text,
              onEmojiSelected: (emoji) {
                setState(() {
                  _selectedEmoji = emoji;
                  _showEmojiSuggestions = false; // Hide suggestions after selection
                });
              },
              themeProvider: themeProvider,
              isFocused: _nameFocusNode.hasFocus || _showEmojiSuggestions,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateTimeFields(Color themeColor) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
                Text('When?', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: themeProvider.textColor)),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: themeProvider.shade400,
                          onPrimary: Colors.white,
                          surface: themeProvider.cardColor,
                          onSurface: themeProvider.textColor,
                          secondary: themeProvider.shade100,
                          onSecondary: themeProvider.shade700,
                        ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: themeProvider.cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: themeProvider.shade400,
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Text(
                '${_date.month}/${_date.day}/${_date.year.toString().substring(2)}',
                style: TextStyle(color: themeProvider.shade400, fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Set Time', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: themeProvider.textColor)),
                            Transform.scale(
                  scale: 0.7,
                  child: Switch(
              value: _hasTime,
                    activeColor: themeProvider.shade400,
                    onChanged: (v) {
                      setState(() {
                        _hasTime = v;
                        if (v) {
                          // When time is enabled, set default 30-minute duration
                          if (_duration == 0) {
                            _duration = 30;
                            _endTime = _calculateEndTime(_startTime, 30);
                          } else {
                            _updateDurationFromTimes();
                          }
                        } else {
                          // When time is disabled, clear duration completely
                          _duration = 0;
                          _endTime = _startTime;
                        }
                      });
                    },
                  ),
            ),
          ],
        ),
        if (_hasTime) ...[
          const SizedBox(height: 4),
          Row(
              children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From', style: TextStyle(fontSize: 11, color: themeProvider.textColorSecondary, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(
                                  primary: themeProvider.shade400,
                                  onPrimary: Colors.white,
                                  surface: themeProvider.cardColor,
                                  onSurface: themeProvider.textColor,
                                  secondary: themeProvider.shade100,
                                  onSecondary: themeProvider.shade700,
                                ),
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: themeProvider.cardColor,
                                  hourMinuteTextColor: themeProvider.textColor,
                                  hourMinuteColor: themeProvider.shade100,
                                  hourMinuteTextStyle: TextStyle(
                                    color: themeProvider.shade700,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  dayPeriodTextColor: themeProvider.textColor,
                                  dayPeriodColor: themeProvider.shade100,
                                  dayPeriodTextStyle: TextStyle(
                                    color: themeProvider.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  dialHandColor: themeProvider.shade400,
                                  dialBackgroundColor: themeProvider.dividerColor,
                                  dialTextColor: themeProvider.textColor,
                                  entryModeIconColor: themeProvider.textColorSecondary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _startTime = picked;
                            // Update end time based on current duration
                            if (_duration > 0) {
                              _endTime = _calculateEndTime(picked, _duration);
                            } else {
                              // If no duration set, default to 30 minutes
                              _endTime = _calculateEndTime(picked, 30);
                              _duration = 30;
                            }
                          });
                        }
                      },
                  child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                          color: themeProvider.dividerColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: themeProvider.dividerColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _startTime.format(context),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: themeProvider.textColor),
                            ),
                            Icon(Icons.access_time, size: 14, color: themeProvider.shade400),
                      ],
                    ),
                  ),
                ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('To', style: TextStyle(fontSize: 11, color: themeProvider.textColorSecondary, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(
                                  primary: themeProvider.shade400,
                                  onPrimary: Colors.white,
                                  surface: themeProvider.cardColor,
                                  onSurface: themeProvider.textColor,
                                  secondary: themeProvider.shade100,
                                  onSecondary: themeProvider.shade700,
                                ),
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: themeProvider.cardColor,
                                  hourMinuteTextColor: themeProvider.textColor,
                                  hourMinuteColor: themeProvider.shade100,
                                  hourMinuteTextStyle: TextStyle(
                                    color: themeProvider.shade700,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  dayPeriodTextColor: themeProvider.textColor,
                                  dayPeriodColor: themeProvider.shade100,
                                  dayPeriodTextStyle: TextStyle(
                                    color: themeProvider.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  dialHandColor: themeProvider.shade400,
                                  dialBackgroundColor: themeProvider.dividerColor,
                                  dialTextColor: themeProvider.textColor,
                                  entryModeIconColor: themeProvider.textColorSecondary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                      setState(() {
                            _endTime = picked;
                            // Ensure end time is after start time
                            if (_endTime.hour * 60 + _endTime.minute <= _startTime.hour * 60 + _startTime.minute) {
                              _startTime = TimeOfDay(
                                hour: _endTime.hour,
                                minute: (_endTime.minute - 30 + 60) % 60,
                              );
                            }
                            // Update duration based on start and end times
                            _updateDurationFromTimes();
                          });
                        }
                      },
                            child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeProvider.dividerColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: themeProvider.dividerColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _endTime.format(context),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: themeProvider.textColor),
                            ),
                            Icon(Icons.access_time, size: 14, color: themeProvider.shade400),
                          ],
                    ),
                  ),
                ),
              ],
            ),
              ),
            ],
          ),
        ],
      ],
    );
      },
    );
  }

  Widget _buildDurationField(Color themeColor) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return Opacity(
      opacity: _hasTime ? 1.0 : 0.5,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            const SizedBox(height: 2),
        Row(
          children: [
                Text('Duration', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: themeProvider.textColor)),
            const Spacer(),
            TextButton(
              onPressed: _hasTime ? () async {
                    final custom = await showCustomDurationDialog(context, themeColor: themeProvider.shade400);
                if (custom != null && !_durations.contains(custom)) {
                  setState(() {
                    _durations.add(custom);
                    _durations.sort();
                    _duration = custom;
                    // Update end time based on new duration
                    if (_hasTime && custom > 0) {
                      _endTime = _calculateEndTime(_startTime, custom);
                    }
                  });
                  // Scroll to the custom duration
                  final idx = _durations.indexOf(custom);
                  await Future.delayed(const Duration(milliseconds: 50));
                  _durationScrollController.animateTo(
                    idx * 60.0, // Reduced chip width + spacing
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else if (custom != null) {
                  setState(() {
                    _duration = custom;
                    // Update end time based on new duration
                    if (_hasTime && custom > 0) {
                      _endTime = _calculateEndTime(_startTime, custom);
                    }
                  });
                  final idx = _durations.indexOf(custom);
                  await Future.delayed(const Duration(milliseconds: 50));
                  _durationScrollController.animateTo(
                    idx * 60.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              } : null,
              style: TextButton.styleFrom(
                foregroundColor: _hasTime ? themeProvider.shade400 : themeProvider.textColorSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              child: Text('More', style: TextStyle(fontSize: 12, color: _hasTime ? themeProvider.shade400 : themeProvider.textColorSecondary)),
            ),
          ],
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            controller: _durationScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _durations.length,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final d = _durations[i];
              final selected = _hasTime && _duration == d;
              return ChoiceChip(
                label: Text(
                  d == 0 ? 'None' : d < 60 ? '${d}m' : d % 60 == 0 ? '${d ~/ 60}h' : '${d ~/ 60}h${d % 60}m',
                  style: TextStyle(color: selected ? themeProvider.cardColor : themeProvider.textColor, fontSize: 12),
                ),
                selected: selected,
                selectedColor: themeColor,
                onSelected: _hasTime ? (_) {
                  setState(() {
                    _duration = d;
                    // Update end time based on new duration
                    if (_hasTime && d > 0) {
                      _endTime = _calculateEndTime(_startTime, d);
                    }
                  });
                } : null,
                showCheckmark: false,
              );
            },
          ),
        ),
      ],
    ),
    );
      },
    );
  }

  Widget _buildReminderField(Color themeColor) {
    const reminderOptions = [5, 10, 15, 30, 60, 120]; // minutes before
    
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Opacity(
          opacity: _hasTime ? 1.0 : 0.5,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Text('Reminder', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: themeProvider.textColor)),
                const Spacer(),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
      value: _reminder,
                    activeColor: themeProvider.shade400,
                      onChanged: _hasTime ? (val) => _setReminder(val) : null,
                  ),
                ),
              ],
            ),
              if (_reminder && _hasTime) ...[
          const SizedBox(height: 2),
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: themeProvider.dividerColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: themeProvider.dividerColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _reminderOffset,
                icon: Icon(Icons.keyboard_arrow_down, size: 14, color: themeProvider.shade400),
                style: TextStyle(fontSize: 12, color: themeProvider.textColor),
                isExpanded: true,
                  items: reminderOptions.map((minutes) {
                    String label;
                    if (minutes < 60) {
                      label = '${minutes}m before';
                    } else if (minutes == 60) {
                      label = '1h before';
                    } else {
                      label = '${minutes ~/ 60}h before';
                    }
                    return DropdownMenuItem<int>(
                      value: minutes,
                      child: Text(label, style: TextStyle(color: themeProvider.textColor, fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _setReminderOffset(value);
                    }
                  },
                ),
              ),
            ),
        ],
      ],
          ),
    );
      },
    );
  }

  Widget _buildLocationField(Color themeColor) {
    // Show for routine
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return Row(
      children: [
            Icon(Icons.location_on, color: themeProvider.successColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _locationController,
                style: TextStyle(fontSize: 14, color: themeProvider.textColor),
                decoration: InputDecoration(
                  labelText: 'Enter a location (optional)',
                  labelStyle: TextStyle(color: themeProvider.shade400, fontSize: 12, fontWeight: FontWeight.w400),
              border: InputBorder.none,
                  hintText: 'e.g., Conference Room A, Coffee Shop',
                  hintStyle: TextStyle(color: themeProvider.textColorSecondary, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ],
        );
      },
    );
  }

  // Check for time overlap with existing plans
  List<PlannerItem> _checkTimeOverlap() {
    if (!_hasTime || widget.existingItems == null) return [];
    
    final targetDate = DateTime(_date.year, _date.month, _date.day);
    final newStartMinutes = _startTime.hour * 60 + _startTime.minute;
    final newEndMinutes = newStartMinutes + _duration;
    
    return widget.existingItems!.where((item) {
      // Check if item is on the same date
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      if (!itemDate.isAtSameMomentAs(targetDate)) return false;
      
      // Skip completed plans - they don't cause conflicts
      if (item.done) return false;
      
      // Check if item has time set
      if (item.startTime == null || item.duration == null) return false;
      
      // Calculate item's time range
      final itemStartMinutes = item.startTime!.hour * 60 + item.startTime!.minute;
      final itemEndMinutes = itemStartMinutes + item.duration!;
      
      // Check for overlap (new plan overlaps with existing plan)
      return (newStartMinutes < itemEndMinutes && newEndMinutes > itemStartMinutes);
    }).toList();
  }

  // Show time conflict dialog
  void _showTimeConflictDialog(List<PlannerItem> overlappingItems) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Time Conflict',
              style: TextStyle(
                color: themeProvider.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ Time conflict: Another plan exists during this time range.',
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            if (overlappingItems.isNotEmpty) ...[
              Text(
                'Overlapping plans:',
                style: TextStyle(
                  color: themeProvider.textColorSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...overlappingItems.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeProvider.shade400.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: themeProvider.shade400.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          if (item.startTime != null && item.duration != null)
                            Text(
                              '${item.startTime!.format(context)} - ${_calculateEndTime(item.startTime!, item.duration!).format(context)}',
                              style: TextStyle(
                                color: themeProvider.textColorSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: themeProvider.textColorSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement view overlapping plan functionality
              // This would typically navigate to the plan or highlight it
            },
            child: Text(
              'View overlapping plan',
              style: TextStyle(color: themeProvider.shade400),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.shade400,
              foregroundColor: themeProvider.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              // Continue with saving despite overlap
              _saveWithOverlap();
            },
            child: const Text('Continue anyway'),
          ),
        ],
      ),
    );
  }

  // Save the plan even with time overlap
  void _saveWithOverlap() {
    _steps = _stepControllers.map((c) => c.text).toList();
    final allStepsCompleted = _stepChecked.isNotEmpty && _stepChecked.every((checked) => checked);
    final finalDoneStatus = allStepsCompleted; // Plan completion is always derived from step completion
    
    final item = PlannerItem(
      id: widget.initialItem?.id,
      name: _nameController.text.trim(),
              emoji: _selectedEmoji ?? EmojiService.getEmojiForName(_nameController.text.trim()),
      date: _date,
      startTime: _hasTime ? _startTime : null,
      duration: _hasTime && _duration > 0 ? _duration : null,
      done: finalDoneStatus,
      type: 'routine',
      steps: _steps.length,
      stepsDone: _stepChecked.where((c) => c).length,
      reminder: _reminderRoutine,
      reminderOffset: _reminderRoutine ? _reminderOffsetRoutine : null,
      stepNames: List<String>.from(_steps),
      stepChecked: List<bool>.from(_stepChecked),
      recurrence: _recurrence,
      location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
    );
    
    widget.onSave(item);
    Navigator.of(context).pop();
  }

  void _onSave() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Enter a name');
      return;
    }

    // Check for duplicate plan names on the same date
    if (widget.existingItems != null && !_isEditing) {
      final planName = _nameController.text.trim();
      final targetDate = DateTime(_date.year, _date.month, _date.day);
      
      final duplicateExists = widget.existingItems!.any((item) {
        final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
        return item.name.toLowerCase() == planName.toLowerCase() && 
               itemDate.isAtSameMomentAs(targetDate) &&
               item.id != widget.initialItem?.id; // Exclude current item when editing
      });
      
      if (duplicateExists) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('A plan already exists for this date. Please rename it.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: themeProvider.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Check for time overlap if time is set
    if (_hasTime && widget.existingItems != null && !_isEditing) {
      final overlappingItems = _checkTimeOverlap();
      if (overlappingItems.isNotEmpty) {
        _showTimeConflictDialog(overlappingItems);
        return;
      }
    }

    // Only allow routine creation
    final type = 'routine';
    PlannerItem item;
    // Preserve the original done status and ID when editing
    final isEditing = widget.initialItem != null;
    final originalDone = isEditing ? widget.initialItem!.done : false;
    final originalId = isEditing ? widget.initialItem!.id : null;
    
      _steps = _stepControllers.map((c) => c.text).toList();
      // Check if all steps are completed to automatically mark the plan as done
      final allStepsCompleted = _stepChecked.isNotEmpty && _stepChecked.every((checked) => checked);
      final finalDoneStatus = allStepsCompleted; // Plan completion is always derived from step completion
      
      item = PlannerItem(
        id: originalId, // Preserve original ID when editing
        name: _nameController.text.trim(),
        emoji: _selectedEmoji ?? EmojiService.getEmojiForName(_nameController.text.trim()),
        date: _date,
        startTime: _hasTime ? _startTime : null,
        duration: _hasTime && _duration > 0 ? _duration : null,
        done: finalDoneStatus,
        type: 'routine',
        steps: _steps.length,
        stepsDone: _stepChecked.where((c) => c).length,
        reminder: _reminderRoutine,
        reminderOffset: _reminderRoutine ? _reminderOffsetRoutine : null,
        stepNames: List<String>.from(_steps),
        stepChecked: List<bool>.from(_stepChecked),
        recurrence: _recurrence,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        isImportant: _isImportant,
    );
    widget.onSave(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final themeColor = themeProvider.shade300;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final dialogWidth = isTablet ? 450.0 : (screenWidth * 0.9).clamp(320.0, 400.0);
    
    return Dialog(
      backgroundColor: themeProvider.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16, 
            isTablet ? 24 : 16, 
            isTablet ? 24 : 16, 
            12
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFields(themeProvider),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isEditing)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          backgroundColor: themeColor,
                          foregroundColor: themeProvider.cardColor,
                          elevation: 2,
                          shadowColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        onPressed: () {
                          try {
                            print('UP button pressed - starting comprehensive update');
                            
                            // 1. Null Safety Checks
                            if (widget.initialItem == null) {
                              print('UP button error: No initial item found');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error: No item to update'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            if (_nameController.text.trim().isEmpty) {
                              print('UP button error: Name is empty');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid name'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            
                            print('UP button: Validating form data for item: ${widget.initialItem!.name}');
                            
                            // 2. Gather all form data with validation
                            final newName = _nameController.text.trim();
                            final newDate = _date;
                            final newHasTime = _hasTime;
                            final newStartTime = _hasTime ? _startTime : null;
                            final newDuration = _duration == 0 ? null : _duration;
                            final newReminder = _reminderRoutine;
                            final newReminderOffset = _reminderRoutine ? _reminderOffsetRoutine : null;
                            final newLocation = _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null;
                            final newRecurrence = _recurrence;
                            
                            // 3. Process steps data
                            final newSteps = _stepControllers.map((c) => c.text.trim()).toList();
                            final newStepsDone = _stepChecked.where((c) => c).length;
                            
                            // Check if all steps are completed to automatically mark the plan as done
                            final allStepsCompleted = _stepChecked.isNotEmpty && _stepChecked.every((checked) => checked);
                            final finalDoneStatus = allStepsCompleted; // Plan completion is always derived from step completion
                            
                            print('UP button: Form data gathered - Name: $newName, Date: $newDate, HasTime: $newHasTime, Steps: ${newSteps.length}');
                            
                            // 4. Create comprehensive updated item
                            final updatedItem = PlannerItem(
                              id: widget.initialItem!.id,
                              name: newName,
                              emoji: _selectedEmoji ?? EmojiService.getEmojiForName(newName), // Use selected emoji or regenerate based on new name
                              date: newDate,
                              startTime: newStartTime,
                              duration: _hasTime && (newDuration ?? 0) > 0 ? newDuration : null,
                              done: finalDoneStatus, // Auto-complete if all steps are done
                              type: widget.initialItem!.type,
                              steps: newSteps.length,
                              stepsDone: newStepsDone,
                              reminder: newReminder,
                              reminderOffset: newReminderOffset,
                              stepNames: List<String>.from(newSteps),
                              stepChecked: List<bool>.from(_stepChecked),
                              recurrence: newRecurrence,
                              location: newLocation,
                              isImportant: _isImportant,
                            );
                            
                            print('UP button: Created comprehensive updated item: ${updatedItem.name}');
                            print('UP button: Item details - Date: ${updatedItem.date}, Time: ${updatedItem.startTime}, Duration: ${updatedItem.duration}, Steps: ${updatedItem.steps}');
                            
                            // 5. Call onSave callback with null safety
                            if (widget.onSave != null) {
                              print('UP button: Calling onSave callback');
                              widget.onSave(updatedItem);
                              print('UP button: onSave callback completed successfully');
                            } else {
                              print('UP button error: onSave callback is null');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error: Save callback not available'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            // 6. Close dialog with safety check
                            if (Navigator.canPop(context)) {
                              print('UP button: Closing dialog');
                              Navigator.of(context).pop();
                              print('UP button: Dialog closed successfully');
                            } else {
                              print('UP button warning: Cannot pop navigator');
                            }
                            
                            print('UP button: Comprehensive update completed successfully');
                            
                          } catch (e) {
                            print('UP button error: Exception occurred: $e');
                            print('UP button error: Stack trace: ${StackTrace.current}');
                            
                            // Show detailed error message to user
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating item: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        },
                        child: const Text('Update'),
                      )
                    else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        backgroundColor: themeProvider.shade400,
                        foregroundColor: themeProvider.cardColor,
                        elevation: 2,
                        shadowColor: themeProvider.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                      onPressed: _onSave,
                        child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }




}

class _AnimatedFlashRow extends StatefulWidget {
  final bool flash;
  final Widget child;
  const _AnimatedFlashRow({Key? key, required this.flash, required this.child}) : super(key: key);

  @override
  State<_AnimatedFlashRow> createState() => _AnimatedFlashRowState();
}

class _AnimatedFlashRowState extends State<_AnimatedFlashRow> {
  Color get _flashColor => widget.flash ? Provider.of<ThemeProvider>(context, listen: false).dividerColor : Colors.transparent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _flashColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: widget.child,
    );
  }
} 

 

  String _getLogoForTheme(ThemeProvider themeProvider) {
    // Get the current theme color and mode to map it to the appropriate logo
    final currentColor = themeProvider.selectedThemeColor;
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final modeSuffix = isDarkMode ? 'dark' : 'light';
    
    if (currentColor == Colors.teal) {
      return 'assets/images/daily quest planner_teal_${modeSuffix}logo.png';
    } else if (currentColor == Colors.pink) {
      return 'assets/images/daily quest planner_pink_${modeSuffix}logo.png';
    } else if (currentColor == CustomMaterialColor.burgundy) {
      return 'assets/images/daily quest planner_burgundy_${modeSuffix}logo.png';
    } else if (currentColor == CustomMaterialColor.slate) {
      return 'assets/images/daily quest planner_slate_${modeSuffix}logo.png';
      } else {
      // Default fallback
      return 'assets/images/daily quest planner_teal_${modeSuffix}logo.png';
    }
} 

