import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ColorPickerDialog extends StatelessWidget {
  const ColorPickerDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('ColorPickerDialog build called');
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Dialog(
          backgroundColor: themeProvider.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.palette,
                      color: themeProvider.textColorSecondary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Choose Theme Color',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Color grid
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    print('Consumer builder called, selected color: ${themeProvider.selectedThemeColor}');
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: ThemeProvider.baseColors.length,
                      itemBuilder: (context, index) {
                        final color = ThemeProvider.baseColors[index];
                        final isSelected = themeProvider.selectedThemeColor == color;
                        
                        return GestureDetector(
                          onTap: () async {
                            themeProvider.setBaseColor(color);
                            
                            Navigator.of(context).pop();
                            
                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Theme color updated!'),
                                backgroundColor: color.shade400,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color.shade400 : themeProvider.dividerColor,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: color.shade200.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ] : [
                                BoxShadow(
                                  color: themeProvider.shadowColor,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Color preview circle
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.shade400,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: themeProvider.cardColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color: themeProvider.cardColor,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                // Color name
                                Text(
                                  _getColorName(color),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.textColorSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getColorName(MaterialColor color) {
    switch (color) {
      case Colors.pink:
        return 'Pink';
      case Colors.teal:
        return 'Teal';
      case CustomMaterialColor.slate:
        return 'Slate';
      case CustomMaterialColor.burgundy:
        return 'Burgundy';
      default:
        return 'Color';
    }
  }
} 