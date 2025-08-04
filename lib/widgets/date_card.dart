import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DateCard extends StatelessWidget {
  final DateTime date;
  final String timeRange;
  final double progress;
  final VoidCallback? onTap;

  const DateCard({
    super.key,
    required this.date,
    required this.timeRange,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 160,
            constraints: const BoxConstraints(
              minHeight: 170,
              maxHeight: 190,
            ),
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
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top section with day name and date
                  Column(
                    children: [
                      // Day name - centered and larger
                      Text(
                        _getDayName(date),
                        style: GoogleFonts.dancingScript(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: themeProvider.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      
                      // Date - centered with proper line height
                      Text(
                        _getDateString(date, timeRange),
                        style: TextStyle(
                          fontSize: 14,
                          color: themeProvider.textColor,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Progress section
                  Column(
                    children: [
                      // Progress bar - moved below date
                      Center(
                        child: SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: themeProvider.dividerColor,
                            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progress)),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Percentage - centered below progress bar
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.dividerColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getDayName(DateTime date) {
    switch (timeRange) {
      case 'weekly':
        return 'This Week';
      case 'monthly':
        return 'This Month';
      case 'yearly':
        return 'This Year';
      default:
        return _getDayOfWeek(date);
    }
  }

  String _getDateString(DateTime date, String timeRange) {
    switch (timeRange) {
      case 'weekly':
        final startOfWeek = _getStartOfWeek(date);
        final endOfWeek = _getEndOfWeek(date);
        return '${_formatDate(startOfWeek)}\n-\n${_formatDate(endOfWeek)}';
      case 'monthly':
        return '${_getMonthName(date)} ${date.year}';
      case 'yearly':
        return '${date.year}';
      default:
        return _formatDate(date);
    }
  }

  String _getDayOfWeek(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[date.month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date).substring(0, 3)} ${date.year}';
  }

  DateTime _getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  DateTime _getEndOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.add(Duration(days: 7 - weekday));
  }

  Color _getProgressColor(double progress) {
    final percentage = progress * 100;
    if (percentage <= 50) {
      return Colors.red;
    } else if (percentage <= 75) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
} 