// """
// AIT Fly App Theme
// =================
// Modern, beautiful theme with gray color scheme
// """

import 'package:flutter/material.dart';

class AITFlyTheme {
  // Brand Colors - Gray Theme
  static const Color primaryPurple = Color(0xFF6B7280); // Main gray (keeping name for compatibility)
  static const Color lightPurple = Color(0xFFF3F4F6); // Light gray for backgrounds
  static const Color darkPurple = Color(0xFF374151); // Dark gray for accents
  static const Color purpleAccent = Color(0xFF9CA3AF); // Accent gray
  
  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFF9CA3AF);
  static const Color darkGray = Color(0xFF374151);
  static const Color black = Color(0xFF111827);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B7280), Color(0xFF374151)],
  );
  
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
  );
  
  // Text Styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: black,
    letterSpacing: -0.5,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: black,
    letterSpacing: -0.3,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: black,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: darkGray,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: darkGray,
    height: 1.4,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: mediumGray,
    height: 1.3,
  );
  
  // App Theme
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.light,
        primary: primaryPurple,
        secondary: purpleAccent,
        surface: white,
        background: lightGray,
      ),
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: white,
        foregroundColor: black,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: black,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: white,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mediumGray.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mediumGray.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: bodyMedium.copyWith(color: mediumGray),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryPurple,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPurple,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: white,
        elevation: 4,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: darkGray,
        size: 24,
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: mediumGray.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),
    );
  }
  
  // Box Shadow for Cards
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
  
  // Decoration for gradient backgrounds
  static BoxDecoration get gradientBackground => const BoxDecoration(
    gradient: lightGradient,
  );
  
  // Decoration for gray gradient buttons
  static BoxDecoration get purpleGradientButton => const BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
}

