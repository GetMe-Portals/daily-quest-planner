import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

/// Card widget to display upcoming tasks for today in a two-column layout, with all content fitting inside the card.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = Theme.of(context);
        final tasks = [
          TaskEntry(time: '10:00', text: 'Meeting with Mark', checked: true),
          TaskEntry(time: '', text: 'Email meeting notes to Anna', checked: true, ),
          TaskEntry(time: '11:45', text: 'Lunch with Anna', checked: false, highlight: true),
        ];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: UP NEXT / TODAY
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UP NEXT',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: themeProvider.textColor,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'TODAY',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: themeProvider.textColorSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Vertical divider
                Container(
                  width: 1,
                  height: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: themeProvider.dividerColor,
                ),
                // Right column: tasks in a vertically aligned Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: tasks.map((task) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _TaskEntryWidget(task: task, themeProvider: themeProvider),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TaskEntry {
  final String time;
  final String text;
  final bool checked;
  final bool highlight;
  final bool isCheckable;
  TaskEntry({
    required this.time,
    required this.text,
    this.checked = false,
    this.highlight = false,
    this.isCheckable = false,
  });
}

class _TaskEntryWidget extends StatelessWidget {
  final TaskEntry task;
  final ThemeProvider themeProvider;
  const _TaskEntryWidget({required this.task, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: themeProvider.textColor,
      fontSize: 15,
    );
    if (task.isCheckable) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: task.checked,
            onChanged: (_) {},
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            activeColor: theme.colorScheme.secondary,
          ),
          Expanded(
            child: Text(
              task.text,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    } else if (task.highlight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: themeProvider.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${task.time} ${task.text}',
          style: textStyle,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: themeProvider.dividerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${task.time} ${task.text}',
          style: textStyle,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }
  }
} 