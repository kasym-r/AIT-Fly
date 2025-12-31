// """
// Main Entry Point
// ================
// This is the starting point of the Flutter app.
// It sets up the app and shows the login screen first.
// """

import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airline Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Primary color scheme
        primarySwatch: Colors.blue,
        // Use Material 3 design
        useMaterial3: true,
        // Card theme
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Input field theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      // Start with splash screen to check authentication
      home: const SplashScreen(),
    );
  }
}



