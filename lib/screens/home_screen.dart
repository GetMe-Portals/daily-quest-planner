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
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_theme.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';

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
  GlobalKey<AnimatedListState> _incompleteListKey = GlobalKey<AnimatedListState>();
  GlobalKey<AnimatedListState> _completedListKey = GlobalKey<AnimatedListState>();
  String? _flashKey;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceCommand = '';
  bool _showMicFab = false;
  double _soundLevel = 0.0;
  Map<String, String> _moodsByDate = {};
  late ConfettiController _confettiController;
  bool _showCompletionMessage = false;
  double _lastProgress = 0.0;
  Set<String> _expandedDays = {}; // Track which days are expanded
  bool _isNoteExpanded = false; // Track if note is expanded
  String _noteText = ''; // Store the note text
  late TextEditingController _noteController; // Persistent controller for note text field
  
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
    _speech = stt.SpeechToText();
    _loadMoods();
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

  void _showContextAwareAddForm() {
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
              initialDate: _selectedDate,
              initialType: initialType, // Pass the context-aware initial type
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

  Future<bool> _checkMicPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  void _handleVoiceCommand(String command) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final lower = command.toLowerCase().trim();
    // Accept both "add task" and "ad task" (common misrecognition)
    final addTaskPattern = RegExp(r'^(add|ad) task (.+) 0?$', caseSensitive: false);
    final match = addTaskPattern.firstMatch(lower);
    if (match != null) {
      final name = match.group(2)!.trim();
      if (name.isNotEmpty) {
        final newTask = PlannerItem(
          name: name,
          emoji: '📝',
          date: DateTime.now(),
          done: false,
          type: 'task',
        );
        setState(() {
          _plannerItems.add(newTask);
        });
        PlannerStorage.save(_plannerItems);
        
        // Note: Voice-created tasks don't have reminders by default
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "$name" added!'),
            backgroundColor: themeProvider.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    // If no command recognized
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No valid command recognized.'),
        backgroundColor: themeProvider.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
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

  void _onMoodSelected(int? moodIndex, String emoji) {
    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    setState(() {
      if (moodIndex == null) {
        _moodsByDate.remove(key);
      } else {
        _moodsByDate[key] = emoji;
      }
    });
    _saveMoods();
  }

  void _checkForCompletion(double progress) {
    if (progress == 1.0 && _lastProgress < 1.0) {
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
    } else if (progress < 1.0 && _lastProgress == 1.0) {
      setState(() {
        _showCompletionMessage = false;
      });
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
                                        // Set time range based on selected date
                                        final today = DateTime.now();
                                        final isToday = date.year == today.year && 
                                                       date.month == today.month && 
                                                       date.day == today.day;
                                        if (isToday) {
                                          _selectedTimeRange = 'today';
                                        } else {
                                          _selectedTimeRange = 'custom';
                                        }
                                      });
                                    },
                                    onPageChanged: (date) {
                                      setState(() {
                                        _selectedDate = date;
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
                        selectedMood: _moodsByDate[DateFormat('yyyy-MM-dd').format(_selectedDate)],
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
                                      child: _buildCompactTimeRangeSelector(themeProvider),
                                    ),
                                  ),
                                  // Type Filter Tabs removed
                      _buildPlannerItemsForDate(_selectedDate, themeProvider),
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
          bottomSheet: _voiceCommand.isNotEmpty && !_isListening
              ? Container(
                  color: themeProvider.cardColor,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: Text('Heard: "$_voiceCommand"', style: TextStyle(fontSize: 16, color: themeProvider.textColor)),
                )
              : null,
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
                  'assets/images/daily_quest_logo.png',
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
    final startOfWeek = _getStartOfWeek(_focusedDay);
    final endOfWeek = _getEndOfWeek(_focusedDay);
    
    // Get items for the week
    final weekItems = <PlannerItem>[];
    DateTime currentDate = startOfWeek;
    while (currentDate.isBefore(endOfWeek.add(const Duration(days: 1)))) {
                  final dayItems = _getItemsForDate(currentDate);
      weekItems.addAll(dayItems);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Calculate week statistics
    final totalItems = weekItems.length;
    final completedItems = weekItems.where((item) => item.done).length;
    final progress = totalItems > 0 ? completedItems / totalItems : 0.0;
    
    return Column(
        children: [
        // Week navigation header
        _buildWeekNavigation(_focusedDay, themeProvider),
          const SizedBox(height: 16),

        // Cute sticker-style weekly grid
          Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
              // Row 1: Monday, Tuesday, Wednesday
                Row(
                  children: [
                  _buildDaySticker('Monday', startOfWeek.add(const Duration(days: 0)), themeProvider, const Color(0xFFE8EAF6)), // Lavender
                  const SizedBox(width: 12),
                  _buildDaySticker('Tuesday', startOfWeek.add(const Duration(days: 1)), themeProvider, const Color(0xFFFFF3E0)), // Peach
                  const SizedBox(width: 12),
                  _buildDaySticker('Wednesday', startOfWeek.add(const Duration(days: 2)), themeProvider, const Color(0xFFE8EAF6)), // Lavender
                ],
              ),
              const SizedBox(height: 12),
              
              // Row 2: Thursday, Friday, Saturday
              Row(
                                children: [
                  _buildDaySticker('Thursday', startOfWeek.add(const Duration(days: 3)), themeProvider, const Color(0xFFFFF3E0)), // Peach
                  const SizedBox(width: 12),
                  _buildDaySticker('Friday', startOfWeek.add(const Duration(days: 4)), themeProvider, const Color(0xFFFFE0B2)), // Soft Orange
                  const SizedBox(width: 12),
                  _buildDaySticker('Saturday', startOfWeek.add(const Duration(days: 5)), themeProvider, const Color(0xFFFFF3E0)), // Peach
                ],
              ),
              const SizedBox(height: 12),
              
              // Row 3: Sunday, NOTE
              Row(
                    children: [
                  Expanded(
                    child: _buildDaySticker('Sunday', startOfWeek.add(const Duration(days: 6)), themeProvider, const Color(0xFFFFE0B2)), // Soft Orange
                  ),
                  const SizedBox(width: 12),
                      Expanded(
                    flex: 2, // Make Note box twice as wide as weekday boxes
                    child: _buildNoteSticker(themeProvider),
                  ),
                ],
                ),
              ],
            ),
          ),
          
        const SizedBox(height: 16),
        
        // Week summary (kept as is)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: themeProvider.shadowColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week Summary',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildSummaryCard('Total', totalItems.toString(), themeProvider.shade400, themeProvider),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Completed', completedItems.toString(), themeProvider.successColor, themeProvider),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Pending', '${(progress * 100).toInt()}%', themeProvider.warningColor, themeProvider),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    // Get items for the month
    final monthItems = _getItemsForTimeRange(baseDate);
    
    // Calculate month statistics
    final totalItems = monthItems.length;
    final completedItems = monthItems.where((item) => item.done).length;
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
                color: themeProvider.shadowColor.withOpacity(0.1),
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
                style: TextStyle(
                  color: themeProvider.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildSummaryCard('Total', totalItems.toString(), themeProvider.shade400, themeProvider),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Completed', completedItems.toString(), themeProvider.successColor, themeProvider),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Pending', pendingItems.toString(), themeProvider.warningColor, themeProvider),
                ],
              ),
            ],
          ),
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
                color: themeProvider.shadowColor.withOpacity(0.1),
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
                style: TextStyle(
                  color: themeProvider.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildSummaryCard('Total', totalItems.toString(), themeProvider.shade400, themeProvider),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Completed', completedItems.toString(), themeProvider.successColor, themeProvider),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Pending', pendingItems.toString(), themeProvider.warningColor, themeProvider),
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
                fontSize: 16,
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
                fontSize: 16,
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
                    height: 60,
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
              final dayItems = _getItemsForDate(currentDate);
              
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = currentDate;
                      _selectedTimeRange = 'today';
                    });
                  },
                  child: Container(
                    height: 60,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isToday ? themeProvider.shade400.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday ? themeProvider.shade400.withOpacity(0.3) : themeProvider.dividerColor.withOpacity(0.3),
                        width: isToday ? 2 : 1,
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
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? themeProvider.shade700 : themeProvider.textColor,
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
    final typeEmoji = _getTypeEmoji(item.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: typeColor.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            typeEmoji,
            style: TextStyle(fontSize: 7),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: Text(
              item.name.length > 6 ? '${item.name.substring(0, 6)}...' : item.name,
              style: TextStyle(
                fontSize: 7,
                color: typeColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarItemsWithOverflow(List<PlannerItem> items, ThemeProvider themeProvider) {
    // Calculate available space for items (cell height - date number - padding)
    // Cell height: 60px, date number: ~12px, padding: 4px, spacing: 1px
    // Available space: ~43px for items
    const double itemHeight = 8.0; // Height of each item preview
    const double itemSpacing = 1.0; // Spacing between items
    const double overflowIndicatorHeight = 8.0; // Height of "+n more" indicator
    
    // Calculate how many items can fit
    int maxVisibleItems = 0;
    double currentHeight = 0;
    
    for (int i = 0; i < items.length; i++) {
      double nextHeight = currentHeight + itemHeight + (i > 0 ? itemSpacing : 0);
      
      // If adding this item would exceed available space, stop
      if (nextHeight > 43) {
        break;
      }
      
      // If this is the last item or adding one more would exceed space, check if we need overflow indicator
      if (i == items.length - 1 || nextHeight + itemHeight + itemSpacing + overflowIndicatorHeight > 43) {
        maxVisibleItems = i + 1;
        break;
      }
      
      currentHeight = nextHeight;
      maxVisibleItems = i + 1;
    }
    
    // Build the visible items
    final visibleItems = items.take(maxVisibleItems).toList();
    final hiddenItems = items.skip(maxVisibleItems).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleItems.map((item) => _buildCalendarItemPreview(item, themeProvider)),
        if (hiddenItems.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: themeProvider.dividerColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${hiddenItems.length} more',
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
      return EmptyStateWidget(timeRange: _selectedTimeRange);
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
          _buildCompactTimeRangeTab('today', 'T', 'Today', themeProvider),
          _buildCompactTimeRangeTab('weekly', 'W', 'Weekly', themeProvider),
          _buildCompactTimeRangeTab('monthly', 'M', 'Monthly', themeProvider),
          _buildCompactTimeRangeTab('yearly', 'Y', 'Yearly', themeProvider),
        ],
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
            // Reset to today when "T" is tapped
            _selectedDate = DateTime.now();
            _selectedTimeRange = 'today';
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
          borderRadius: BorderRadius.circular(20),
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
        return Colors.blue;
      case 'event':
        return Colors.green;
      case 'shopping':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPlannerItemRow(PlannerItem item, VoidCallback onToggle, ThemeProvider themeProvider, {bool flash = false}) {
    final start = item.startTime;
    final duration = item.duration ?? 0;
    final end = start == null ? null : TimeOfDay(
      hour: (start.hour + ((start.minute + duration) ~/ 60)) % 24,
      minute: (start.minute + duration) % 60,
    );
    final typeColor = _getTypeColor(item.type, themeProvider);
    String durationLabel = '';
    if (duration > 0) {
      if (duration % 60 == 0) {
        durationLabel = '${duration ~/ 60}h';
      } else if (duration > 60) {
        durationLabel = '${duration ~/ 60}h${duration % 60}m';
      } else {
        durationLabel = '${duration}m';
      }
    }
          return _AnimatedFlashRow(
        flash: flash,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          decoration: BoxDecoration(
            border: Border.all(
              color: themeProvider.dividerColor.withOpacity(0.05),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: themeProvider.dividerColor.withOpacity(0.05), // Made very light transparent gray
                borderRadius: BorderRadius.circular(8), // Changed from circle to rounded rectangle
              ),
              child: Center(
                child: item.type == 'shopping'
                    ? Icon(Icons.shopping_cart_outlined, color: typeColor, size: 20)
                    : Text(item.emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _capitalizeWords(item.name),
                          style: GoogleFonts.dancingScript(
                            textStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              decoration: item.done ? TextDecoration.lineThrough : null,
                              color: item.done ? themeProvider.textColorSecondary : themeProvider.textColor,
                              ),
                            ),
                          ),
                      ),
                      if (durationLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(durationLabel, style: TextStyle(fontSize: 12, color: themeProvider.shade400, fontWeight: FontWeight.w600)),
                        ),
                      // Show recurrence indicator
                      if (item.recurrence != null && 
                          (item.recurrence!.patterns.isNotEmpty || 
                           (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty)))
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.repeat, size: 16, color: themeProvider.infoColor),
                          ),
                        ],
                      ),
                  if (start != null)
                    Row(
                      children: [
                        Text(
                          start.format(context),
                          style: TextStyle(fontSize: 12, color: themeProvider.textColorSecondary),
                        ),
                        if (end != null) ...[
                          const SizedBox(width: 6),
                          Text('-', style: TextStyle(fontSize: 12, color: themeProvider.textColorSecondary)),
                          const SizedBox(width: 2),
                          Text(
                            end.format(context),
                            style: TextStyle(fontSize: 12, color: themeProvider.textColorSecondary),
                          ),
                        ],
                      ],
                    ),
                  if (item.type == 'routine' && item.steps != null && item.steps! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${item.stepsDone ?? 0} of ${item.steps} steps',
                        style: TextStyle(fontSize: 12, color: themeProvider.infoColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: item.done
                  ? SunCheckbox(size: 22)
                  : Icon(Icons.radio_button_unchecked, color: themeProvider.textColorSecondary, size: 22),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
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
    setState(() {
      item.done = !item.done;
      
      // If marking as completed and it's a routine with steps, mark all steps as completed
      if (item.done && item.type == 'routine' && item.stepChecked != null && item.stepChecked!.isNotEmpty) {
        item.stepChecked = List.filled(item.stepChecked!.length, true);
        item.stepsDone = item.stepChecked!.length;
      }
      
      PlannerStorage.save(_plannerItems);
    });
    
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
    
    // Handle recurring tasks
    PlannerItem? originalItem;
    if (item.recurrence != null && 
        (item.recurrence!.patterns.isNotEmpty || 
         (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty))) {
      // Find the original recurring task
      originalItem = _plannerItems.firstWhere(
        (original) => original.recurrence != null && 
                     (original.recurrence!.patterns.isNotEmpty || 
                      (original.recurrence!.customRules != null && original.recurrence!.customRules!.isNotEmpty)) &&
                     original.name == item.name &&
                     original.type == item.type &&
                     original.date.isBefore(item.date),
        orElse: () => item,
      );
    }
    
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
        
        // Update original item if this is a recurring task
        if (originalItem != null && originalItem != item) {
          originalItem.done = true;
          // Also update steps for the original item if it's a routine
          if (originalItem.type == 'routine' && originalItem.stepChecked != null && originalItem.stepChecked!.isNotEmpty) {
            originalItem.stepChecked = List.filled(originalItem.stepChecked!.length, true);
            originalItem.stepsDone = originalItem.stepChecked!.length;
          }
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
        
        // When unmarking as completed, we don't automatically uncheck steps
        // The user can manually manage individual step completion
        
        // Update original item if this is a recurring task
        if (originalItem != null && originalItem != item) {
          originalItem.done = false;
        }
        // Insert into incomplete after a short delay
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            _incompleteListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 350));
          });
        });
      }
      PlannerStorage.save(_plannerItems);
    });
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
    final monthItems = _getItemsForTimeRange(monthStart);
    
    // Calculate month statistics
    final totalItems = monthItems.length;
    final completedItems = monthItems.where((item) => item.done).length;
    
    // Check if this is the current month
    final now = DateTime.now();
    final isCurrentMonth = baseDate.year == now.year && monthNumber == now.month;
    
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isCurrentMonth ? Border.all(
          color: themeProvider.shade400.withOpacity(0.3),
          width: 1,
        ) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Future: Navigate to month view or show month details
            // For now, just show a snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$monthName ${baseDate.year}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(6), // Further reduced padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  monthName.substring(0, 3), // First 3 letters (Jan, Feb, etc.)
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 11, // Minimized font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1), // Minimal spacing
                Text(
                  totalItems.toString(),
                  style: TextStyle(
                    color: themeProvider.shade400,
                    fontSize: 12, // Minimized font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1), // Minimal spacing
                Text(
                  completedItems.toString(),
                  style: TextStyle(
                    color: themeProvider.successColor,
                    fontSize: 10, // Minimized font size
                    fontWeight: FontWeight.w500,
                  ),
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
  const AddPlannerItemForm({
    Key? key, 
    required this.onSave, 
    required this.initialDate, 
    this.initialItem,
    this.initialType,
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
  TimeOfDay _endTime = TimeOfDay.now().replacing(minute: (TimeOfDay.now().minute + 30) % 60);
  int _duration = 0;
  final List<int> _durations = [0, 1, 15, 30, 45, 60, 90];
  late final ScrollController _durationScrollController;
  String? _nameError;
  Recurrence? _recurrence;
  // Routine fields
  List<String> _steps = [];
  List<TextEditingController> _stepControllers = [];
  List<bool> _stepChecked = [];

  // Flag to determine if we're editing an existing item
  late bool _isEditing;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _durationScrollController = ScrollController();
    
    // Set the editing flag based on whether we have an initial item
    _isEditing = widget.initialItem != null;
    
    // If editing an existing item, populate the form
    if (widget.initialItem != null) {
      final item = widget.initialItem!;
      _nameController.text = item.name;
      _date = item.date;
      
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
      _endTime = now.replacing(minute: (now.minute + 30) % 60);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _durationScrollController.dispose();
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

  // Helper to update duration based on start and end times
  void _updateDurationFromTimes() {
    if (_hasTime) {
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
        _duration = duration;
        // If this duration is not in the list, add it
        if (!_durations.contains(duration)) {
          _durations.add(duration);
          _durations.sort();
        }
      }
    }
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
        _buildDateTimeFields(themeColor),
        _buildReminderField(themeColor),
        _buildDurationField(themeColor),
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

  Widget _buildNameField(Color themeColor, String label) {
    return Row(
      children: [
        Text(getEmojiForName(_nameController.text), style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _nameController,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Provider.of<ThemeProvider>(context, listen: false).textColor),
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
              // This will trigger a rebuild and update the emoji
            }),
          ),
        ),
      ],
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
                        // When time is enabled, automatically calculate duration from start/end times
                        if (v) {
                          // If duration is currently 0 (None), set a default 30-minute duration
                          if (_duration == 0) {
                            _duration = 30;
                            _endTime = TimeOfDay(
                              hour: _startTime.hour,
                              minute: (_startTime.minute + 30) % 60,
                            );
                          } else {
                            _updateDurationFromTimes();
                          }
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
                            // Ensure end time is after start time
                            if (_endTime.hour * 60 + _endTime.minute <= _startTime.hour * 60 + _startTime.minute) {
                              _endTime = TimeOfDay(
                                hour: _startTime.hour,
                                minute: (_startTime.minute + 30) % 60,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            const SizedBox(height: 2),
        Row(
          children: [
                Text('Duration', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: themeProvider.textColor)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                    final custom = await showCustomDurationDialog(context, themeColor: themeProvider.shade400);
                if (custom != null && !_durations.contains(custom)) {
                  setState(() {
                    _durations.add(custom);
                    _durations.sort();
                    _duration = custom;
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
                  });
                  final idx = _durations.indexOf(custom);
                  await Future.delayed(const Duration(milliseconds: 50));
                  _durationScrollController.animateTo(
                    idx * 60.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: themeProvider.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              child: Text('More', style: TextStyle(fontSize: 12, color: themeProvider.shade400)),
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
              final selected = _duration == d;
              return ChoiceChip(
                label: Text(
                  d == 0 ? 'None' : d < 60 ? '${d}m' : d % 60 == 0 ? '${d ~/ 60}h' : '${d ~/ 60}h${d % 60}m',
                  style: TextStyle(color: selected ? themeProvider.cardColor : themeProvider.textColor, fontSize: 12),
                ),
                selected: selected,
                selectedColor: themeColor,
                onSelected: (_) {
                  setState(() {
                    _duration = d;
                    // Update end time based on new duration
                    if (_hasTime && d > 0) {
                      final startMinutes = _startTime.hour * 60 + _startTime.minute;
                      final endMinutes = startMinutes + d;
                      _endTime = TimeOfDay(hour: (endMinutes ~/ 60) % 24, minute: endMinutes % 60);
                    }
                  });
                },
                showCheckmark: false,
              );
            },
          ),
        ),
      ],
    );
      },
    );
  }

  Widget _buildReminderField(Color themeColor) {
    const reminderOptions = [5, 10, 15, 30, 60, 120]; // minutes before
    
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
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
                    onChanged: (val) => _setReminder(val),
                  ),
                ),
              ],
            ),
        if (_reminder) ...[
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

  void _onSave() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Enter a name');
      return;
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
      final finalDoneStatus = allStepsCompleted ? true : originalDone;
      
      item = PlannerItem(
        id: originalId, // Preserve original ID when editing
        name: _nameController.text.trim(),
        emoji: getEmojiForName(_nameController.text.trim()),
        date: _date,
        startTime: _hasTime ? _startTime : null,
        duration: _duration == 0 ? null : _duration,
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
                            final finalDoneStatus = allStepsCompleted ? true : widget.initialItem!.done;
                            
                            print('UP button: Form data gathered - Name: $newName, Date: $newDate, HasTime: $newHasTime, Steps: ${newSteps.length}');
                            
                            // 4. Create comprehensive updated item
                            final updatedItem = PlannerItem(
                              id: widget.initialItem!.id,
                              name: newName,
                              emoji: getEmojiForName(newName), // Regenerate emoji based on new name
                              date: newDate,
                              startTime: newStartTime,
                              duration: newDuration,
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

class _SoundWaveBar extends StatelessWidget {
  final double level;
  const _SoundWaveBar({Key? key, required this.level}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    final barHeight = 40.0;
    final barWidth = 180.0;
    final waveHeight = (level * 2.5).clamp(6.0, barHeight - 8.0);
    final isSilent = level < 2.0;
    return Container(
      width: barWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: themeProvider.shade100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shade200.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: isSilent
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: themeProvider.shade400, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Listening...',
                  style: TextStyle(
                    color: themeProvider.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            )
          : CustomPaint(
              size: Size(barWidth - 36, barHeight),
              painter: _WavePainter(waveHeight: waveHeight, color: themeProvider.shade400),
            ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double waveHeight;
  final Color color;
  _WavePainter({required this.waveHeight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();
    final midY = size.height / 2;
    final amplitude = waveHeight / 2;
    final waveLength = size.width / 1.5;
    for (double x = 0; x <= size.width; x += 1) {
      final y = midY + amplitude *
          sin(2 * pi * x / waveLength + DateTime.now().millisecond / 250.0);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.waveHeight != waveHeight;
  }
} 

