import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Custom MaterialColor for #4A5A75
class CustomMaterialColor {
  static const MaterialColor slate = MaterialColor(
    0xFF4A5A75, // Primary color
    <int, Color>{
      50: Color(0xFFE8EAED),
      100: Color(0xFFC5CBD3),
      200: Color(0xFF9FA8B5),
      300: Color(0xFF798597),
      400: Color(0xFF5D6A7E),
      500: Color(0xFF4A5A75), // Primary
      600: Color(0xFF43526D),
      700: Color(0xFF3A4862),
      800: Color(0xFF323F58),
      900: Color(0xFF222E45),
    },
  );
  
  static const MaterialColor burgundy = MaterialColor(
    0xFF5C0120, // Primary color
    <int, Color>{
      50: Color(0xFFF2E6E9),
      100: Color(0xFFE0BFC7),
      200: Color(0xFFCC95A2),
      300: Color(0xFFB86B7D),
      400: Color(0xFFA44C62),
      500: Color(0xFF5C0120), // Primary
      600: Color(0xFF52011C),
      700: Color(0xFF470118),
      800: Color(0xFF3D0114),
      900: Color(0xFF2E000F),
    },
  );
  
  static const MaterialColor crimson = MaterialColor(
    0xFFD90416, // Primary color
    <int, Color>{
      50: Color(0xFFFDE6E8),
      100: Color(0xFFFABFC4),
      200: Color(0xFFF7959D),
      300: Color(0xFFF46B76),
      400: Color(0xFFF14C59),
      500: Color(0xFFD90416), // Primary
      600: Color(0xFFC30414),
      700: Color(0xFFAA0311),
      800: Color(0xFF91030F),
      900: Color(0xFF6E020B),
    },
  );
}

/// Central theme definitions for the app, including light and dark color schemes.
class AppTheme {
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color darkBackground = Color(0xFF181A20);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF23262F);
  static const Color accentPink = Color(0xFFFFE0E9);
  static const Color accentBlue = Color(0xFFE0F0FF);

  static const Color accentGreen = Color(0xFFE0FFE6);
  static const Color accentYellow = Color(0xFFFFF9E0);
  static const Color accentPurple = Color(0xFFEDE0FF);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    cardColor: cardLight,
    colorScheme: ColorScheme.light(
      primary: accentBlue,
      secondary: accentPink,
      background: lightBackground,
      surface: cardLight,
      onBackground: Colors.black87,
      onSurface: Colors.black87,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Serif',
        fontWeight: FontWeight.bold,
        fontSize: 32,
        color: Colors.black87,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
    ),
    useMaterial3: true,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    cardColor: cardDark,
    colorScheme: ColorScheme.dark(
      primary: accentBlue,
      secondary: accentPink,
      background: darkBackground,
      surface: cardDark,
      onBackground: Colors.white,
      onSurface: Colors.white,
      onPrimary: Colors.black87,
      onSecondary: Colors.black87,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Serif',
        fontWeight: FontWeight.bold,
        fontSize: 32,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Colors.white,
      ),
    ),
    useMaterial3: true,
  );
}

/// Provider for theme switching using Provider package.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  // Base color selection
  MaterialColor _selectedThemeColor = Colors.teal;
  MaterialColor get selectedThemeColor => _selectedThemeColor;

  // Available base colors
  static const List<MaterialColor> baseColors = [
    Colors.pink,
    Colors.teal,
    CustomMaterialColor.burgundy,
    CustomMaterialColor.slate,
  ];

  ThemeProvider() {
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    final savedColorIndex = prefs.getInt('selected_color_index') ?? 1;
    
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    if (savedColorIndex < baseColors.length) {
      _selectedThemeColor = baseColors[savedColorIndex];
    }
    notifyListeners();
  }

  Future<void> _saveThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _themeMode == ThemeMode.dark);
    await prefs.setInt('selected_color_index', baseColors.indexOf(_selectedThemeColor));
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveThemeSettings();
    notifyListeners();
  }

  void setBaseColor(MaterialColor color) {
    _selectedThemeColor = color;
    _saveThemeSettings();
    notifyListeners();
  }

  // Helper methods to get consistent shade values
  Color get shade50 => _selectedThemeColor.shade50;
  Color get shade100 => _selectedThemeColor.shade100;
  Color get shade200 => _selectedThemeColor.shade200;
  Color get shade300 => _selectedThemeColor.shade300;
  Color get shade400 => _selectedThemeColor.shade400;
  Color get shade500 => _selectedThemeColor.shade500;
  Color get shade600 => _selectedThemeColor.shade600;
  Color get shade700 => _selectedThemeColor.shade700;
  Color get shade800 => _selectedThemeColor.shade800;
  Color get shade900 => _selectedThemeColor.shade900;

  // Theme-aware color getters
  Color get backgroundColor => _themeMode == ThemeMode.dark 
    ? AppTheme.darkBackground 
    : AppTheme.lightBackground;
    
  Color get cardColor => _themeMode == ThemeMode.dark 
    ? AppTheme.cardDark 
    : AppTheme.cardLight;
    
  Color get textColor => _themeMode == ThemeMode.dark 
    ? Colors.white 
    : Colors.black87;
    
  Color get textColorSecondary => _themeMode == ThemeMode.dark 
    ? Colors.white70 
    : Colors.black54;
    
  Color get iconColor => _themeMode == ThemeMode.dark 
    ? Colors.white 
    : Colors.black87;
    
  Color get dividerColor => _themeMode == ThemeMode.dark 
    ? Colors.white24 
    : Colors.black12;
    
  Color get shadowColor => _themeMode == ThemeMode.dark 
    ? Colors.black54 
    : Colors.black12;
    
  Color get overlayColor => _themeMode == ThemeMode.dark 
    ? Colors.black54 
    : Colors.black26;
    
  Color get successColor => Colors.green.shade400;
  Color get errorColor => Colors.red.shade400;
  Color get warningColor => Colors.orange.shade400;
  Color get infoColor => Colors.blue.shade400;
  
  // Burgundy color
  Color get burgundyColor => const Color(0xFF5C0120);
} 