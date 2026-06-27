import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The 3 palettes shipped in `design_handoff_milelog` — Rose is the
/// original/primary palette; Lime and Cyan are alternates. Each has a dark
/// and light variant (see the const token sets below, ported from the
/// handoff's `styles.css` `:root[data-palette=...][data-theme=...]` blocks,
/// OKLCH values converted to sRGB).
enum AppPalette { rose, lime, cyan }

/// Palette/mode-aware color tokens, looked up via [AppColors.of] (a Theme
/// extension) rather than as static constants, since the user can switch
/// palette and dark/light mode at runtime.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surfaceElevated,
    required this.surfaceElevated2,
    required this.surfaceInset,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textDim,
    required this.textDimmer,
    required this.textGhost,
    required this.accent,
    required this.accentSecondary,
    required this.accentInk,
    required this.accentTintAlpha,
    required this.success,
    required this.danger,
    required this.warning,
    required this.personalTag,
  });

  final Color background;
  final Color surfaceElevated;
  final Color surfaceElevated2;
  final Color surfaceInset;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textDim;
  final Color textDimmer;
  final Color textGhost;
  final Color accent;
  final Color accentSecondary;
  final Color accentInk;
  final double accentTintAlpha;
  final Color success;
  final Color danger;
  final Color warning;
  final Color personalTag;

  /// Business-trip tag color is always identical to [accent] in every
  /// palette (mirrors the design tokens' `--biz: var(--accent)`).
  Color get businessTag => accent;
  Color get accentTint => accent.withValues(alpha: accentTintAlpha);

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? background,
    Color? surfaceElevated,
    Color? surfaceElevated2,
    Color? surfaceInset,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textDim,
    Color? textDimmer,
    Color? textGhost,
    Color? accent,
    Color? accentSecondary,
    Color? accentInk,
    double? accentTintAlpha,
    Color? success,
    Color? danger,
    Color? warning,
    Color? personalTag,
  }) {
    return AppColors(
      background: background ?? this.background,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceElevated2: surfaceElevated2 ?? this.surfaceElevated2,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textDim: textDim ?? this.textDim,
      textDimmer: textDimmer ?? this.textDimmer,
      textGhost: textGhost ?? this.textGhost,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentInk: accentInk ?? this.accentInk,
      accentTintAlpha: accentTintAlpha ?? this.accentTintAlpha,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      personalTag: personalTag ?? this.personalTag,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceElevated2:
          Color.lerp(surfaceElevated2, other.surfaceElevated2, t)!,
      surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      textDimmer: Color.lerp(textDimmer, other.textDimmer, t)!,
      textGhost: Color.lerp(textGhost, other.textGhost, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      accentTintAlpha: lerpDouble(accentTintAlpha, other.accentTintAlpha, t) ??
          accentTintAlpha,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      personalTag: Color.lerp(personalTag, other.personalTag, t)!,
    );
  }
}

const _roseDark = AppColors(
  background: Color(0xFF140910),
  surfaceElevated: Color(0xFF1F1018),
  surfaceElevated2: Color(0xFF2A1722),
  surfaceInset: Color(0xFF0B0508),
  border: Color(0xFF2E1A25),
  borderStrong: Color(0xFF3F2433),
  textPrimary: Color(0xFFF6EEF3),
  textDim: Color(0xFFB8A0AE),
  textDimmer: Color(0xFF816A78),
  textGhost: Color(0xFF4A3742),
  accent: Color(0xFFFF6895),
  accentSecondary: Color(0xFFFF9661),
  accentInk: Color(0xFF15080E),
  accentTintAlpha: 0.14,
  success: Color(0xFF5FD37F),
  danger: Color(0xFFFF4C4D),
  warning: Color(0xFFF3BA25),
  personalTag: Color(0xFF65BDFF),
);

const _limeDark = AppColors(
  background: Color(0xFF0A0F0A),
  surfaceElevated: Color(0xFF121913),
  surfaceElevated2: Color(0xFF1A231C),
  surfaceInset: Color(0xFF050805),
  border: Color(0xFF1F2A20),
  borderStrong: Color(0xFF2A3A2C),
  textPrimary: Color(0xFFEEF4EE),
  textDim: Color(0xFF9FB3A2),
  textDimmer: Color(0xFF6E8172),
  textGhost: Color(0xFF3F4E42),
  accent: Color(0xFFBDF520),
  accentSecondary: Color(0xFF46CE83),
  accentInk: Color(0xFF0A0F0A),
  accentTintAlpha: 0.14,
  success: Color(0xFF5CE483),
  danger: Color(0xFFFF5453),
  warning: Color(0xFFF3BA25),
  personalTag: Color(0xFF969CEE),
);

const _cyanDark = AppColors(
  background: Color(0xFF06101D),
  surfaceElevated: Color(0xFF0D1A2A),
  surfaceElevated2: Color(0xFF13233A),
  surfaceInset: Color(0xFF030814),
  border: Color(0xFF1A2D45),
  borderStrong: Color(0xFF254060),
  textPrimary: Color(0xFFEBF2FA),
  textDim: Color(0xFF94AAC1),
  textDimmer: Color(0xFF60788F),
  textGhost: Color(0xFF35465A),
  accent: Color(0xFF00E3D1),
  accentSecondary: Color(0xFF42C2E6),
  accentInk: Color(0xFF05101C),
  accentTintAlpha: 0.14,
  success: Color(0xFF4AE2AC),
  danger: Color(0xFFFF4C4D),
  warning: Color(0xFFF3BA25),
  personalTag: Color(0xFFC5A2FF),
);

/// Light mode base — also used as-is for Rose (the handoff has no dedicated
/// light+rose override block; Lime/Cyan layer a few overrides on top of
/// this in their light variants below, exactly mirroring the CSS cascade).
const _roseLight = AppColors(
  background: Color(0xFFFBF6F5),
  surfaceElevated: Color(0xFFFFFFFF),
  surfaceElevated2: Color(0xFFFDF9F8),
  surfaceInset: Color(0xFFF2E9E6),
  border: Color(0xFFEADDD8),
  borderStrong: Color(0xFFD8C4BC),
  textPrimary: Color(0xFF1C0E14),
  textDim: Color(0xFF6B5460),
  textDimmer: Color(0xFF9E8392),
  textGhost: Color(0xFFD2BFC9),
  accent: Color(0xFFDA1D69),
  accentSecondary: Color(0xFFE86518),
  accentInk: Color(0xFFFFFFFF),
  accentTintAlpha: 0.1,
  success: Color(0xFF1B9247),
  danger: Color(0xFFDF202E),
  warning: Color(0xFFF3BA25),
  personalTag: Color(0xFF2389E2),
);

const _limeLight = AppColors(
  background: Color(0xFFF7FAF5),
  surfaceElevated: Color(0xFFFFFFFF),
  surfaceElevated2: Color(0xFFFDF9F8),
  surfaceInset: Color(0xFFECF2E7),
  border: Color(0xFFDAE6D2),
  borderStrong: Color(0xFFBFD0B3),
  textPrimary: Color(0xFF0E140F),
  textDim: Color(0xFF5A6B5E),
  textDimmer: Color(0xFF8A9D8E),
  textGhost: Color(0xFFD2BFC9),
  accent: Color(0xFF338800),
  accentSecondary: Color(0xFFE86518),
  accentInk: Color(0xFFFFFFFF),
  accentTintAlpha: 0.12,
  success: Color(0xFF1B9247),
  danger: Color(0xFFDF202E),
  warning: Color(0xFFF3BA25),
  personalTag: Color(0xFF6C6ECB),
);

const _cyanLight = AppColors(
  background: Color(0xFFF2F7FA),
  surfaceElevated: Color(0xFFFFFFFF),
  surfaceElevated2: Color(0xFFFDF9F8),
  surfaceInset: Color(0xFFE3EEF4),
  border: Color(0xFFD0E0EA),
  borderStrong: Color(0xFFA9C3D4),
  textPrimary: Color(0xFF081521),
  textDim: Color(0xFF52687A),
  textDimmer: Color(0xFF8099AD),
  textGhost: Color(0xFFD2BFC9),
  accent: Color(0xFF008F9F),
  accentSecondary: Color(0xFFE86518),
  accentInk: Color(0xFFFFFFFF),
  accentTintAlpha: 0.12,
  success: Color(0xFF1B9247),
  danger: Color(0xFFDF202E),
  warning: Color(0xFFF3BA25),
  personalTag: Color(0xFF8E6AC7),
);

class AppTheme {
  AppTheme._();

  // ── Spacing (4dp base) — palette/mode independent ───────────────────────
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space10 = 10.0;
  static const space14 = 14.0;
  static const space16 = 16.0;
  static const space18 = 18.0;
  static const space20 = 20.0;
  static const space24 = 24.0;

  // ── Typography scale (dp) ─────────────────────────────────────────────
  static const fontSizeHeading = 24.0;
  static const fontSizeTitleLarge = 20.0;
  static const fontSizeTitleMedium = 16.0;
  static const fontSizeBody = 14.0;
  static const fontSizeCaption = 12.0;
  static const fontSizeLabel = 11.0;

  // ── Shape ────────────────────────────────────────────────────────────────
  static const cardRadius = 18.0;
  static const buttonRadius = 14.0;
  static const settingsRowMinHeight = 64.0;

  static AppColors colorsFor(AppPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (palette) {
      case AppPalette.rose:
        return isDark ? _roseDark : _roseLight;
      case AppPalette.lime:
        return isDark ? _limeDark : _limeLight;
      case AppPalette.cyan:
        return isDark ? _cyanDark : _cyanLight;
    }
  }

  static TextStyle _display({required double size, required Color color}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -size * 0.03,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle _heading({required double size, required Color color}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -size * 0.025,
        color: color,
      );

  static TextStyle _body({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.spaceGrotesk(
          fontSize: size, fontWeight: weight, color: color);

  static TextStyle _mono({
    required double size,
    required Color color,
    double trackingEm = 0.08,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size * trackingEm,
        color: color,
      );

  static ThemeData themeFor(AppPalette palette, Brightness brightness) {
    final colors = colorsFor(palette, brightness);

    final textTheme = TextTheme(
      // Hero numbers — km/currency/time counters.
      displayLarge: _display(size: 58, color: colors.textPrimary),
      displayMedium: _display(size: 46, color: colors.textPrimary),
      displaySmall: _display(size: 36, color: colors.textPrimary),
      // Screen headings (headingLarge→24, headingMedium→20, headingSmall→16).
      headlineLarge: _heading(size: 24, color: colors.textPrimary),
      headlineMedium: _heading(size: 24, color: colors.textPrimary),
      headlineSmall: _heading(size: 20, color: colors.textPrimary),
      titleLarge: _heading(size: 20, color: colors.textPrimary),
      titleMedium:
          _body(size: 16, color: colors.textPrimary, weight: FontWeight.w600),
      // Body text (headingSmall→16 semibold via titleMedium).
      bodyLarge: _body(size: 16, color: colors.textPrimary),
      bodyMedium: _body(size: 14, color: colors.textPrimary),
      bodySmall: _body(size: 12, color: colors.textDim, weight: FontWeight.w400),
      // Mono section/micro labels — 11px, letter-spacing ~0.5.
      labelLarge: _mono(size: 11, color: colors.textPrimary, trackingEm: 0.04),
      labelMedium: _mono(size: 11, color: colors.textDim, trackingEm: 0.045),
      labelSmall: _mono(size: 10, color: colors.textDimmer, trackingEm: 0.14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
      textTheme: textTheme,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        surface: colors.surfaceElevated,
        primary: colors.accent,
        onPrimary: colors.accentInk,
        // Tinted accent for pill indicators (NavigationBar, chips, etc.)
        primaryContainer:
            colors.accent.withValues(alpha: colors.accentTintAlpha),
        onPrimaryContainer: colors.accent,
        // "Personal" trip-type tag color — see AppColors.businessTag/personalTag.
        secondary: colors.personalTag,
        onSecondary: colors.accentInk,
        // Map secondaryContainer → accent tint so M3 NavigationBar indicator
        // uses the correct palette accent even when theme override is missed.
        secondaryContainer:
            colors.accent.withValues(alpha: colors.accentTintAlpha),
        onSecondaryContainer: colors.accent,
        tertiary: colors.accentSecondary,
        onTertiary: colors.accentInk,
        error: colors.danger,
        onError: colors.accentInk,
        onSurface: colors.textPrimary,
        outline: colors.border,
        outlineVariant: colors.borderStrong,
        surfaceContainerHighest: colors.surfaceElevated2,
      ),
      cardColor: colors.surfaceElevated,
      cardTheme: CardThemeData(
        color: colors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _heading(size: 20, color: colors.textPrimary),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surfaceElevated,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.textDimmer,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.accentInk,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: space16, vertical: space14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(space8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(space8),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: colors.textDim),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.accent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.accentInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: space24, vertical: space14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: colors.textPrimary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceElevated2,
        selectedColor: colors.accentTint,
        labelStyle: TextStyle(color: colors.textPrimary),
        side: BorderSide.none,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(space8)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colors.accent
              : colors.textDimmer,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colors.accent.withValues(alpha: 0.35)
              : colors.textGhost,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.accent.withValues(alpha: colors.accentTintAlpha),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.accent);
          }
          return IconThemeData(color: colors.textDimmer);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(color: colors.textDimmer, fontSize: 12);
        }),
      ),
    );
  }
}

