import 'package:flutter/material.dart';

/// Color palette and typography lifted directly from the Eunice-branch
/// InTravel web dashboard (assets/intravel/index.html :root variables)
/// so the native Flutter screens match pixel-for-pixel.
class AppTheme {
  // ─── Light palette (--paper/--card/--forest/--ink/--muted/--line/--warm/--accent) ─
  static const Color paper = Color(0xFFF8F6F1);
  static const Color card = Color(0xFFFFFFFF);
  static const Color forest = Color(0xFF1C4034);
  static const Color ink = Color(0xFF2E2621);
  static const Color muted = Color(0xFF91A099);
  static const Color line = Color(0xFFE6E2DB);
  static const Color warm = Color(0xFFEFE2D6);
  static const Color accent = Color(0xFFDF9A43);

  // ─── Dark palette (.dark class overrides) ──────────────────────────────────
  static const Color darkPaper = Color(0xFF1F1F1F);
  static const Color darkCard = Color(0xFF2A2A2A);
  static const Color darkInk = Color(0xFFF2F2F2);
  static const Color darkMuted = Color(0xFFA6A6A6);
  static const Color darkLine = Color(0xFF424242);
  static const Color darkWarm = Color(0xFF333333);
  static const Color darkAccent = Color(0xFF4EA1FF);

  // ─── Backward-compatible aliases used across existing screens ──────────────
  static const Color primaryDark = forest;
  static const Color primaryGreen = Color(0xFF2D5A3F);
  static const Color accentGold = accent;
  static const Color accentAmber = Color(0xFFF5A623);
  static const Color backgroundWhite = paper;
  static const Color cardWhite = card;
  static const Color surfaceLight = Color(0xFFF5F5F0);
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF5D6B64);
  static const Color textMuted = muted;
  static const Color dividerColor = line;
  static const Color chipBackground = Color(0xFFF0F0F0);
  static const Color starColor = Color(0xFFFFC107);
  static const Color categoryGreen = forest;
  static const Color navBarDark = forest;
  static const Color liveCardDark = Color(0xFF050505);

  static const String serifFont = 'Georgia';

  // ─── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    paperColor: paper,
    cardColor: card,
    inkColor: ink,
    mutedColor: muted,
    lineColor: line,
    accentColor: accent,
    forestColor: forest,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    paperColor: darkPaper,
    cardColor: darkCard,
    inkColor: darkInk,
    mutedColor: darkMuted,
    lineColor: darkLine,
    accentColor: darkAccent,
    forestColor: darkAccent,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color paperColor,
    required Color cardColor,
    required Color inkColor,
    required Color mutedColor,
    required Color lineColor,
    required Color accentColor,
    required Color forestColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: paperColor,
      primaryColor: forestColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: forestColor,
        onPrimary: Colors.white,
        secondary: accentColor,
        onSecondary: Colors.white,
        surface: cardColor,
        onSurface: inkColor,
        error: const Color(0xFFE53935),
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: inkColor),
        titleTextStyle: TextStyle(
          color: inkColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forestColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontFamily: serifFont,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: inkColor,
          letterSpacing: -0.4,
          height: 1.05,
        ),
        headlineMedium: TextStyle(
          fontFamily: serifFont,
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: inkColor,
          height: 1.1,
        ),
        headlineSmall: TextStyle(
          fontFamily: serifFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: inkColor,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: inkColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: inkColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: inkColor,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: mutedColor,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: mutedColor,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: inkColor,
        ),
      ),
      extensions: [
        AppColors(
          paper: paperColor,
          card: cardColor,
          ink: inkColor,
          muted: mutedColor,
          line: lineColor,
          accent: accentColor,
          forest: forestColor,
        ),
      ],
    );
  }
}

/// Theme-aware colors so widgets can adapt to Dark Mode without hardcoding
/// light-only constants from [AppTheme].
class AppColors extends ThemeExtension<AppColors> {
  final Color paper;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color forest;

  const AppColors({
    required this.paper,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.forest,
  });

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ??
        const AppColors(
          paper: AppTheme.paper,
          card: AppTheme.card,
          ink: AppTheme.ink,
          muted: AppTheme.muted,
          line: AppTheme.line,
          accent: AppTheme.accent,
          forest: AppTheme.forest,
        );
  }

  @override
  AppColors copyWith({
    Color? paper,
    Color? card,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? forest,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      forest: forest ?? this.forest,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      forest: Color.lerp(forest, other.forest, t)!,
    );
  }
}
