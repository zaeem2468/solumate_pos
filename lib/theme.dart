import 'package:flutter/material.dart';

/// Colours taken from hardware-shop signage: galvanised grey, workshop navy,
/// hi-vis yellow for what is selected, and Solumate red for the main action.
class AppColors {
  static const Color navy = Color(0xFF14304A);
  static const Color navyRaised = Color(0xFF1F4463);
  static const Color navyDeep = Color(0xFF0A1A30);
  static const Color red = Color(0xFFD81B2C);
  static const Color orange = Color(0xFFFF6A13);
  static const Color gold = Color(0xFFFFD34D);
  static const Color redTint = Color(0xFFFBECEE);
  static const Color yellow = Color(0xFFFFC629);
  static const Color ground = Color(0xFFE9ECEE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF16212B);
  static const Color muted = Color(0xFF5D6B78);
  static const Color line = Color(0xFFD5DADF);
  static const Color ok = Color(0xFF1E7B4A);
  static const Color warn = Color(0xFFB0600A);
}

class AppGradients {
  static const LinearGradient hot = LinearGradient(colors: [Color(0xFFD81B2C), Color(0xFFF2500F)]);
  static const LinearGradient gold = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE27A), Color(0xFFFFC629), Color(0xFFFF9A1F)]);
  static const LinearGradient goldText = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFFFE27A), Color(0xFFFFB000)]);
  static const LinearGradient sidebar = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.navyDeep, AppColors.navy, Color(0xFF3A1238)]);
  static const LinearGradient banner = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [AppColors.navyDeep, Color(0xFF3A1238), Color(0xFFC8102E)]);

  static LinearGradient forColor(Color color) => LinearGradient(colors: [Color.lerp(color, Colors.black, 0.28)!, color]);
}

class AppText {
  /// Condensed sign lettering for page titles, prices and totals.
  static TextStyle display(double size, {Color color = AppColors.ink}) => TextStyle(
    fontFamily: 'RobotoCondensed',
    fontWeight: FontWeight.w700,
    fontSize: size,
    color: color,
    height: 1.1,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData buildAppTheme() {
  final outline = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line));
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

  return ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.red,
    scaffoldBackgroundColor: AppColors.ground,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.red,
      primary: AppColors.red,
      secondary: AppColors.navy,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceTint: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(borderSide: const BorderSide(color: AppColors.navy, width: 2)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, elevation: 0, shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.navy, side: const BorderSide(color: AppColors.line), shape: buttonShape),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.navy)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.navy : AppColors.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    chipTheme: const ChipThemeData(
      selectedColor: AppColors.yellow,
      checkmarkColor: AppColors.navy,
      side: BorderSide(color: AppColors.line),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
