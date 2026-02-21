import 'package:flutter/material.dart';

class AppTheme {
  static const Color ice = Color(0xFFA9CFE0);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color deepTeal = Color(0xFF103C44);
  static const Color mist = Color(0xFFC7D6DE);
  static const Color sky = Color(0xFF78AFC3);
  static const Color slate = Color(0xFF6E8F99);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: violet,
        secondary: sky,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: deepTeal,
      ),
      scaffoldBackgroundColor: mist,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: deepTeal,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: deepTeal,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: deepTeal,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: deepTeal,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: deepTeal,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: slate),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
