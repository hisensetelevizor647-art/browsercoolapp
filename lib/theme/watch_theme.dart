import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WatchTheme {
  static final _lightPrimary = Colors.teal.shade700;
  static final _lightSecondary = Colors.deepOrange.shade300;
  static final _lightBackground = Colors.grey.shade50;
  static final _lightSurface = Colors.white;

  // Real True OLED / AMOLED Dark Theme Constants
  static const _darkPrimary = Color(0xFF26A69A); // Vibrant crisp teal
  static const _darkSecondary = Color(0xFFFF8A65); // Warm accent
  static const _darkBackground = Color(0xFF000000); // 100% True Pitch Black for OLED
  static const _darkSurface = Color(0xFF121212); // Deep Charcoal
  static const _darkSurfaceContainer = Color(0xFF1A1A1A); // Slightly raised dark surface
  static const _darkSurfaceContainerHighest = Color(0xFF242424); // Elevated chip/input

  static List<Color> getGradientColors(String themeId, bool isDark) {
    switch (themeId) {
      case 'darkVoid':
        return [
          const Color(0xFF000000),
          const Color(0xFF0A0A0A),
          const Color(0xFF141414),
          const Color(0xFF000000),
        ];
      case 'ocean':
        return isDark
            ? [
                const Color(0xFF001219),
                const Color(0xFF001F2B),
                const Color(0xFF0A192F),
                const Color(0xFF000000),
              ]
            : [
                Colors.cyan.shade500.withOpacity(0.22),
                Colors.blue.shade600.withOpacity(0.2),
                Colors.lightBlue.shade400.withOpacity(0.16),
                Colors.indigo.shade500.withOpacity(0.2),
              ];
      case 'sunset':
        return isDark
            ? [
                const Color(0xFF1A0A00),
                const Color(0xFF2B0E14),
                const Color(0xFF1F0A24),
                const Color(0xFF000000),
              ]
            : [
                Colors.orange.shade500.withOpacity(0.22),
                Colors.red.shade500.withOpacity(0.2),
                Colors.pink.shade400.withOpacity(0.16),
                Colors.deepPurple.shade500.withOpacity(0.2),
              ];
      case 'default':
      default:
        return isDark
            ? [
                const Color(0xFF040A10),
                const Color(0xFF0D0510),
                const Color(0xFF050F0B),
                const Color(0xFF000000),
              ]
            : [
                Colors.blue.shade500.withOpacity(0.22),
                Colors.red.shade500.withOpacity(0.2),
                Colors.yellow.shade600.withOpacity(0.16),
                Colors.green.shade500.withOpacity(0.2),
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
      textTheme: _safeTextTheme(base.textTheme),
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
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: Colors.black,
      primaryContainer: const Color(0xFF1B3B36),
      onPrimaryContainer: const Color(0xFFA7F3D0),
      secondary: _darkSecondary,
      onSecondary: Colors.black,
      secondaryContainer: const Color(0xFF3B231B),
      onSecondaryContainer: const Color(0xFFFFCCBC),
      surface: _darkSurface,
      onSurface: const Color(0xFFF1F5F9),
      surfaceContainer: _darkSurfaceContainer,
      surfaceContainerHighest: _darkSurfaceContainerHighest,
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: const Color(0xFF334155),
      outlineVariant: const Color(0xFF1E293B),
      error: const Color(0xFFEF4444),
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: _darkBackground,
      canvasColor: _darkBackground,
      cardColor: _darkSurface,
      dialogBackgroundColor: _darkSurface,
      shadowColor: Colors.black,
    );

      textTheme: _safeTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF1F5F9),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262626), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceContainerHighest,
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D3748)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkPrimary, width: 1.2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
        elevation: 2,
        backgroundColor: _darkSurfaceContainerHighest,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _darkSurfaceContainer,
        contentTextStyle: TextStyle(color: Color(0xFFF1F5F9), fontSize: 12),
      ),
    );
  }

  static TextTheme _safeTextTheme(TextTheme base) {
    try {
      return GoogleFonts.soraTextTheme(base);
    } catch (_) {
      return base;
    }
  }
}
