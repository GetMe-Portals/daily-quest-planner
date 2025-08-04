import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/planner_item.dart';

class CustomCalendarCard extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime focusedDate;
  final List<PlannerItem> items;
  final Function(DateTime) onDateSelected;
  final Function(DateTime) onPageChanged;

  const CustomCalendarCard({
    super.key,
    required this.selectedDate,
    required this.focusedDate,
    required this.items,
    required this.onDateSelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          width: 200,
          height: 220, // Increased height to accommodate all 6 weeks
          decoration: BoxDecoration(
            color: themeProvider.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: themeProvider.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with navigation
              _buildHeader(themeProvider),
              Divider(height: 0.5, color: themeProvider.dividerColor), // Reduced divider height
              // Calendar grid
              Expanded(
                child: _buildCalendarGrid(themeProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Container(
      height: 32, // Further reduced header height to save more space
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.chevron_left, color: themeProvider.textColor, size: 20),
              onPressed: () {
                final previousMonth = DateTime(focusedDate.year, focusedDate.month - 1);
                onPageChanged(previousMonth);
              },
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_getMonthName(focusedDate)} ${focusedDate.year}',
                style: TextStyle(
                  fontSize: 13, // Reduced font size to save space
                  fontWeight: FontWeight.w500,
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.chevron_right, color: themeProvider.textColor, size: 20),
              onPressed: () {
                final nextMonth = DateTime(focusedDate.year, focusedDate.month + 1);
                onPageChanged(nextMonth);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeProvider themeProvider) {
    final daysInMonth = DateTime(focusedDate.year, focusedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(focusedDate.year, focusedDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced vertical padding
      child: Column(
        children: [
          // Day headers
          SizedBox(
            height: 18, // Reduced day header height
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          // Calendar days
          Expanded(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                // Convert weekday to Monday-based (Monday=0, Sunday=6)
                final mondayBasedWeekday = (firstWeekday - 1) % 7;
                final dayOffset = index - mondayBasedWeekday;
                final day = dayOffset + 1;
                
                if (dayOffset < 0 || day > daysInMonth) {
                  return const SizedBox.shrink();
                }
                
                final date = DateTime(focusedDate.year, focusedDate.month, day);
                final isSelected = _isSameDate(date, selectedDate);
                final isToday = _isSameDate(date, DateTime.now());
                final hasItems = _hasItemsForDate(date);
                
                return _buildDayCell(date, day, isSelected, isToday, hasItems, themeProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, int day, bool isSelected, bool isToday, bool hasItems, ThemeProvider themeProvider) {
    return GestureDetector(
      onTap: () => onDateSelected(date),
      child: Container(
        margin: const EdgeInsets.all(0.5), // Reduced margin to save space
        decoration: BoxDecoration(
          // Show background for today's date (regardless of selection)
          color: isToday ? themeProvider.shade400.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          // Show border only for selected dates
          border: isSelected ? Border.all(color: themeProvider.shade400.withOpacity(0.3), width: 1) : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? themeProvider.shade700 : themeProvider.textColor,
                ),
              ),
            ),
            if (hasItems)
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: themeProvider.shade100,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  bool _hasItemsForDate(DateTime date) {
    return items.any((item) => _isSameDate(item.date, date));
  }

  String _getMonthName(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[date.month - 1];
  }
} 