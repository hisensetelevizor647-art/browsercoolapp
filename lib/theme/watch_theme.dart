import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WatchTheme {
  static final _lightPrimary = Colors.teal.shade700;
  static final _lightSecondary = Colors.deepOrange.shade300;
  static final _lightBackground = Colors.grey.shade50;
  static final _lightSurface = Colors.white;

  static final _darkPrimary = Colors.tealAccent.shade400;
  static final _darkSecondary = Colors.orange.shade300;
  static final _darkBackground = Colors.blueGrey.shade900;
  static final _darkSurface = Colors.blueGrey.shade800;

  static List<Color> getGradientColors(String themeId, bool isDark) {
    switch (themeId) {
      case 'ocean':
        return [
          Colors.cyan.shade500.withOpacity(isDark ? 0.34 : 0.22),
          Colors.blue.shade600.withOpacity(isDark ? 0.3 : 0.2),
          Colors.lightBlue.shade400.withOpacity(isDark ? 0.24 : 0.16),
          Colors.indigo.shade500.withOpacity(isDark ? 0.3 : 0.2),
        ];
      case 'sunset':
        return [
          Colors.orange.shade500.withOpacity(isDark ? 0.34 : 0.22),
          Colors.red.shade500.withOpacity(isDark ? 0.3 : 0.2),
          Colors.pink.shade400.withOpacity(isDark ? 0.24 : 0.16),
          Colors.deepPurple.shade500.withOpacity(isDark ? 0.3 : 0.2),
        ];
      case 'darkVoid':
        return [
          Colors.grey.shade800.withOpacity(isDark ? 0.4 : 0.3),
          Colors.black87.withOpacity(isDark ? 0.5 : 0.4),
          Colors.blueGrey.shade900.withOpacity(isDark ? 0.4 : 0.3),
          Colors.black.withOpacity(isDark ? 0.6 : 0.5),
        ];
      case 'default':
      default:
        return [
          Colors.blue.shade500.withOpacity(isDark ? 0.34 : 0.22),
          Colors.red.shade500.withOpacity(isDark ? 0.3 : 0.2),
          Colors.yellow.shade600.withOpacity(isDark ? 0.24 : 0.16),
          Colors.green.shade500.withOpacity(isDark ? 0.3 : 0.2),
        ];
    }
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
      primary: _lightPrimary,
      secondary: _lightSecondary,
      surface: _lightSurface,
      surfaceTint: _lightPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: _lightBackground,
      shadowColor: Colors.blueGrey.shade900,
    );

    return base.copyWith(
      textTheme: GoogleFonts.soraTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface.withOpacity(0.88),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
        hintStyle: TextStyle(
          color: scheme.onSurface.withOpacity(0.5),
          fontSize: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary.withOpacity(0.45)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
        elevation: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surface,
        contentTextStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
      primary: _darkPrimary,
      secondary: _darkSecondary,
      surface: _darkSurface,
      surfaceTint: _darkPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: _darkBackground,
      shadowColor: Colors.black,
    );

    return base.copyWith(
      textTheme: GoogleFonts.soraTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface.withOpacity(0.86),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
        hintStyle: TextStyle(
          color: scheme.onSurface.withOpacity(0.48),
          fontSize: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary.withOpacity(0.7)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
        elevation: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surface,
        contentTextStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
      ),
    );
  }
}
