import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final String timeRange;
  final DateTime? selectedDate;

  const EmptyStateWidget({
    super.key,
    required this.timeRange,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // GIF Animation Container
              Container(
                width: 200,
                height: 200,
                child: Image.asset(
                  _getAnimationForTheme(themeProvider),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              
              // Message
              Text(
                _getEmptyMessage(),
                style: TextStyle(
                  fontSize: 14, // Reduced font size for better proportion
                  fontWeight: FontWeight.w500, // Slightly reduced weight for better proportion
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Encouraging text
              Text(
                _getEncouragingMessage(),
                style: GoogleFonts.dancingScript(
                  fontSize: 16,
                  color: themeProvider.textColorSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  String _getEmptyMessage() {
    switch (timeRange) {
      case 'weekly':
        return 'No items for this week';
      case 'monthly':
        return 'No items for this month';
      case 'yearly':
        return 'No items for this year';
      default:
        // Check if this is today or a selected date
        if (selectedDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final selectedDay = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
          
          if (selectedDay.isAtSameMomentAs(today)) {
            return 'No Plans for Today';
          } else {
            // Format the date as MMM dd (e.g., "Aug 31")
            final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                               'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            final monthName = monthNames[selectedDate!.month - 1];
            final day = selectedDate!.day.toString().padLeft(2, '0');
            return 'No Plans for $monthName $day';
          }
        }
        return 'No Plans for Today';
    }
  }

  String _getEncouragingMessage() {
    switch (timeRange) {
      case 'weekly':
        return 'Start planning your week by adding tasks, routines, or events!';
      case 'monthly':
        return 'Start planning your month by adding tasks, routines, or events!';
      case 'yearly':
        return 'Start planning your year by adding tasks, routines, or events!';
      default:
        return 'Start Planning Your Day';
    }
  }

  String _getAnimationForTheme(ThemeProvider themeProvider) {
    // Get the theme name based on the selected color
    final selectedColor = themeProvider.selectedThemeColor;
    
    if (selectedColor == Colors.teal) {
      return 'assets/animations/no_plan_teal.gif';
    } else if (selectedColor == Colors.pink) {
      return 'assets/animations/no_plan_pink.gif';
    } else if (selectedColor == CustomMaterialColor.burgundy) {
      return 'assets/animations/no_plan_burgundy.gif';
    } else if (selectedColor == CustomMaterialColor.slate) {
      return 'assets/animations/no_plan_slate.gif';
    } else {
      return 'assets/animations/no_plan_teal.gif'; // Default to teal
    }
  }
} 