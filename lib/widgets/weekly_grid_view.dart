import 'package:flutter/material.dart';
import '../models/planner_item.dart';
import '../theme/app_theme.dart';

class WeeklyGridView extends StatelessWidget {
  final DateTime selectedDate;
  final List<PlannerItem> allItems;
  final ThemeProvider themeProvider;
  final Function(DateTime) onDaySelected;
  final VoidCallback onAddTask;
  final Function(DateTime) onWeekChanged;

  const WeeklyGridView({
    Key? key,
    required this.selectedDate,
    required this.allItems,
    required this.themeProvider,
    required this.onDaySelected,
    required this.onAddTask,
    required this.onWeekChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final weekStart = _getStartOfWeek(selectedDate);
    final weekDays = <DateTime>[];
    
    // Generate all days of the week
    for (int i = 0; i < 7; i++) {
      weekDays.add(weekStart.add(Duration(days: i)));
    }

    return _buildTimeSlotsGrid(weekDays, themeProvider);
  }

  Widget _buildTimeSlotsGrid(List<DateTime> weekDays, ThemeProvider themeProvider) {
    // Generate time slots from 6:00 AM to 5:00 AM (24 hours)
    final timeSlots = <TimeOfDay>[];
    for (int hour = 6; hour <= 29; hour++) {
      timeSlots.add(TimeOfDay(hour: hour % 24, minute: 0));
    }

    return Container(
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
      ),
      child: Column(
        children: [
          // Header row with day names
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: themeProvider.shade400.withOpacity(0.05),
            ),
            child: Row(
              children: [
                // Time column header (empty)
                SizedBox(
                  width: 40,
                  child: Text(
                    'Time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColorSecondary,
                    ),
                  ),
                ),
                // Day headers
                ...weekDays.map((day) => Expanded(
                  child: Text(
                    _getAbbreviatedDayName(day.weekday),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColorSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )).toList(),
              ],
            ),
          ),
          // Plans summary row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: themeProvider.shade400.withOpacity(0.02),
            ),
            child: Row(
              children: [
                // Plans label
                SizedBox(
                  width: 40,
                  child: Text(
                    '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColorSecondary,
                    ),
                  ),
                ),
                // Day summaries
                ...weekDays.map((day) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    decoration: BoxDecoration(
                      color: _getDaySummaryColor(day, themeProvider),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getDaySummaryText(day),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
          // Time slots rows
          ...timeSlots.map((timeSlot) => Container(
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                // Time slot label
                Container(
                  width: 40,
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimeNumber(timeSlot),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColorSecondary,
                        ),
                      ),
                      Text(
                        ' ${_formatTimePeriod(timeSlot)}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.normal,
                          color: themeProvider.textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Day cells
                ...weekDays.map((day) => Expanded(
                  child: Container(
                    height: 40,
                    child: _buildTimeSlotCell(day, timeSlot, themeProvider),
                  ),
                )).toList(),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildTimeSlotCell(DateTime day, TimeOfDay timeSlot, ThemeProvider themeProvider) {
    final tasksForThisDay = _getTasksForDate(day);
    final tasksInThisHour = <PlannerItem>[];
    
    // Find tasks that should be displayed in this hour slot
    for (final task in tasksForThisDay) {
      if (task.startTime != null) {
        final taskStartHour = task.startTime!.hour;
        final currentHour = timeSlot.hour;
        
        // Only show task in the hour slot where it starts
        if (taskStartHour == currentHour) {
          tasksInThisHour.add(task);
        }
      }
    }
    
    if (tasksInThisHour.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: _getDayColumnColor(day).withOpacity(0.3),
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.all(1),
      child: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              color: themeProvider.shade400.withOpacity(0.02),
            ),
          ),
          // Task blocks
          ...tasksInThisHour.asMap().entries.map((entry) {
            final index = entry.key;
            final task = entry.value;
            final maxTasks = 2; // Show up to 2 visible blocks per hour
            
            if (index >= maxTasks) {
              if (index == maxTasks) {
                return Positioned(
                  top: index * 22.0,
                  left: 2,
                  right: 2,
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: themeProvider.textColorSecondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '+${tasksInThisHour.length - maxTasks}',
                        style: TextStyle(
                          fontSize: 10,
                          color: themeProvider.cardColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            
            return _buildTaskBlock(task, day, timeSlot, themeProvider, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTaskBlock(PlannerItem task, DateTime day, TimeOfDay timeSlot, ThemeProvider themeProvider, int index) {
    final duration = task.duration ?? 30;
    final hours = duration / 60.0; // Use exact hours, not rounded up
    final blockHeight = (hours * 40.0).clamp(40.0, 200.0); // Min 40px, max 200px (5 hours)
    
    // Calculate vertical offset based on start time within the hour
    double topOffset = index * 22.0;
    if (task.startTime != null && task.startTime!.hour == timeSlot.hour) {
      final startMinute = task.startTime!.minute;
      topOffset += (startMinute / 60.0) * 40.0; // Adjust position within the hour
    }
    
    return Positioned(
      top: topOffset,
      left: 2,
      right: 2,
      child: Container(
        height: blockHeight,
        decoration: BoxDecoration(
          color: _getTaskColor(task, themeProvider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            task.name,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // Tasks that START in this hour
  List<PlannerItem> _getStartingTasksForTimeSlot(DateTime day, TimeOfDay timeSlot) {
    final targetDate = DateTime(day.year, day.month, day.day);
    final tasksForTimeSlot = <PlannerItem>[];
    
    for (final item in allItems) {
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      
      // Include tasks for this day that START within this hour (including partial hours like 6:30)
      if (itemDate.isAtSameMomentAs(targetDate) && item.startTime != null) {
        if (item.startTime!.hour == timeSlot.hour) {
          tasksForTimeSlot.add(item);
        }
      }
    }
    
    return tasksForTimeSlot;
  }

  // Tasks that OVERLAP with this hour (for background highlighting)
  List<PlannerItem> _getOverlappingTasksForTimeSlot(DateTime day, TimeOfDay timeSlot) {
    final targetDate = DateTime(day.year, day.month, day.day);
    final overlapping = <PlannerItem>[];
    final slotStart = timeSlot.hour * 60;
    final slotEnd = (timeSlot.hour + 1) * 60;
    
    for (final item in allItems) {
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      if (!itemDate.isAtSameMomentAs(targetDate) || item.startTime == null) continue;
      final start = item.startTime!.hour * 60 + item.startTime!.minute;
      final end = start + (item.duration ?? 30);
      if (end > slotStart && start < slotEnd) {
        overlapping.add(item);
      }
    }
    return overlapping;
  }

  double _getTaskHeight(PlannerItem task) {
    final duration = task.duration ?? 30;
    final hours = duration / 60.0;
    // Minimum height of 20px, maximum of 40px (full cell height)
    return (hours * 20).clamp(20.0, 40.0);
  }

  Color _getTaskColor(PlannerItem task, ThemeProvider themeProvider) {
    if (task.done) {
      return Colors.green.withOpacity(0.8);
    }
    
    switch (task.type) {
      case 'event':
        return themeProvider.shade500.withOpacity(0.8);
      case 'routine':
        return Colors.orange.withOpacity(0.8);
      case 'shopping':
        return Colors.purple.withOpacity(0.8);
      default:
        return themeProvider.shade400.withOpacity(0.8);
    }
  }

  List<PlannerItem> _getTasksForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final tasksForDate = <PlannerItem>[];
    final processedIds = <String>{};
    
    for (final item in allItems) {
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      
      bool shouldAppear = false;
      
      if (itemDate.isAtSameMomentAs(targetDate)) {
        shouldAppear = true;
      } else if (item.recurrence != null && 
                 (item.recurrence!.patterns.isNotEmpty || 
                  (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty))) {
        // Handle recurring items
        shouldAppear = true; // Simplified for now
      }
      
      if (shouldAppear && !processedIds.contains(item.id)) {
        tasksForDate.add(item);
        processedIds.add(item.id);
      }
    }
    
    return tasksForDate;
  }

  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  String _getAbbreviatedDayName(int weekday) {
    switch (weekday) {
      case 1: return 'M';
      case 2: return 'T';
      case 3: return 'W';
      case 4: return 'T';
      case 5: return 'F';
      case 6: return 'S';
      case 7: return 'S';
      default: return '';
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour} $period';
  }

  String _formatTimeNumber(TimeOfDay time) {
    final hour = time.hour;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return displayHour.toString();
  }

  String _formatTimePeriod(TimeOfDay time) {
    final hour = time.hour;
    return hour >= 12 ? 'PM' : 'AM';
  }

  String _formatTimeRange(PlannerItem task) {
    if (task.startTime == null) return '';
    final duration = task.duration ?? 30;
    final startMinutes = task.startTime!.hour * 60 + task.startTime!.minute;
    final endMinutes = startMinutes + duration;
    final endHour = (endMinutes ~/ 60) % 24;
    final endMinute = endMinutes % 60;
    final end = TimeOfDay(hour: endHour, minute: endMinute);
    return '${_formatTime(task.startTime!)} - ${_formatTime(end)}';
  }

  String _getDaySummaryText(DateTime day) {
    final tasks = _getTasksForDate(day);
    final completedTasks = tasks.where((task) => task.done).length;
    final totalTasks = tasks.length;
    return '$completedTasks/$totalTasks';
  }

  Color _getDaySummaryColor(DateTime day, ThemeProvider themeProvider) {
    final tasks = _getTasksForDate(day);
    if (tasks.isEmpty) {
      return themeProvider.shade400.withOpacity(0.1);
    }
    
    final completedTasks = tasks.where((task) => task.done).length;
    final totalTasks = tasks.length;
    final completionRatio = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    
    if (completionRatio == 1.0) {
      return Colors.green.shade100; // All completed
    } else if (completionRatio > 0.5) {
      return Colors.orange.shade100; // More than half completed
    } else if (completionRatio > 0) {
      return Colors.yellow.shade100; // Some completed
    } else {
      return Colors.red.shade100; // None completed
    }
  }

  Color _getDayColumnColor(DateTime day) {
    // Return specific colors for each day of the week based on the image
    switch (day.weekday) {
      case 1: // Monday
        return Colors.purple.shade100;
      case 2: // Tuesday
        return Colors.orange.shade100;
      case 3: // Wednesday
        return Colors.green.shade100;
      case 4: // Thursday
        return Colors.blue.shade100;
      case 5: // Friday
        return Colors.yellow.shade100;
      case 6: // Saturday
        return Colors.pink.shade100;
      case 7: // Sunday
        return Colors.green.shade50;
      default:
        return Colors.grey.shade100;
    }
  }
}
