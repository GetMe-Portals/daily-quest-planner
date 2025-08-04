import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final String timeRange;

  const EmptyStateWidget({
    super.key,
    required this.timeRange,
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
                  'assets/animations/no_plan.gif',
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
                style: TextStyle(
                  fontSize: 14,
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
        return 'No items for today';
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
        return 'Start planning your day by adding tasks, routines, or events!';
    }
  }
} 