import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Daily Quest Planner',
      description: 'Your personal companion for organizing tasks, routines, and events with ease.',
      icon: Icons.calendar_today,
    ),
    OnboardingPage(
      title: 'Smart Planning',
      description: 'Create recurring tasks, set reminders, and track your progress and mood with beautiful visualizations.',
      icon: Icons.insights,
    ),
    OnboardingPage(
      title: 'Choose Your Style',
      description: 'Switch between 4 beautiful color themes to match your vibe!',
      icon: Icons.palette,
    ),
    OnboardingPage(
      title: 'Ready to Start?',
      description: 'Begin your journey to better productivity and organization.',
      icon: Icons.rocket_launch,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: themeProvider.backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: themeProvider.textColorSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], themeProvider);
                    },
                  ),
                ),
                _buildBottomSection(themeProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage(OnboardingPage page, ThemeProvider themeProvider) {
    final isLastPage = _pages.indexOf(page) == _pages.length - 1;
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: themeProvider.shade300,
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: themeProvider.shade100,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: themeProvider.cardColor,
            ),
          ),
          const SizedBox(height: 48),
          
          // Title
          Text(
            page.title,
            style: GoogleFonts.dancingScript(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: themeProvider.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: themeProvider.textColorSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Visual highlight section for the last page
          if (isLastPage) ...[
            const SizedBox(height: 40),
            _buildFeatureHighlights(themeProvider),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights(ThemeProvider themeProvider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.security,
          size: 20,
          color: themeProvider.shade400,
        ),
        const SizedBox(width: 12),
        Text(
          'Your data is always safe, even offline',
          style: TextStyle(
            fontSize: 14,
            color: themeProvider.textColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }



  Widget _buildBottomSection(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentPage 
                    ? themeProvider.shade300 
                    : themeProvider.dividerColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Next/Get Started button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.shade300,
                foregroundColor: themeProvider.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: themeProvider.shade100,
              ),
              child: Text(
                _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });
} 