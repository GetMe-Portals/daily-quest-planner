import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/planner_item.dart';
import '../theme/app_theme.dart';
import 'donut_chart.dart';
import '../services/mood_service.dart';
import 'mood_streaks_widget.dart';

class DashboardView extends StatefulWidget {
  final List<PlannerItem> items;
  final DateTime selectedDate;
  final Map<DateTime, String>? moodData; // Map of date to mood type
  final Function(DateTime)? onDateChanged; // Callback to update main date
  final Function(DateTime)? onMonthChanged; // Callback to sync mood calendar month
  final Function(DateTime, String)? onMoodSelected; // Callback for mood selection

  const DashboardView({
    Key? key,
    required this.items,
    required this.selectedDate,
    this.moodData,
    this.onDateChanged,
    this.onMonthChanged,
    this.onMoodSelected,
  }) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late DateTime _moodCalendarDate;

  @override
  void initState() {
    super.initState();
    _moodCalendarDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(DashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update mood calendar month when selected date changes (from calendar card)
    if (oldWidget.selectedDate.month != widget.selectedDate.month || 
        oldWidget.selectedDate.year != widget.selectedDate.year) {
      setState(() {
        _moodCalendarDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
      });
      // Notify parent about month change
      widget.onMonthChanged?.call(_moodCalendarDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMoodSummary(themeProvider),
            ],
          ),
        );
      },
    );
  }

  Map<String, int> _calculateDashboardData(String period) {
    final now = DateTime.now();
    final itemsForPeriod = <PlannerItem>[];

    switch (period) {
      case 'daily':
        itemsForPeriod.addAll(_getItemsForDate(widget.selectedDate));
        break;
      case 'weekly':
        final weekStart = widget.selectedDate.subtract(Duration(days: widget.selectedDate.weekday - 1));
        for (int i = 0; i < 7; i++) {
          itemsForPeriod.addAll(_getItemsForDate(weekStart.add(Duration(days: i))));
        }
        break;
      case 'monthly':
        final monthStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
        final monthEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0);
        for (int i = 0; i < monthEnd.day; i++) {
          itemsForPeriod.addAll(_getItemsForDate(monthStart.add(Duration(days: i))));
        }
        break;
      case 'yearly':
        final yearStart = DateTime(widget.selectedDate.year, 1, 1);
        final yearEnd = DateTime(widget.selectedDate.year, 12, 31);
        for (int i = 0; i < yearEnd.difference(yearStart).inDays + 1; i++) {
          itemsForPeriod.addAll(_getItemsForDate(yearStart.add(Duration(days: i))));
        }
        break;
    }

    final total = itemsForPeriod.length;
    final completed = itemsForPeriod.where((item) => item.done).length;
    final pending = total - completed;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
    };
  }

  List<PlannerItem> _getItemsForDate(DateTime date) {
    final itemsForDate = <PlannerItem>[];
    final processedIds = <String>{};
    
    final targetDate = DateTime(date.year, date.month, date.day);
    
    for (final item in widget.items) {
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      
      bool shouldAppear = false;
      
      if (itemDate.isAtSameMomentAs(targetDate)) {
        shouldAppear = true;
      } else if (item.recurrence != null && 
                 (item.recurrence!.patterns.isNotEmpty || 
                  (item.recurrence!.customRules != null && item.recurrence!.customRules!.isNotEmpty)) &&
                 RecurrenceUtils.shouldAppearOnDate(item, date)) {
        shouldAppear = true;
      }
      
      if (shouldAppear && !processedIds.contains(item.id)) {
        if (itemDate.isAtSameMomentAs(targetDate)) {
          itemsForDate.add(item);
        } else {
          final virtualItem = RecurrenceUtils.createVirtualInstance(item, date);
          itemsForDate.add(virtualItem);
        }
        processedIds.add(item.id);
      }
    }
    
    return itemsForDate;
  }

  Widget _buildLegend(ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Completed', themeProvider.shade400),
        _buildLegendItem('Pending', themeProvider.infoColor),
        _buildLegendItem('Total', themeProvider.warningColor),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSummary(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMoodCalendar(themeProvider),
        const SizedBox(height: 20),
        _buildMoodSummarySection(themeProvider),
      ],
    );
  }

  Widget _buildMoodCalendar(ThemeProvider themeProvider) {
    final daysInMonth = DateTime(_moodCalendarDate.year, _moodCalendarDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_moodCalendarDate.year, _moodCalendarDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    
    // Calculate how many empty cells we need at the start
    final emptyCells = firstWeekday - 1;
    
    return Column(
      children: [
        // Month navigation header
        Container(
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
                  final newDate = DateTime(_moodCalendarDate.year, _moodCalendarDate.month - 1, 1);
                  setState(() {
                    _moodCalendarDate = newDate;
                  });
                  // Update main date to sync with mood calendar
                  widget.onDateChanged?.call(newDate);
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
                  '${_getMonthName(_moodCalendarDate.month)} ${_moodCalendarDate.year}',
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
                  final newDate = DateTime(_moodCalendarDate.year, _moodCalendarDate.month + 1, 1);
                  setState(() {
                    _moodCalendarDate = newDate;
                  });
                  // Update main date to sync with mood calendar
                  widget.onDateChanged?.call(newDate);
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
              if (!_isCurrentMonth(_moodCalendarDate))
                GestureDetector(
                  onTap: () {
                    final today = DateTime.now();
                    setState(() {
                      _moodCalendarDate = today;
                    });
                    // Update main date to sync with mood calendar
                    widget.onDateChanged?.call(today);
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
        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: emptyCells + daysInMonth,
          itemBuilder: (context, index) {
            if (index < emptyCells) {
              // Empty cells for days before the month starts
              return Container();
            }
            
                         final day = index - emptyCells + 1;
             final mood = _getMoodForDay(day, themeProvider);
            
            final isSelectedDate = day == widget.selectedDate.day && 
                                   _moodCalendarDate.month == widget.selectedDate.month && 
                                   _moodCalendarDate.year == widget.selectedDate.year;
            
            return GestureDetector(
              onTap: () => _showMoodSelectionDialog(day, themeProvider),
              child: Container(
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  color: mood.color,
                  shape: BoxShape.circle,
                  border: isSelectedDate ? Border.all(
                    color: themeProvider.shade400,
                    width: 2,
                  ) : null,
                ),
                child: Center(
                  child: Text(
                    mood.emoji.isNotEmpty ? mood.emoji : '$day',
                    style: TextStyle(
                      fontSize: mood.emoji.isNotEmpty ? 20 : 12,
                      color: mood.emoji.isNotEmpty ? null : (themeProvider.themeMode == ThemeMode.dark ? Colors.grey.shade300 : Colors.grey.shade600),
                      fontWeight: mood.emoji.isNotEmpty ? null : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  MoodData _getMoodForDay(int day, ThemeProvider themeProvider) {
    if (widget.moodData == null) {
      // If no mood data available, show empty circles for all days
      return MoodService.getEmptyMood(themeProvider);
    }

    final date = DateTime(_moodCalendarDate.year, _moodCalendarDate.month, day);
    
    // Check if we have mood data for this date
    final moodType = widget.moodData![date];
    
    if (moodType != null && moodType.isNotEmpty) {
      // Return the mood data for this date
      return MoodService.getMoodData(moodType, themeProvider);
    } else {
      // No mood set for this date - show empty circle
      return MoodService.getEmptyMood(themeProvider);
    }
  }

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'JANUARY';
      case 2: return 'FEBRUARY';
      case 3: return 'MARCH';
      case 4: return 'APRIL';
      case 5: return 'MAY';
      case 6: return 'JUNE';
      case 7: return 'JULY';
      case 8: return 'AUGUST';
      case 9: return 'SEPTEMBER';
      case 10: return 'OCTOBER';
      case 11: return 'NOVEMBER';
      case 12: return 'DECEMBER';
      default: return '';
    }
  }

  Widget _buildMoodSummarySection(ThemeProvider themeProvider) {
    final moodData = _calculateMoodData();
    
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
            'Mood Summary',
            style: GoogleFonts.dancingScript(
              color: themeProvider.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 24),
          _buildMoodDonutChart(moodData, themeProvider),
          const SizedBox(height: 16),
          //            MoodStreaksWidget(
          //    moodData: moodData,
          //    calendarDate: _moodCalendarDate,
          //    themeProvider: themeProvider,
          //  ),
        ],
      ),
    );
  }

  Widget _buildMoodDonutChart(Map<String, dynamic> moodData, ThemeProvider themeProvider) {
    final totalMoods = moodData['total'] as int;
    final sections = <PieChartSectionData>[];
    
    if (totalMoods == 0) {
      // Show grayed-out donut chart when no mood data is available
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade300.withOpacity(0.5),
          value: 1.0,
          title: '',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.transparent,
          ),
        ),
      );
    } else {
             // Show normal donut chart with mood data
       final moodColors = {
         'happy': MoodService.getColor('happy', themeProvider),
         'neutral': MoodService.getColor('neutral', themeProvider),
         'sad': MoodService.getColor('sad', themeProvider),
         'angry': MoodService.getColor('angry', themeProvider),
       };

      final moodEmojis = {
        'happy': '😊',
        'neutral': '😐',
        'sad': '😢',
        'angry': '😠',
      };

      moodData['distribution'].forEach((mood, count) {
        if (count > 0) {
          final percentage = (count / totalMoods * 100).round();
          sections.add(
            PieChartSectionData(
              color: moodColors[mood]!,
              value: count.toDouble(),
              title: '$percentage%',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          );
        }
      });
    }

    return SizedBox(
      height: 150,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  

  Map<String, dynamic> _calculateMoodData() {
    final moodDistribution = {'happy': 0, 'neutral': 0, 'sad': 0, 'angry': 0};
    final moodStreaks = {'happy': 0, 'neutral': 0, 'sad': 0, 'angry': 0};
    
    // Calculate mood distribution for the current month
    final monthStart = DateTime(_moodCalendarDate.year, _moodCalendarDate.month, 1);
    final monthEnd = DateTime(_moodCalendarDate.year, _moodCalendarDate.month + 1, 0);
    
    for (int i = 0; i < monthEnd.day; i++) {
      final date = monthStart.add(Duration(days: i));
      final mood = _getMoodForDate(date);
      if (mood.isNotEmpty) {
        moodDistribution[mood] = (moodDistribution[mood] ?? 0) + 1;
      }
    }
    
    // Calculate streaks
    final currentDate = DateTime.now();
    final currentStreak = _calculateCurrentStreak(currentDate);
    
    // Calculate longest streaks for each mood
    moodStreaks.forEach((mood, _) {
      moodStreaks[mood] = _calculateLongestStreak(mood, monthStart, monthEnd);
    });
    
    final total = moodDistribution.values.reduce((a, b) => a + b);
    
    return {
      'distribution': moodDistribution,
      'streaks': moodStreaks,
      'currentStreak': currentStreak,
      'total': total,
    };
  }

  String _getMoodForDate(DateTime date) {
    if (widget.moodData == null) return '';
    
    final dateKey = DateTime(date.year, date.month, date.day);
    return widget.moodData![dateKey] ?? '';
  }

  Map<String, dynamic>? _calculateCurrentStreak(DateTime currentDate) {
    if (widget.moodData == null) return null;
    
    final currentMood = _getMoodForDate(currentDate);
    if (currentMood.isEmpty) return null;
    
    int streak = 0;
    DateTime checkDate = currentDate;
    
    while (true) {
      final mood = _getMoodForDate(checkDate);
      if (mood == currentMood) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return {
      'mood': currentMood,
      'streak': streak,
    };
  }

  int _calculateLongestStreak(String mood, DateTime startDate, DateTime endDate) {
    if (widget.moodData == null) return 0;
    
    int longestStreak = 0;
    int currentStreak = 0;
    
    for (int i = 0; i < endDate.day; i++) {
      final date = startDate.add(Duration(days: i));
      final moodForDate = _getMoodForDate(date);
      
      if (moodForDate == mood) {
        currentStreak++;
        longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;
      } else {
        currentStreak = 0;
      }
    }
    
    return longestStreak;
  }

  void _showMoodSelectionDialog(int day, ThemeProvider themeProvider) {
    final selectedDate = DateTime(_moodCalendarDate.year, _moodCalendarDate.month, day);
    final currentMood = widget.moodData?[selectedDate];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: themeProvider.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Select Mood for ${_getMonthName(_moodCalendarDate.month)} $day',
            style: TextStyle(
              color: themeProvider.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMoodOption('😊', 'happy', currentMood == 'happy', themeProvider, selectedDate),
                  _buildMoodOption('😐', 'neutral', currentMood == 'neutral', themeProvider, selectedDate),
                  _buildMoodOption('😢', 'sad', currentMood == 'sad', themeProvider, selectedDate),
                  _buildMoodOption('😠', 'angry', currentMood == 'angry', themeProvider, selectedDate),
                ],
              ),
              const SizedBox(height: 16),
              if (currentMood != null && currentMood.isNotEmpty)
                TextButton(
                  onPressed: () {
                    widget.onMoodSelected?.call(selectedDate, '');
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Remove Mood',
                    style: TextStyle(
                      color: themeProvider.errorColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoodOption(String emoji, String moodType, bool isSelected, ThemeProvider themeProvider, DateTime selectedDate) {
    return GestureDetector(
      onTap: () {
        widget.onMoodSelected?.call(selectedDate, moodType);
        Navigator.of(context).pop();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? themeProvider.shade300 : MoodService.getColor(moodType, themeProvider),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: themeProvider.shade500, width: 2) : null,
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

 