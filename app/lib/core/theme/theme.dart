import 'package:flutter/material.dart';

/// Brand colors sampled from the Mokhtar logo.
abstract final class BrandColors {
  static const navy = Color(0xFF0B2B5B);        // building, wordmark
  static const tealBlue = Color(0xFF17A2B8);    // hexagon gradient
  static const green = Color(0xFF1FA85C);       // check / payment circle
  static const lightBlue = Color(0xFF4A9FD8);   // phone screen lines
}

ThemeData buildMokhtarTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.navy,
    primary: BrandColors.navy,
    secondary: BrandColors.tealBlue,
    tertiary: BrandColors.green,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: BrandColors.navy,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.navy,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
  );
}
