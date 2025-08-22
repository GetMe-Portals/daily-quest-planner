import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/planner_item.dart';
import '../theme/app_theme.dart';
import 'task_row_widget.dart';

class WeeklyDayCard extends StatefulWidget {
  final String dayName;
  final DateTime date;
  final List<PlannerItem> tasks;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;
  final Function(DateTime) onAddTask;
  final Function(PlannerItem) onToggleTask;
  final Function(PlannerItem)? onDeleteTask;
  final Function(PlannerItem)? onEditTask;
  final Function(PlannerItem)? onToggleImportantTask;
  final bool isExpanded;

  const WeeklyDayCard({
    Key? key,
    required this.dayName,
    required this.date,
    required this.tasks,
    required this.themeProvider,
    required this.onTap,
    required this.onAddTask,
    required this.onToggleTask,
    this.onDeleteTask,
    this.onEditTask,
    this.onToggleImportantTask,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  State<WeeklyDayCard> createState() => _WeeklyDayCardState();
}

class _WeeklyDayCardState extends State<WeeklyDayCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  void didUpdateWidget(WeeklyDayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      setState(() {
        _isExpanded = widget.isExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedTasks = widget.tasks.where((task) => task.done).length;
    final totalTasks = widget.tasks.length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDayColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.themeProvider.shade400.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Header row with day info and controls
                    Row(
                      children: [
                        // Day name and date
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.dayName,
                                style: GoogleFonts.dancingScript(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: widget.themeProvider.textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(widget.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.themeProvider.textColorSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Task count and progress
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '$completedTasks/$totalTasks',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: widget.themeProvider.textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (totalTasks > 0)
                                Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: widget.themeProvider.dividerColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: widget.themeProvider.shade400,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Add task button
                        IconButton(
                          onPressed: () => widget.onAddTask(widget.date),
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: widget.themeProvider.shade400,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        
                        // Expand/collapse arrow
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          icon: Icon(
                            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: widget.themeProvider.shade400,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    // Integrated task list for all days (Option 1) with animation
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      child: _isExpanded
                          ? Column(
                              children: [
                                const SizedBox(height: 6),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  width: double.infinity,
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                const SizedBox(height: 6),
                                widget.tasks.isNotEmpty
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ...widget.tasks.map((task) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: TaskRowWidget(
                                              item: task,
                                              themeProvider: widget.themeProvider,
                                              onToggle: () => widget.onToggleTask(task),
                                              onDelete: widget.onDeleteTask != null ? () => widget.onDeleteTask!(task) : null,
                                              onEdit: widget.onEditTask != null ? () => widget.onEditTask!(task) : null,
                                              onToggleImportant: () => widget.onToggleImportantTask != null ? widget.onToggleImportantTask!(task) : null,
                                            ),
                                          )).toList(),
                                        ],
                                      )
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 3),
                                          child: Text(
                                            'No plan for the day',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: widget.themeProvider.textColorSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          

        ],
      ),
    );
  }

  Color _getDayColor() {
    // Different background colors for each day - theme aware
    final isDark = widget.themeProvider.themeMode == ThemeMode.dark;
    
    switch (widget.dayName.toLowerCase()) {
      case 'monday':
        return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF3E5F5); // Dark navy/Light purple
      case 'tuesday':
        return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFFF3E0); // Dark navy/Light orange
      case 'wednesday':
        return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8F5E8); // Dark navy/Light green
      case 'thursday':
        return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE3F2FD); // Dark navy/Light blue
      case 'friday':
        return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFFF8E1); // Dark navy/Light yellow
      case 'saturday':
        return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFCE4EC); // Dark navy/Light pink
      case 'sunday':
        return isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF1F8E9); // Dark navy/Light green
      default:
        return isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF5F5F5); // Dark/Light grey
    }
  }

  String _formatDate(DateTime date) {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${monthNames[date.month - 1]} ${date.day}';
  }
} 