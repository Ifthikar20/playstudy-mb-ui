import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'reading_bloc.dart';
import 'theme_bloc.dart';

/// Pastel design system inspired by a soft, playful tile palette.
/// Light: off-white background, vivid indigo primary, with lime / peach /
/// mint / sky / lavender accents used throughout cards and chips.
class ThemeColors {
  // Pastel accent palette (the tile colors).
  static const Color pastelLime = Color(0xFFD6F26C);
  static const Color pastelPeach = Color(0xFFFBC78A);
  static const Color pastelMint = Color(0xFF8FE3B6);
  static const Color pastelSky = Color(0xFFA8E6F0);
  static const Color pastelLavender = Color(0xFFC4C0F5);
  static const Color brandIndigo = Color(0xFF6B5CE7);

  // Light — simplistic, near-black primary + neutral greys. Purple
  // (brandIndigo) is reserved for the exam area only.
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1A1A1A);
  static const Color lightSecondary = Color(0xFF3A3A3C);
  static const Color lightAccent = pastelMint;
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightBorder = Color(0xFFE5E5EA);
  static const Color lightError = Color(0xFFE5484D);

  // Dark
  static const Color darkBackground = Color(0xFF0E0E14);
  static const Color darkSurface = Color(0xFF1C1B26);
  static const Color darkPrimary = Color(0xFF8A7EFA);
  static const Color darkSecondary = brandIndigo;
  static const Color darkAccent = pastelMint;
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkError = Color(0xFFFF6B6E);

  /// Indigo gradient for primary CTAs.
  static const List<Color> brandGradient = [
    Color(0xFF6B5CE7),
    Color(0xFF7B6CF6),
    Color(0xFF9D8DFA),
  ];

  /// Accent palette as an ordered list — handy for assigning a distinct
  /// pastel to each card in a list (modulo length).
  static const List<Color> accentPalette = [
    pastelLime,
    pastelPeach,
    pastelMint,
    pastelSky,
    pastelLavender,
  ];

  static Color background(AppThemeMode m) =>
      m == AppThemeMode.light ? lightBackground : darkBackground;
  static Color surface(AppThemeMode m) =>
      m == AppThemeMode.light ? lightSurface : darkSurface;
  static Color primary(AppThemeMode m) =>
      m == AppThemeMode.light ? lightPrimary : darkPrimary;
  static Color textPrimary(AppThemeMode m) =>
      m == AppThemeMode.light ? lightTextPrimary : darkTextPrimary;
  static Color textSecondary(AppThemeMode m) =>
      m == AppThemeMode.light ? lightTextSecondary : darkTextSecondary;
  static Color border(AppThemeMode m) =>
      m == AppThemeMode.light ? lightBorder : darkBorder;
}

class AppTheme {
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius = 12.0;
  static const double chipRadius = 20.0;

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        bg: ThemeColors.lightBackground,
        surface: ThemeColors.lightSurface,
        primary: ThemeColors.lightPrimary,
        secondary: ThemeColors.lightSecondary,
        accent: ThemeColors.lightAccent,
        textPrimary: ThemeColors.lightTextPrimary,
        textSecondary: ThemeColors.lightTextSecondary,
        border: ThemeColors.lightBorder,
        error: ThemeColors.lightError,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        bg: ThemeColors.darkBackground,
        surface: ThemeColors.darkSurface,
        primary: ThemeColors.darkPrimary,
        secondary: ThemeColors.darkSecondary,
        accent: ThemeColors.darkAccent,
        textPrimary: ThemeColors.darkTextPrimary,
        textSecondary: ThemeColors.darkTextSecondary,
        border: ThemeColors.darkBorder,
        error: ThemeColors.darkError,
      );

  /// Apply the reader's dyslexia-friendly background tint + text colour on top
  /// of the light theme. Tints the reading surfaces (scaffold + cards) and
  /// softens the text. No-op at defaults so the standard look is preserved.
  static ThemeData withReading(ThemeData base, ReadingState r) {
    if (r.isDefault) return base;
    final bg = r.background.color;
    final tc = r.textColor.color;
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: base.colorScheme.copyWith(surface: bg, onSurface: tc),
      cardTheme: base.cardTheme.copyWith(color: bg),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: bg,
        foregroundColor: tc,
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: tc),
      ),
      textTheme: base.textTheme.apply(bodyColor: tc, displayColor: tc),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required Color error,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accent,
        onTertiary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
        displaySmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        // Keep app bars clean white — stop M3 from tinting them red on scroll.
        surfaceTintColor: Colors.transparent,
        backgroundColor: bg,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        // No M3 primary tint on cards — keep them neutral, Airbnb-style.
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(chipRadius),
          side: BorderSide(color: border),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}
