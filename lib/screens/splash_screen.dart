import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme.dart' show CustomMaterialColor;

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashComplete;

  const SplashScreen({
    super.key,
    required this.onSplashComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      _fadeController.forward();
      _scaleController.forward();
    }
    
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      widget.onSplashComplete();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  String _getLogoForTheme(ThemeProvider themeProvider) {
    // Get the current theme color and map it to the appropriate logo
    final currentColor = themeProvider.selectedThemeColor;
    
    if (currentColor == Colors.teal) {
      return 'assets/images/daily_quest_logo_teal.png';
    } else if (currentColor == Colors.pink) {
      return 'assets/images/daily_quest_logo_pink.png';
    } else if (currentColor == CustomMaterialColor.burgundy) {
      return 'assets/images/daily_quest_logo_burgundy.png';
    } else if (currentColor == CustomMaterialColor.slate) {
      return 'assets/images/daily_quest_logo_slate.png';
    } else {
      // Default fallback
      return 'assets/images/daily_quest_logo_teal.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: themeProvider.backgroundColor,
          body: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeController, _scaleController]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Image.asset(
                          _getLogoForTheme(themeProvider),
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 32),
                        
                        // App title
                        Text(
                          'Daily Quest',
                          style: GoogleFonts.dancingScript(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.shade400,
                            shadows: [
                              Shadow(
                                color: themeProvider.shadowColor,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Subtitle
                        Text(
                          'PLANNER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.shade400,
                            letterSpacing: 2,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 48),
                        
                        // Loading indicator
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(themeProvider.shade300),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
} 