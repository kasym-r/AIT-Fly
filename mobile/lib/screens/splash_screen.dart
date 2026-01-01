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
              // Animated airplane icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AITFlyTheme.white,
                  shape: BoxShape.circle,
                  boxShadow: AITFlyTheme.cardShadow,
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  size: 64,
                  color: AITFlyTheme.primaryPurple,
                ),
              ),
              const SizedBox(height: 32),
              
              // AIT Fly Branding
              ShaderMask(
                shaderCallback: (bounds) => AITFlyTheme.primaryGradient.createShader(bounds),
                child: const Text(
                  'AIT Fly',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Journey Starts Here',
                style: AITFlyTheme.bodyMedium.copyWith(
                  color: AITFlyTheme.mediumGray,
                ),
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

