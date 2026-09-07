import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/minimal_loader.dart';
import 'expense_tracker_screen.dart';
import 'google_auth_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _startInitialCheck();
  }

  void _startInitialCheck() {
    // Pure minimal round loader with zero text
    _navigationTimer = Timer(const Duration(milliseconds: 1400), () async {
      final authService = AuthService();
      final signedIn = await authService.isSignedIn();
      final prefs = await SharedPreferences.getInstance();
      final isOnboarded = prefs.getBool('is_onboarded') ?? false;

      Widget targetScreen;
      if (!signedIn) {
        // User not logged in -> Show Google Sign-In Only
        targetScreen = const GoogleAuthScreen();
      } else {
        // User logged in -> Check if budget is set
        final user = authService.currentUser;
        if (user != null) {
          final profile = await FirestoreService().getUserProfile(user.uid);
          if ((profile != null && profile['totalBudget'] != null) || isOnboarded) {
            targetScreen = const ExpenseTrackerScreen();
          } else {
            targetScreen = const OnboardingScreen();
          }
        } else {
          // Desktop Google session
          targetScreen = isOnboarded
              ? const ExpenseTrackerScreen()
              : const OnboardingScreen();
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: MinimalLoader(
          size: 32,
          strokeWidth: 2.4,
          color: Colors.white,
          showTrack: true,
        ),
      ),
    );
  }
}
