import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/mood_service.dart';

class MoodStreaksWidget extends StatelessWidget {
  final Map<String, dynamic> moodData;
  final DateTime calendarDate;
  final ThemeProvider themeProvider;

  const MoodStreaksWidget({
    Key? key,
    required this.moodData,
    required this.calendarDate,
    required this.themeProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final streaks = moodData['streaks'] as Map<String, int>;
    final currentStreak = moodData['currentStreak'] as Map<String, dynamic>?;
    
    // Get the number of days in the current month for max progress
    final daysInMonth = DateTime(calendarDate.year, calendarDate.month + 1, 0).day;
    final maxProgress = daysInMonth.toDouble();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood Streaks',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: themeProvider.textColor,
          ),
        ),
        const SizedBox(height: 12),
        ...streaks.entries.map((entry) {
          final mood = entry.key;
          final streak = entry.value;
          final emoji = _getMoodEmoji(mood);
          final isCurrentStreak = currentStreak != null && currentStreak['mood'] == mood;
          final progress = streak > 0 ? (streak / maxProgress).clamp(0.0, 1.0) : 0.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mood label and emoji
                Row(
                  children: [
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _capitalizeFirst(mood),
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.textColor,
                        fontWeight: isCurrentStreak ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isCurrentStreak) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: themeProvider.shade400.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 10,
                            color: themeProvider.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: themeProvider.dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getMoodProgressColor(mood),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$streak days',
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.textColorSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  String _getMoodEmoji(String mood) {
    switch (mood) {
      case 'happy': return '😊';
      case 'neutral': return '😐';
      case 'sad': return '😢';
      case 'angry': return '😠';
      default: return '';
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Color _getMoodProgressColor(String mood) {
    // Use the same colors as the mood bars for consistency
    return MoodService.getColor(mood, themeProvider);
  }
}
