import 'package:flutter/material.dart';

class AppTheme {
  static const Color lightBackground = Color(0xFFFBF8FF);
  static const Color lightText = Color(0xFF4B4854);
  static const Color text = lightText;
  static const Color background = lightBackground;
  static const Color darkBackground = Color(0xFF121218);
  static const Color darkSurface = Color(0xFF1E1E27);
  static const Color darkText = Color(0xFFF4F2F8);
  static const Color success = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF55D187);
  static const Color danger = Color(0xFFD04444);
  static const Color border = Color(0xFFFFDDE1);

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Roboto');
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B6D9E),
        brightness: Brightness.light,
        background: lightBackground,
        surface: Colors.white,
      ),
      textTheme: base.textTheme.apply(bodyColor: lightText, displayColor: lightText),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Roboto');
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9EA2FF),
        brightness: Brightness.dark,
        background: darkBackground,
        surface: darkSurface,
      ),
      textTheme: base.textTheme.apply(bodyColor: darkText, displayColor: darkText),
      cardTheme: CardThemeData(
        elevation: 1,
        color: darkSurface,
        shadowColor: Colors.black.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF262633),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
