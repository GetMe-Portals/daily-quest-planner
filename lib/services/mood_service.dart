import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodService {
  // Get mood data by mood type with theme-aware colors
  static MoodData getMoodData(String moodType, ThemeProvider themeProvider) {
    final emoji = _getEmoji(moodType);
    final color = _getMoodColor(moodType, themeProvider);
    return MoodData(emoji, color);
  }

  // Get all available mood types
  static List<String> getMoodTypes() {
    return ['happy', 'neutral', 'sad', 'angry'];
  }

  // Get emoji for mood type
  static String getEmoji(String moodType) {
    return _getEmoji(moodType);
  }

  // Get color for mood type with theme awareness
  static Color getColor(String moodType, ThemeProvider themeProvider) {
    return _getMoodColor(moodType, themeProvider);
  }

  // Get neutral/empty mood data for dates without mood
  static MoodData getEmptyMood(ThemeProvider themeProvider) {
    if (themeProvider.themeMode == ThemeMode.dark) {
      return MoodData('', Colors.grey.shade700);
    } else {
      return MoodData('', Colors.grey.shade200);
    }
  }

  // Private helper methods
  static String _getEmoji(String moodType) {
    switch (moodType) {
      case 'happy':
        return '😊';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      default:
        return '';
    }
  }

  static Color _getMoodColor(String moodType, ThemeProvider themeProvider) {
          // Use theme-aware colors that work well in both light and dark modes
      if (themeProvider.themeMode == ThemeMode.dark) {
        // Dark mode colors - same as light mode but with 70% transparency
        switch (moodType) {
          case 'happy':
            return const Color(0xFFE3F2FD).withOpacity(0.7); // Soft light blue with transparency
          case 'neutral':
            return const Color(0xFFF3E5F5).withOpacity(0.7); // Soft light purple with transparency
          case 'sad':
            return const Color(0xFFFCE4EC).withOpacity(0.7); // Soft light pink with transparency
          case 'angry':
            return const Color(0xFFFFF8E1).withOpacity(0.7); // Soft light yellow/cream with transparency
          default:
            return themeProvider.cardColor.withOpacity(0.7);
        }
    } else {
      // Light mode colors - light pastel backgrounds
      switch (moodType) {
        case 'happy':
          return const Color(0xFFE3F2FD); // Soft light blue
        case 'neutral':
          return const Color(0xFFF3E5F5); // Soft light purple
        case 'sad':
          return const Color(0xFFFCE4EC); // Soft light pink
        case 'angry':
          return const Color(0xFFFFF8E1); // Soft light yellow/cream
        default:
          return themeProvider.cardColor;
      }
    }
  }
}

class MoodData {
  final String emoji;
  final Color color;
  
  const MoodData(this.emoji, this.color);
} 