import 'package:flutter/material.dart';

class AppTheme {
  // Renk Paleti (HTML kodundan alınmıştır)
  static const Color _primaryBlue = Color(0xFF137FEC);
  static const Color _backgroundDark = Color(0xFF101922);
  static const Color _surfaceDark = Color(0xFF192633);
  static const Color _borderDark = Color(0xFF324D67);
  static const Color _textSecondary = Color(0xFF92ADC9);
  static const Color _errorRed = Color(0xFFEF4444);

  static final ThemeData seismoDarkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _backgroundDark,
    primaryColor: _primaryBlue,

    colorScheme: const ColorScheme.dark(
      primary: _primaryBlue,
      secondary: _primaryBlue,
      surface: _surfaceDark,
      background: _backgroundDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onBackground: _textSecondary,
      error: _errorRed,
    ),

    useMaterial3: true,

    // Yazı Tipleri (Public Sans benzeri bir görünüm için)
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textSecondary),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 14, color: _textSecondary),
    ),

    // Input Tasarımı (HTML'deki Input alanları gibi)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _backgroundDark,
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
      prefixIconColor: _textSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryBlue, width: 2),
      ),
    ),

    // Buton Tasarımları
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}