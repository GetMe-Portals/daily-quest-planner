import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await WidgetService.initialize();
  
  // Initialize notification service non-blocking (in background) with timeout
  NotificationService().initialize().timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      print('Main: Notification service initialization timed out, continuing...');
    },
  ).catchError((e) {
    print('Main: Error initializing notifications: $e');
  });
  
  // Request permissions and test notification asynchronously (non-blocking)
  NotificationService().requestPermissions().catchError((e) {
    print('Main: Error requesting permissions: $e');
  });
  
  // Test notification service asynchronously (non-blocking) - commented out for now
  // NotificationService().testNotification().catchError((e) {
  //   print('Main: Error testing notification: $e');
  // });
  
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
  
  runApp(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MyApp(onboardingComplete: onboardingComplete),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool onboardingComplete;
  const MyApp({super.key, required this.onboardingComplete});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  void _onSplashComplete() {
    print('Main: Splash complete, navigating to ${widget.onboardingComplete ? 'HomeScreen' : 'OnboardingScreen'}');
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Quest Planner',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: _showSplash 
        ? SplashScreen(onSplashComplete: _onSplashComplete)
        : (widget.onboardingComplete ? const HomeScreen() : const OnboardingScreen()),
      localizationsDelegates: const [
        // Add localization delegates here
      ],
      supportedLocales: const [
        Locale('en'),
      ],
    );
  }
}
