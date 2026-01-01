// """
// Splash Screen
// =============
// This screen checks if the user is already logged in.
// If a valid token exists, it navigates to the flight search screen.
// Otherwise, it shows the login screen.
// """

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ait_fly_logo.dart';
import 'login_screen.dart';
import 'flight_search_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait a bit for smooth transition
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      // Check if token exists
      final token = await ApiService.getToken();
      
      if (token != null && token.isNotEmpty) {
        // Token exists - verify it's still valid by calling /me
        try {
          await ApiService.getCurrentUser();
          // Token is valid - navigate to flight search
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const FlightSearchScreen()),
            );
            return;
          }
        } catch (e) {
          // Token is invalid or expired - clear it and show login
          await ApiService.clearToken();
        }
      }
      
      // No token or token invalid - show login screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      // Error checking auth - show login screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AITFlyTheme.gradientBackground,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // AIT Fly Logo
              const AITFlyLogo(
                size: 100,
                showTagline: true,
              ),
              const SizedBox(height: 48),
              
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AITFlyTheme.primaryPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

