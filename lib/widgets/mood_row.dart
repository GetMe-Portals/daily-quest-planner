import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

/// Mood tracker row with 4 basic emoji faces and pastel backgrounds.
class MoodRow extends StatelessWidget {
  final String? selectedMood;
  final Function(String) onMoodSelected;

  const MoodRow({
    super.key,
    this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MoodButton(
              emoji: '😊',
              mood: 'happy',
              isSelected: selectedMood == 'happy',
              onTap: () => onMoodSelected(selectedMood == 'happy' ? '' : 'happy'),
              themeProvider: themeProvider,
            ),
            const SizedBox(width: 6),
            _MoodButton(
              emoji: '😐',
              mood: 'neutral',
              isSelected: selectedMood == 'neutral',
              onTap: () => onMoodSelected(selectedMood == 'neutral' ? '' : 'neutral'),
              themeProvider: themeProvider,
            ),
            const SizedBox(width: 6),
            _MoodButton(
              emoji: '😢',
              mood: 'sad',
              isSelected: selectedMood == 'sad',
              onTap: () => onMoodSelected(selectedMood == 'sad' ? '' : 'sad'),
              themeProvider: themeProvider,
            ),
            const SizedBox(width: 6),
            _MoodButton(
              emoji: '😠',
              mood: 'angry',
              isSelected: selectedMood == 'angry',
              onTap: () => onMoodSelected(selectedMood == 'angry' ? '' : 'angry'),
              themeProvider: themeProvider,
            ),
          ],
        );
      },
    );
  }
}

class _MoodButton extends StatelessWidget {
  final String emoji;
  final String mood;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeProvider themeProvider;

  const _MoodButton({
    required this.emoji,
    required this.mood,
    required this.isSelected,
    required this.onTap,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getMoodColor(),
          borderRadius: BorderRadius.circular(12), // Changed from circle to rounded rectangle
          border: isSelected ? Border.all(color: themeProvider.shade300, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: themeProvider.shadowColor,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }

  Color _getMoodColor() {
    // Use theme-aware colors that work well in both light and dark modes
    if (themeProvider.themeMode == ThemeMode.dark) {
      // Dark mode colors - subtle transparent backgrounds
      switch (mood) {
        case 'happy':
          return const Color(0xFF2196F3).withOpacity(0.25); // Light blue
        case 'neutral':
          return const Color(0xFF9C27B0).withOpacity(0.25); // Light purple
        case 'sad':
          return const Color(0xFFE91E63).withOpacity(0.25); // Light pink
        case 'angry':
          return const Color(0xFFFF9800).withOpacity(0.25); // Light orange
        default:
          return themeProvider.cardColor.withOpacity(0.15);
      }
    } else {
      // Light mode colors - light pastel backgrounds
      switch (mood) {
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