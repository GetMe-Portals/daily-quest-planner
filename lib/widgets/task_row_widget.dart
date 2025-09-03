import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/planner_item.dart';
import '../theme/app_theme.dart';
import 'sun_checkbox.dart';

class TaskRowWidget extends StatelessWidget {
  final PlannerItem item;
  final ThemeProvider themeProvider;
  final VoidCallback onToggle;
  final bool flash;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleImportant; // NEW: callback for toggling important status

  const TaskRowWidget({
    Key? key,
    required this.item,
    required this.themeProvider,
    required this.onToggle,
    this.flash = false,
    this.onDelete,
    this.onEdit,
    this.onToggleImportant, // NEW: optional callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

    Widget taskContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        border: Border.all(
          color: item.isImportant 
              ? Colors.amber.withOpacity(0.3) 
              : themeProvider.dividerColor.withOpacity(0.05),
          width: item.isImportant ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: item.isImportant 
            ? Colors.amber.withOpacity(0.05) 
            : Colors.transparent,
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: themeProvider.dividerColor.withOpacity(0.05), // Made very light transparent gray
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
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
                          style: TextStyle(
                            fontWeight: item.isImportant ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 14,
                            decoration: item.done ? TextDecoration.lineThrough : null,
                            color: item.done ? themeProvider.textColorSecondary : themeProvider.textColor,
                          ),
                        ),
                      ),
                      if (durationLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            durationLabel, 
                            style: TextStyle(
                              fontSize: 12, 
                              color: themeProvider.shade400, 
                              fontWeight: FontWeight.w600
                            )
                          ),
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
            // Star icon for important tasks
            if (onToggleImportant != null)
              GestureDetector(
                onTap: onToggleImportant,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    item.isImportant ? Icons.star : Icons.star_border,
                    color: item.isImportant ? Colors.amber : themeProvider.textColorSecondary,
                    size: 20,
                  ),
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
      );

    // Wrap with GestureDetector for edit if onEdit is provided
    Widget finalWidget = _AnimatedFlashRow(
      flash: flash,
      child: taskContent,
    );

    if (onEdit != null) {
      finalWidget = GestureDetector(
        onTap: onEdit,
        child: finalWidget,
      );
    }

    // Wrap with Dismissible if onDelete is provided
    if (onDelete != null) {
      final itemKey = item.hashCode.toString() + item.name;
      return Dismissible(
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
        onDismissed: (direction) {
          onDelete!();
        },
        child: finalWidget,
      );
    }

    return finalWidget;
  }

  Color _getTypeColor(String type, ThemeProvider themeProvider) {
    switch (type.toLowerCase()) {
      case 'task':
        return themeProvider.shade400;
      case 'routine':
        return Colors.orange;
      case 'event':
        return Colors.blue;
      case 'shopping':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Helper method to capitalize only the first letter of the entire task name
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    
    // If first letter is already capital, return as is
    if (text[0] == text[0].toUpperCase()) return text;
    
    // Only capitalize the first letter, keep the rest exactly as typed
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _AnimatedFlashRow extends StatefulWidget {
  final Widget child;
  final bool flash;

  const _AnimatedFlashRow({
    required this.child,
    required this.flash,
  });

  @override
  State<_AnimatedFlashRow> createState() => _AnimatedFlashRowState();
}

class _AnimatedFlashRowState extends State<_AnimatedFlashRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_AnimatedFlashRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flash && !oldWidget.flash) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}


