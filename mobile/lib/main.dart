// """
// Main Entry Point - AIT Fly
// ===========================
// This is the starting point of the Flutter app.
// It sets up the app with AIT Fly branding and modern theme.
// """

import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIT Fly',
      debugShowCheckedModeBanner: false,
      theme: AITFlyTheme.theme,
      // Start with splash screen to check authentication
      home: const SplashScreen(),
    );
  }
}



