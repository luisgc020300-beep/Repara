// lib/theme/design_tokens.dart
//
// Identidad visual de Repara: "la ficha viva de la casa". A diferencia de
// RiskRunner (táctico, oscuro) o Convive (corcho de piso compartido), Repara
// necesita transmitir calma y confianza doméstica -- fondo claro, cálido,
// nunca blanco puro ni gris frío de software de gestión. Un único tema claro
// (sin modo oscuro en v1): la app se piensa para consultarse en el salón o
// enseñarse a un profesional, no para uso nocturno prolongado como correr.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReparaColors extends ThemeExtension<ReparaColors> {
  const ReparaColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkMuted,
    required this.brand,
    required this.brandOn,
    required this.sand,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color background; // fondo general -- marfil roto
  final Color surface; // tarjetas
  final Color surfaceMuted; // campos de entrada, filas alternas
  final Color ink; // texto principal -- negro carbón, no negro puro
  final Color inkMuted; // texto secundario -- gris cálido
  final Color brand; // verde salvia profundo -- color de marca
  final Color brandOn; // texto/icono sobre un fondo de marca relleno
  final Color sand; // acento secundario -- beige/arena
  final Color success;
  final Color warning;
  final Color error;

  static const light = ReparaColors(
    background: Color(0xFFF7F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFE8DA),
    ink: Color(0xFF241F1A),
    inkMuted: Color(0xFF6B6053),
    brand: Color(0xFF2F4A3C),
    brandOn: Color(0xFFFFFFFF),
    sand: Color(0xFFD8C8A8),
    success: Color(0xFF3E7A4F),
    warning: Color(0xFFB8842E),
    error: Color(0xFFB4463A),
  );

  @override
  ReparaColors copyWith({
    Color? background, Color? surface, Color? surfaceMuted, Color? ink, Color? inkMuted,
    Color? brand, Color? brandOn, Color? sand, Color? success, Color? warning, Color? error,
  }) {
    return ReparaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      brand: brand ?? this.brand,
      brandOn: brandOn ?? this.brandOn,
      sand: sand ?? this.sand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  ReparaColors lerp(ThemeExtension<ReparaColors>? other, double t) {
    if (other is! ReparaColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension ReparaThemeContextX on BuildContext {
  ReparaColors get colors => Theme.of(this).extension<ReparaColors>()!;
}

class ReparaText {
  ReparaText._();

  static TextTheme uiTextTheme() {
    final base = ThemeData.light().textTheme;
    return GoogleFonts.interTextTheme(base).apply(
      bodyColor: ReparaColors.light.ink,
      displayColor: ReparaColors.light.ink,
    );
  }
}

ThemeData buildReparaTheme() {
  final palette = ReparaColors.light;
  final textTheme = ReparaText.uiTextTheme();
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: palette.background,
    textTheme: textTheme,
    extensions: [palette],
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      surface: palette.surface,
      onSurface: palette.ink,
      primary: palette.brand,
      onPrimary: palette.brandOn,
      secondary: palette.sand,
      onSecondary: palette.ink,
      tertiary: palette.success,
      onTertiary: Colors.white,
      error: palette.error,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: palette.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.ink.withValues(alpha: 0.06)),
      ),
    ),
    dividerColor: palette.inkMuted.withValues(alpha: 0.15),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: palette.inkMuted.withValues(alpha: 0.8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brand,
        foregroundColor: palette.brandOn,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.brand,
        side: BorderSide(color: palette.brand.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.surface,
      selectedItemColor: palette.brand,
      unselectedItemColor: palette.inkMuted,
      type: BottomNavigationBarType.fixed,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
