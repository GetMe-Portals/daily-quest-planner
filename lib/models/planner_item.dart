import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

class PlannerItem {
  final String id; // Unique identifier for the item
  String name;
  String emoji;
  DateTime date;
  TimeOfDay? startTime;
  int? duration;
  bool done;
  String type; // 'task', 'routine', 'event', 'shopping'
  bool? reminder;
  int? reminderOffset; // minutes before the event/task
  Recurrence? recurrence;
  String? location; // Location for events
  // Routine fields
  int? steps;
  int? stepsDone;
  List<String>? stepNames;
  List<bool>? stepChecked;

  PlannerItem({
    String? id,
    required this.name,
    required this.emoji,
    required this.date,
    this.startTime,
    this.duration,
    required this.done,
    required this.type,
    this.reminder,
    this.reminderOffset,
    this.recurrence,
    this.location,
    this.steps,
    this.stepsDone,
    this.stepNames,
    this.stepChecked,
  }) : id = id ?? _generateId();

  // Generate a unique ID
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 1000)).toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'date': date.toIso8601String(),
    'startTime': startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
    'duration': duration,
    'done': done,
    'type': type,
    'reminder': reminder,
    'reminderOffset': reminderOffset,
    'recurrence': recurrence?.toJson(),
    'location': location,
    'steps': steps,
    'stepsDone': stepsDone,
    'stepNames': stepNames,
    'stepChecked': stepChecked,
  };

  static PlannerItem fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? s) {
      if (s == null) return null;
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }
    return PlannerItem(
      id: json['id'], // Include ID for existing items
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '',
      date: DateTime.parse(json['date']),
      startTime: parseTime(json['startTime']),
      duration: json['duration'],
      done: json['done'] ?? false,
      type: json['type'] ?? 'task',
      reminder: json['reminder'],
      reminderOffset: json['reminderOffset'],
      recurrence: Recurrence.fromJson(json['recurrence']),
      location: json['location'],
      steps: json['steps'],
      stepsDone: json['stepsDone'],
      stepNames: (json['stepNames'] as List?)?.map((e) => e.toString()).toList(),
      stepChecked: (json['stepChecked'] as List?)?.map((e) => e == true).toList(),
    );
  }
}

class PlannerStorage {
  static const _key = 'planner_items';
  static Future<void> save(List<PlannerItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }
  static Future<List<PlannerItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    final items = list.map((e) => PlannerItem.fromJson(e)).toList();
    return items;
  }
}

class Recurrence {
  final List<String> patterns; // List of recurrence patterns
  final List<CustomRecurrence>? customRules; // Custom recurrence rules
  final String endType; // 'never', 'onDate', 'after'
  final DateTime? endDate;
  final int? endAfter;
  
  Recurrence({
    required this.patterns,
    this.customRules,
    this.endType = 'never',
    this.endDate,
    this.endAfter,
  });
  
  // Constructor for backward compatibility
  Recurrence.fromLegacy({
    required String frequency,
    List<int>? daysOfWeek,
    List<int>? monthDates,
    this.endType = 'never',
    this.endDate,
    this.endAfter,
  }) : patterns = [frequency],
       customRules = null;
  
  // Get legacy frequency for backward compatibility
  String get frequency => patterns.isNotEmpty ? patterns.first : 'none';
  
  Map<String, dynamic> toJson() => {
    'patterns': patterns,
    'customRules': customRules?.map((r) => r.toJson()).toList(),
    'endType': endType,
    'endDate': endDate?.toIso8601String(),
    'endAfter': endAfter,
  };
  static Recurrence? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    
    // Handle legacy format
    if (json.containsKey('frequency')) {
      return Recurrence.fromLegacy(
        frequency: json['frequency'] ?? 'none',
        daysOfWeek: (json['daysOfWeek'] as List?)?.map((e) => e as int).toList(),
        monthDates: (json['monthDates'] as List?)?.map((e) => e as int).toList(),
        endType: json['endType'] ?? 'never',
        endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
        endAfter: json['endAfter'],
      );
    }
    
    // Handle new format
    return Recurrence(
      patterns: (json['patterns'] as List?)?.map((e) => e.toString()).toList() ?? [],
      customRules: (json['customRules'] as List?)?.map((e) => CustomRecurrence.fromJson(e)).toList(),
      endType: json['endType'] ?? 'never',
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      endAfter: json['endAfter'],
    );
  }
  String summary() {
    if (patterns.isEmpty) return 'No recurrence';
    
    final summaries = <String>[];
    
    for (final pattern in patterns) {
      switch (pattern) {
        case 'daily': summaries.add('Daily'); break;
        case 'weekdays': summaries.add('Weekdays'); break;
        case 'weekends': summaries.add('Weekends'); break;
        case 'monthly': summaries.add('Monthly'); break;
        case 'yearly': summaries.add('Yearly'); break;
      }
    }
    
    if (customRules != null && customRules!.isNotEmpty) {
      summaries.addAll(customRules!.map((r) => r.displayText));
    }
    
    return summaries.join(', ');
  }
}

class CustomRecurrence {
  final String type; // 'every_n_days', 'every_n_weeks', 'every_n_months', 'nth_day_of_month', 'specific_weekdays'
  final int interval;
  final int? dayOfWeek; // 0=Sun, 1=Mon, etc.
  final int? dayOfMonth; // 1-31
  final int? weekOfMonth; // 1-5 (1st, 2nd, 3rd, 4th, 5th week)
  final List<int>? selectedWeekdays; // 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  
  CustomRecurrence({
    required this.type,
    required this.interval,
    this.dayOfWeek,
    this.dayOfMonth,
    this.weekOfMonth,
    this.selectedWeekdays,
  });
  
  String get displayText {
    switch (type) {
      case 'every_n_days':
        return 'Every $interval days';
      case 'every_n_weeks':
        return 'Every $interval weeks';
      case 'every_n_months':
        return 'Every $interval months';
      case 'nth_day_of_month':
        final weekNames = ['1st', '2nd', '3rd', '4th', '5th'];
        final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return '${weekNames[weekOfMonth! - 1]} ${dayNames[dayOfWeek!]} of month';
      case 'specific_weekdays':
        if (selectedWeekdays == null || selectedWeekdays!.isEmpty) {
          return 'Specific Weekdays';
        }
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final selectedDays = selectedWeekdays!.map((day) => dayNames[day - 1]).toList();
        return 'Every ${selectedDays.join(', ')}';
      default:
        return 'Custom';
    }
  }
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'interval': interval,
    'dayOfWeek': dayOfWeek,
    'dayOfMonth': dayOfMonth,
    'weekOfMonth': weekOfMonth,
    'selectedWeekdays': selectedWeekdays,
  };
  
  static CustomRecurrence fromJson(Map<String, dynamic> json) {
    return CustomRecurrence(
      type: json['type'] ?? '',
      interval: json['interval'] ?? 1,
      dayOfWeek: json['dayOfWeek'],
      dayOfMonth: json['dayOfMonth'],
      weekOfMonth: json['weekOfMonth'],
      selectedWeekdays: json['selectedWeekdays'] != null 
          ? List<int>.from(json['selectedWeekdays'])
          : null,
    );
  }
}

class RecurrenceSection extends StatefulWidget {
  final Recurrence? initialValue;
  final void Function(Recurrence?) onChanged;
  const RecurrenceSection({Key? key, this.initialValue, required this.onChanged}) : super(key: key);
  @override
  State<RecurrenceSection> createState() => _RecurrenceSectionState();
}

class _RecurrenceSectionState extends State<RecurrenceSection> {
  late Set<String> _selectedPatterns;
  late List<CustomRecurrence> _customRules;
  late ScrollController _scrollController;
  
  static const List<Map<String, dynamic>> _recurrenceOptions = [
    {'id': 'daily', 'label': 'Every Day'},
    {'id': 'weekdays', 'label': 'Weekdays'},
    {'id': 'weekends', 'label': 'Weekends'},
    {'id': 'monthly', 'label': 'Every Month'},
    {'id': 'yearly', 'label': 'Every Year'},
    {'id': 'custom', 'label': 'Custom'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectedPatterns = <String>{};
    _customRules = <CustomRecurrence>[];
    
    if (widget.initialValue != null) {
      _selectedPatterns = Set.from(widget.initialValue!.patterns);
      _customRules = List.from(widget.initialValue!.customRules ?? []);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePattern(String patternId) {
    setState(() {
      if (patternId == 'custom') {
        _showCustomRecurrenceDialog();
        return;
      } else {
        if (_selectedPatterns.contains(patternId)) {
          _selectedPatterns.remove(patternId);
        } else {
          _selectedPatterns.add(patternId);
        }
      }
      _updateRecurrence();
    });
  }

  void _showCustomRecurrenceDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomRecurrenceSheet(
        onAdd: (customRule) {
          setState(() {
            _customRules.add(customRule);
            _updateRecurrence();
          });
        },
      ),
    );
  }

  void _removeCustomRule(CustomRecurrence rule) {
    setState(() {
      _customRules.remove(rule);
      _updateRecurrence();
    });
  }

  void _updateRecurrence() {
    final patterns = _selectedPatterns.toList();
    final customRules = _customRules.isNotEmpty ? _customRules : null;
    
    // Create recurrence if there are patterns OR custom rules
    final recurrence = (patterns.isNotEmpty || customRules != null)
        ? Recurrence(
            patterns: patterns,
            customRules: customRules,
          )
        : null;
    
    widget.onChanged(recurrence);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final themeColor = themeProvider.shade400;
        
        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text('Recurrence', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, color: themeProvider.textColor)),
        const SizedBox(height: 2),
        SizedBox(
          height: 36,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _recurrenceOptions.length,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final option = _recurrenceOptions[i];
              final isSelected = _selectedPatterns.contains(option['id']);
              
              return ChoiceChip(
                label: Text(option['label'], style: TextStyle(color: isSelected ? themeProvider.cardColor : themeProvider.textColor, fontSize: 12)),
                selected: isSelected,
                selectedColor: themeColor,
                onSelected: (_) => _togglePattern(option['id']),
                showCheckmark: false,
              );
            },
          ),
        ),
        if (_customRules.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 3,
            children: _customRules.map((rule) {
              return Chip(
                label: Text(rule.displayText, style: TextStyle(color: themeProvider.textColor)),
                backgroundColor: themeColor.withOpacity(0.1),
                side: BorderSide(color: themeColor),
                deleteIcon: Icon(Icons.close, size: 16, color: themeColor),
                onDeleted: () => _removeCustomRule(rule),
              );
            }).toList(),
          ),
        ],
      ],
    );
      },
    );
  }
}

class _CustomRecurrenceSheet extends StatefulWidget {
  final void Function(CustomRecurrence) onAdd;
  
  const _CustomRecurrenceSheet({required this.onAdd});
  
  @override
  State<_CustomRecurrenceSheet> createState() => _CustomRecurrenceSheetState();
}

class _CustomRecurrenceSheetState extends State<_CustomRecurrenceSheet> {
  String _selectedType = 'every_n_days';
  int _interval = 1;
  int _selectedDayOfWeek = 1; // Monday
  int _selectedWeekOfMonth = 1; // 1st week
  Set<int> _selectedWeekdays = <int>{}; // 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final themeColor = themeProvider.shade400;
        
        return Container(
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Custom Recurrence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeProvider.textColor)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: themeProvider.textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'every_n_days', child: Text('Every N days')),
              DropdownMenuItem(value: 'every_n_weeks', child: Text('Every N weeks')),
              DropdownMenuItem(value: 'every_n_months', child: Text('Every N months')),
              DropdownMenuItem(value: 'nth_day_of_month', child: Text('Nth day of month')),
              DropdownMenuItem(value: 'specific_weekdays', child: Text('Specific Weekdays')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedType = value);
              }
            },
          ),
          const SizedBox(height: 16),
          if (_selectedType == 'specific_weekdays') ...[
            // Weekday selector
            Text(
              'Select Weekdays',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildWeekdayChip(1, 'Mon', themeProvider),
                _buildWeekdayChip(2, 'Tue', themeProvider),
                _buildWeekdayChip(3, 'Wed', themeProvider),
                _buildWeekdayChip(4, 'Thu', themeProvider),
                _buildWeekdayChip(5, 'Fri', themeProvider),
                _buildWeekdayChip(6, 'Sat', themeProvider),
                _buildWeekdayChip(7, 'Sun', themeProvider),
              ],
            ),
          ] else if (_selectedType != 'nth_day_of_month') ...[
            Row(
              children: [
                const Text('Every '),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: '1',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (value) {
                      final interval = int.tryParse(value);
                      if (interval != null && interval > 0) {
                        setState(() => _interval = interval);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(_selectedType == 'every_n_days' ? 'days' : 
                     _selectedType == 'every_n_weeks' ? 'weeks' : 'months'),
              ],
            ),
          ] else ...[
            Row(
              children: [
                DropdownButton<int>(
                  value: _selectedWeekOfMonth,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1st')),
                    DropdownMenuItem(value: 2, child: Text('2nd')),
                    DropdownMenuItem(value: 3, child: Text('3rd')),
                    DropdownMenuItem(value: 4, child: Text('4th')),
                    DropdownMenuItem(value: 5, child: Text('5th')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedWeekOfMonth = value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedDayOfWeek,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Sunday')),
                    DropdownMenuItem(value: 1, child: Text('Monday')),
                    DropdownMenuItem(value: 2, child: Text('Tuesday')),
                    DropdownMenuItem(value: 3, child: Text('Wednesday')),
                    DropdownMenuItem(value: 4, child: Text('Thursday')),
                    DropdownMenuItem(value: 5, child: Text('Friday')),
                    DropdownMenuItem(value: 6, child: Text('Saturday')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedDayOfWeek = value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                const Text('of month'),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: themeProvider.cardColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Validate that at least one weekday is selected for specific_weekdays
                if (_selectedType == 'specific_weekdays' && _selectedWeekdays.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please select at least one weekday'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                
                final customRule = CustomRecurrence(
                  type: _selectedType,
                  interval: _interval,
                  dayOfWeek: _selectedType == 'nth_day_of_month' ? _selectedDayOfWeek : null,
                  weekOfMonth: _selectedType == 'nth_day_of_month' ? _selectedWeekOfMonth : null,
                  selectedWeekdays: _selectedType == 'specific_weekdays' ? _selectedWeekdays.toList() : null,
                );
                widget.onAdd(customRule);
                Navigator.pop(context);
              },
              child: const Text('Add Custom Rule'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
      },
    );
  }

  Widget _buildWeekdayChip(int weekday, String label, ThemeProvider themeProvider) {
    final isSelected = _selectedWeekdays.contains(weekday);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedWeekdays.remove(weekday);
          } else {
            _selectedWeekdays.add(weekday);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeProvider.shade400 : themeProvider.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? themeProvider.shade400 : themeProvider.dividerColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? themeProvider.cardColor : themeProvider.textColor,
          ),
        ),
      ),
    );
  }
}

class RecurrenceUtils {
  /// Determines if a task with recurrence should appear on a given date
  static bool shouldAppearOnDate(PlannerItem item, DateTime targetDate) {
    if (item.recurrence == null) {
      return false;
    }

    // Don't show recurring tasks before their original date
    if (targetDate.isBefore(item.date)) {
      return false;
    }

    // Check each recurrence pattern
    for (final pattern in item.recurrence!.patterns) {
      if (_matchesPattern(pattern, item.date, targetDate)) {
        return true;
      }
    }

    // Check custom recurrence rules
    if (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty) {
      for (final customRule in item.recurrence!.customRules!) {
        if (_matchesCustomRule(customRule, item.date, targetDate)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if a specific pattern matches the target date
  static bool _matchesPattern(String pattern, DateTime originalDate, DateTime targetDate) {
    switch (pattern) {
      case 'daily':
        return true; // Appears on every day after original date
      
      case 'weekdays':
        return targetDate.weekday >= 1 && targetDate.weekday <= 5; // Monday to Friday
      
      case 'weekends':
        return targetDate.weekday == 6 || targetDate.weekday == 7; // Saturday and Sunday
      
      case 'monthly':
        // Same day of month (e.g., 15th of every month)
        return targetDate.day == originalDate.day;
      
      case 'yearly':
        // Same day and month (e.g., January 15th every year)
        return targetDate.month == originalDate.month && targetDate.day == originalDate.day;
      
      default:
        return false;
    }
  }

  /// Checks if a custom recurrence rule matches the target date
  static bool _matchesCustomRule(CustomRecurrence rule, DateTime originalDate, DateTime targetDate) {
    switch (rule.type) {
      case 'every_n_days':
        final daysDiff = targetDate.difference(originalDate).inDays;
        return daysDiff >= 0 && daysDiff % rule.interval == 0;
      
      case 'every_n_weeks':
        final weeksDiff = targetDate.difference(originalDate).inDays ~/ 7;
        return weeksDiff >= 0 && weeksDiff % rule.interval == 0 && 
               targetDate.weekday == originalDate.weekday;
      
      case 'every_n_months':
        final monthsDiff = (targetDate.year - originalDate.year) * 12 + 
                          (targetDate.month - originalDate.month);
        return monthsDiff >= 0 && monthsDiff % rule.interval == 0 && 
               targetDate.day == originalDate.day;
      
      case 'nth_day_of_month':
        if (rule.weekOfMonth == null || rule.dayOfWeek == null) return false;
        
        // Calculate the nth occurrence of the specified day of week in the target month
        final firstDayOfMonth = DateTime(targetDate.year, targetDate.month, 1);
        final firstDayWeekday = firstDayOfMonth.weekday;
        
        // Calculate the first occurrence of the target day of week
        int firstOccurrence = 1;
        if (firstDayWeekday <= rule.dayOfWeek!) {
          firstOccurrence += rule.dayOfWeek! - firstDayWeekday;
        } else {
          firstOccurrence += 7 - firstDayWeekday + rule.dayOfWeek!;
        }
        
        // Calculate the nth occurrence
        final targetDay = firstOccurrence + (rule.weekOfMonth! - 1) * 7;
        
        // Check if the target day exists in the month and matches our target date
        final lastDayOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0);
        return targetDay <= lastDayOfMonth.day && targetDate.day == targetDay;
      
      case 'specific_weekdays':
        if (rule.selectedWeekdays == null || rule.selectedWeekdays!.isEmpty) return false;
        
        // Check if the target date's weekday is in the selected weekdays
        // Note: DateTime.weekday uses 1=Monday, 7=Sunday, which matches our format
        return rule.selectedWeekdays!.contains(targetDate.weekday);
      
      default:
        return false;
    }
  }

  /// Gets the next occurrence date for a recurring task
  static DateTime? getNextOccurrence(PlannerItem item, DateTime fromDate) {
    if (item.recurrence == null) {
      return null;
    }

    // Check if there are any patterns or custom rules
    final hasPatterns = item.recurrence!.patterns.isNotEmpty;
    final hasCustomRules = item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty;
    
    if (!hasPatterns && !hasCustomRules) {
      return null;
    }

    DateTime currentDate = fromDate.add(const Duration(days: 1));
    final maxDate = fromDate.add(const Duration(days: 365)); // Limit to 1 year ahead

    while (currentDate.isBefore(maxDate)) {
      if (shouldAppearOnDate(item, currentDate)) {
        return currentDate;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return null;
  }

  /// Gets all occurrence dates for a recurring task within a date range
  static List<DateTime> getOccurrencesInRange(PlannerItem item, DateTime startDate, DateTime endDate) {
    if (item.recurrence == null) {
      return [];
    }

    // Check if there are any patterns or custom rules
    final hasPatterns = item.recurrence!.patterns.isNotEmpty;
    final hasCustomRules = item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty;
    
    if (!hasPatterns && !hasCustomRules) {
      return [];
    }

    final occurrences = <DateTime>[];
    DateTime currentDate = startDate;

    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      if (shouldAppearOnDate(item, currentDate)) {
        occurrences.add(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return occurrences;
  }

  /// Creates a virtual task instance for a specific date
  static PlannerItem createVirtualInstance(PlannerItem originalItem, DateTime targetDate) {
    return PlannerItem(
      id: '${originalItem.id}_virtual_${targetDate.millisecondsSinceEpoch}', // Unique ID for virtual instances
      name: originalItem.name,
      emoji: originalItem.emoji,
      date: targetDate,
      startTime: originalItem.startTime,
      duration: originalItem.duration,
      done: false, // Virtual instances are always unchecked
      type: originalItem.type,
      reminder: originalItem.reminder,
      reminderOffset: originalItem.reminderOffset,
      location: originalItem.location,
      recurrence: originalItem.recurrence, // Keep recurrence info for identification
      steps: originalItem.steps,
      stepsDone: originalItem.stepsDone,
      stepNames: originalItem.stepNames,
      stepChecked: originalItem.stepChecked,
    );
  }
}

String getEmojiForName(String name) {
  if (name.trim().isEmpty) return '📝'; // Default for empty input
  
  final lower = name.toLowerCase();
  
  // Meeting & Events
  if (lower.contains('meeting') || lower.contains('appointment') || lower.contains('conference')) return '📅';
  if (lower.contains('birthday') || lower.contains('party') || lower.contains('celebration')) return '🎂';
  if (lower.contains('wedding') || lower.contains('anniversary')) return '💒';
  if (lower.contains('dinner') || lower.contains('lunch') || lower.contains('breakfast')) return '🍽️';
  
  // Health & Fitness
  if (lower.contains('workout') || lower.contains('gym') || lower.contains('exercise') || lower.contains('fitness')) return '💪';
  if (lower.contains('run') || lower.contains('jog') || lower.contains('marathon')) return '🏃';
  if (lower.contains('walk') || lower.contains('hike')) return '🚶';
  if (lower.contains('yoga') || lower.contains('meditate') || lower.contains('meditation')) return '🧘';
  if (lower.contains('doctor') || lower.contains('medical') || lower.contains('appointment')) return '🩺';
  if (lower.contains('dentist') || lower.contains('dental')) return '🦷';
  if (lower.contains('pharmacy') || lower.contains('medicine')) return '💊';
  
  // Shopping & Errands
  if (lower.contains('shop') || lower.contains('buy') || lower.contains('purchase')) return '🛒';
  if (lower.contains('grocery') || lower.contains('food') || lower.contains('market')) return '🛒';
  if (lower.contains('clothes') || lower.contains('fashion') || lower.contains('outfit')) return '👕';
  
  // Travel & Transportation
  if (lower.contains('flight') || lower.contains('travel') || lower.contains('trip') || lower.contains('vacation')) return '✈️';
  if (lower.contains('car') || lower.contains('drive') || lower.contains('road')) return '🚗';
  if (lower.contains('train') || lower.contains('subway') || lower.contains('metro')) return '🚆';
  if (lower.contains('bus') || lower.contains('transport')) return '🚌';
  
  // Work & Business
  if (lower.contains('work') || lower.contains('office') || lower.contains('job')) return '💼';
  if (lower.contains('email') || lower.contains('mail')) return '✉️';
  if (lower.contains('call') || lower.contains('phone') || lower.contains('dial')) return '📞';
  if (lower.contains('presentation') || lower.contains('pitch') || lower.contains('demo')) return '📊';
  if (lower.contains('interview') || lower.contains('resume') || lower.contains('cv')) return '📋';
  
  // Education & Learning
  if (lower.contains('study') || lower.contains('learn') || lower.contains('course')) return '📖';
  if (lower.contains('read') || lower.contains('book') || lower.contains('library')) return '📚';
  if (lower.contains('write') || lower.contains('blog') || lower.contains('article')) return '✍️';
  if (lower.contains('homework') || lower.contains('assignment') || lower.contains('project')) return '📝';
  if (lower.contains('exam') || lower.contains('test') || lower.contains('quiz')) return '📝';
  
  // Home & Personal
  if (lower.contains('clean') || lower.contains('laundry') || lower.contains('wash')) return '🧹';
  if (lower.contains('cook') || lower.contains('bake') || lower.contains('kitchen')) return '🍳';
  if (lower.contains('water') || lower.contains('plant') || lower.contains('garden')) return '💧';
  if (lower.contains('pet') || lower.contains('dog') || lower.contains('cat')) return '🐕';
  if (lower.contains('baby') || lower.contains('child') || lower.contains('kid')) return '👶';
  
  // Entertainment & Leisure
  if (lower.contains('movie') || lower.contains('film') || lower.contains('cinema')) return '🎬';
  if (lower.contains('music') || lower.contains('concert') || lower.contains('gig')) return '🎵';
  if (lower.contains('game') || lower.contains('play') || lower.contains('gaming')) return '🎮';
  if (lower.contains('sport') || lower.contains('football') || lower.contains('basketball')) return '⚽';
  if (lower.contains('swim') || lower.contains('pool')) return '🏊';
  
  // Financial & Banking
  if (lower.contains('bank') || lower.contains('money') || lower.contains('finance')) return '💰';
  if (lower.contains('pay') || lower.contains('bill') || lower.contains('rent')) return '💳';
  
  // Technology & Digital
  if (lower.contains('computer') || lower.contains('laptop') || lower.contains('tech')) return '💻';
  if (lower.contains('phone') || lower.contains('mobile') || lower.contains('app')) return '📱';
  if (lower.contains('internet') || lower.contains('wifi') || lower.contains('online')) return '🌐';
  
  // Default categories
  if (lower.contains('task') || lower.contains('todo')) return '📝';
  if (lower.contains('routine') || lower.contains('habit')) return '🔁';
  if (lower.contains('event') || lower.contains('activity')) return '📆';
  
  return '📝'; // Default for unmatched
}

Future<int?> showCustomDurationDialog(BuildContext context, {Color? themeColor}) async {
  final controller = TextEditingController();
  String? error;
  return await showDialog<int>(
    context: context,
    builder: (context) {
      return Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: themeProvider.cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Custom Duration', style: TextStyle(color: themeProvider.textColor)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: false, signed: false),
                  style: TextStyle(color: themeProvider.textColor),
                  decoration: InputDecoration(
                    labelText: 'Minutes or hh:mm',
                    labelStyle: TextStyle(color: themeProvider.textColorSecondary),
                    errorText: error,
                    errorStyle: TextStyle(color: themeProvider.errorColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Enter minutes (e.g. 90) or hours:minutes (e.g. 1:30)', style: TextStyle(fontSize: 12, color: themeProvider.textColorSecondary)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: themeProvider.textColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor ?? Colors.pink.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final text = controller.text.trim();
                  int? minutes;
                  if (text.contains(':')) {
                    final parts = text.split(':');
                    if (parts.length == 2) {
                      final h = int.tryParse(parts[0]);
                      final m = int.tryParse(parts[1]);
                      if (h != null && m != null && h >= 0 && m >= 0 && m < 60) {
                        minutes = h * 60 + m;
                      }
                    }
                  } else {
                    final m = int.tryParse(text);
                    if (m != null && m > 0) minutes = m;
                  }
                  if (minutes == null || minutes <= 0) {
                    setState(() => error = 'Enter a valid duration');
                  } else {
                    Navigator.pop(context, minutes);
                  }
                },
                child: Text('OK', style: TextStyle(color: themeProvider.cardColor)),
              ),
            ],
          );
        },
      );
        },
      );
    },
  );
} 