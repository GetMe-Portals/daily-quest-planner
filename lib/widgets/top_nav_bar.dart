import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'color_picker_dialog.dart';


class TopNavBar extends StatelessWidget {
  const TopNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const Spacer(),
        ],
      ),
        );
      },
    );
  }
}

// Reuse the logo widget from bottom_nav_bar.dart
class DailyQuestLogo extends StatelessWidget {
  const DailyQuestLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return SizedBox(
      width: 150, // Adjust as needed for best fit
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              style: GoogleFonts.dancingScript(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: 'Daily',
                  style: TextStyle(
                        color: themeProvider.shade400,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: themeProvider.shadowColor, blurRadius: 2)],
                  ),
                ),
                TextSpan(
                  text: 'Quest',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: themeProvider.shadowColor, blurRadius: 2)],
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -4), // Move 'Planner' up to reduce space
            child: Text(
              'Planner',
              style: TextStyle(
                    color: themeProvider.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                letterSpacing: 1,
                fontFamily: 'Roboto', // Not cursive
              ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}

// Reuse the settings panel from bottom_nav_bar.dart
class SettingsPanel extends StatelessWidget {
  final bool left;
  const SettingsPanel({super.key, this.left = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Align(
          alignment: left ? Alignment.bottomLeft : Alignment.topRight,
          child: Container(
            width: 140,
            constraints: const BoxConstraints(
              minHeight: 120,
              maxHeight: 200,
            ),
            margin: left 
              ? const EdgeInsets.only(left: 8, bottom: 56)
              : const EdgeInsets.only(right: 8, top: 56),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: themeProvider.shadowColor,
                  blurRadius: 16,
                  offset: left 
                    ? const Offset(4, -4)
                    : const Offset(-4, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.account_circle, size: 32, color: themeProvider.infoColor),
                  onPressed: () {},
                  tooltip: 'Profile',
                ),
                IconButton(
                  icon: Icon(
                    themeProvider.themeMode == ThemeMode.dark 
                      ? Icons.light_mode 
                      : Icons.dark_mode, 
                    size: 28, 
                    color: themeProvider.warningColor
                  ),
                  onPressed: () {
                    themeProvider.toggleTheme();
                    Navigator.of(context).pop();
                  },
                  tooltip: 'Toggle Dark/Light Mode',
                ),
                IconButton(
                  icon: const Text('🎨', style: TextStyle(fontSize: 28)),
                  onPressed: () {
                    print('Color palette icon tapped!');
                    // Close the settings panel first
                    Navigator.of(context).pop();
                    // Then show the color picker dialog
                    Future.delayed(const Duration(milliseconds: 100), () {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) => const ColorPickerDialog(),
                      );
                    });
                  },
                  tooltip: 'Color Palette',
                ),

              ],
            ),
          ),
        );
      },
    );
  }
} 