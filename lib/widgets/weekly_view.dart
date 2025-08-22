import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/planner_item.dart';
import '../theme/app_theme.dart';
import 'weekly_day_card.dart';
import 'donut_chart.dart';
import 'weekly_grid_view.dart';
import '../models/planner_item.dart';

class WeeklyView extends StatelessWidget {
  final DateTime selectedDate;
  final List<PlannerItem> allItems;
  final ThemeProvider themeProvider;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onAddTask;
  final Function(DateTime) onWeekChanged;
  final Function(PlannerItem) onToggleTask;
  final Function(PlannerItem)? onDeleteTask;
  final Function(PlannerItem)? onEditTask;
  final Function(PlannerItem)? onToggleImportantTask;
  final bool showImportantOnly;
  final DateTime? expandedDate;

  const WeeklyView({
    Key? key,
    required this.selectedDate,
    required this.allItems,
    required this.themeProvider,
    required this.onDaySelected,
    required this.onAddTask,
    required this.onWeekChanged,
    required this.onToggleTask,
    this.onDeleteTask,
    this.onEditTask,
    this.onToggleImportantTask,
    this.showImportantOnly = false,
    this.expandedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
        final weekStart = _getStartOfWeek(selectedDate);
    final weekDays = <DateTime>[];
    
    // Generate all days of the week
    for (int i = 0; i < 7; i++) {
      weekDays.add(weekStart.add(Duration(days: i)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
          children: [
                    // Week header
          Container(
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
                    onWeekChanged(selectedDate.subtract(const Duration(days: 7)));
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
            '${_formatDate(weekStart)} - ${_formatDate(weekStart.add(const Duration(days: 6)))}',
            style: TextStyle(
              fontSize: 14,
                      fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
            ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Next week button
                GestureDetector(
                  onTap: () {
                    onWeekChanged(selectedDate.add(const Duration(days: 7)));
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
                if (!_isCurrentWeek(selectedDate))
                  GestureDetector(
                    onTap: () {
                      onWeekChanged(DateTime.now());
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
            ),
          
          const SizedBox(height: 8),
          
          // Time slots grid --- this is the weekly grid view
          // WeeklyGridView(
          //   selectedDate: selectedDate,
          //   allItems: allItems,
          //   themeProvider: themeProvider,
          //   onDaySelected: onDaySelected,
          //   onAddTask: onAddTask,
          //   onWeekChanged: onWeekChanged,
          // ),
          const SizedBox(height: 8),
          
          // Days column
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: weekDays.length,
            itemBuilder: (context, index) {
              final date = weekDays[index];
              final dayName = _getDayName(date.weekday);
              final tasksForDay = _getTasksForDate(date);
              
              return WeeklyDayCard(
                dayName: dayName,
                date: date,
                tasks: tasksForDay,
                themeProvider: themeProvider,
                onTap: () => onDaySelected(date),
                onAddTask: (selectedDate) => onAddTask(selectedDate),
                onToggleTask: onToggleTask,
                onDeleteTask: onDeleteTask,
                onEditTask: onEditTask,
                onToggleImportantTask: onToggleImportantTask,
                isExpanded: expandedDate != null && 
                  date.year == expandedDate!.year && 
                  date.month == expandedDate!.month && 
                  date.day == expandedDate!.day,
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Week summary
          _buildWeekSummary(weekDays),
        ],
      ),
    );
  }

  Widget _buildWeekSummary(List<DateTime> weekDays) {
    int totalTasks = 0;
    int completedTasks = 0;
    
    for (final date in weekDays) {
      final tasks = _getTasksForDate(date);
      totalTasks += tasks.length;
      completedTasks += tasks.where((task) => task.done).length;
    }
    
    final pendingTasks = totalTasks - completedTasks;

    return Container(
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
            'Week Summary',
                      style: GoogleFonts.dancingScript(
              fontSize: 20,
              fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 4,
            childAspectRatio: 0.8,
            children: [
              DonutChart(
                total: totalTasks,
                completed: completedTasks,
                pending: pendingTasks,
                label: 'Total',
                size: 60,
                completedColor: themeProvider.shade400.withOpacity(0.8),
                pendingColor: themeProvider.shade400.withOpacity(0.8),
                totalColor: themeProvider.shade400.withOpacity(0.8),
              ),
              DonutChart(
                total: totalTasks,
                completed: completedTasks,
                pending: pendingTasks,
                label: 'Completed',
                size: 60,
                completedColor: Colors.green.shade400.withOpacity(0.8),
                pendingColor: Colors.green.shade400.withOpacity(0.8),
                totalColor: Colors.green.shade400.withOpacity(0.8),
              ),
              DonutChart(
                total: totalTasks,
                completed: completedTasks,
                pending: pendingTasks,
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
    );
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
                  (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty)) &&
                 RecurrenceUtils.shouldAppearOnDate(item, targetDate)) {
        shouldAppear = true;
      }
      
      if (shouldAppear && !processedIds.contains(item.id)) {
        if (itemDate.isAtSameMomentAs(targetDate)) {
          // Use the original item for the exact date match
          tasksForDate.add(item);
        } else {
          // Create a virtual instance for recurring items
          final virtualItem = RecurrenceUtils.createVirtualInstance(item, targetDate);
          tasksForDate.add(virtualItem);
        }
        processedIds.add(item.id);
      }
    }
    
    // Filter by important if toggle is enabled
    if (showImportantOnly) {
      return tasksForDate.where((item) => item.isImportant).toList();
    }
    
    return tasksForDate;
  }



  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }



  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)}';
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '';
    }
  }

  bool _isCurrentWeek(DateTime date) {
    final now = DateTime.now();
    final currentWeekStart = _getStartOfWeek(now);
    final dateWeekStart = _getStartOfWeek(date);
    return currentWeekStart.isAtSameMomentAs(dateWeekStart);
  }










} 