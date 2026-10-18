// lib/theme/design_tokens.dart
//
// Identidad visual de Repara -- "REPARA Professional" (rediseño CEO,
// octubre 2026): azul marino profesional + fondo cálido neutro + superficies
// blancas con borde fino, editorial y de gestión -- reemplaza la paleta
// "niebla azulada + lavanda" anterior. Sin degradados, sin sombras fuertes,
// sin acentos decorativos: cada color tiene un rol semántico concreto.
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

class ReparaColors extends ThemeExtension<ReparaColors> {
  const ReparaColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSunken,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.brand,
    required this.brandStrong,
    required this.brandOn,
    required this.brandTint,
    required this.sand,
    required this.success,
    required this.warning,
    required this.warningText,
    required this.error,
    required this.errorText,
    required this.overlay,
  });

  final Color background; // fondo general -- cálido neutro
  final Color surface; // tarjetas -- blanco
  final Color surfaceMuted; // campos de entrada, filas alternas
  final Color surfaceSunken; // pista vacía de una barra de progreso, separadores gruesos
  final Color border; // borde fino de tarjetas/inputs/divisores -- NUNCA alpha sobre ink
  final Color ink; // texto principal -- azul marino oscuro
  final Color inkMuted; // texto secundario -- gris azulado
  final Color inkFaint; // texto terciario, iconos en reposo -- NUNCA para texto que haya que leer
  final Color brand; // azul de interacción -- botones secundarios, enlaces, iconos activos
  final Color brandStrong; // azul marino profundo -- CTA principal, nav activa, pressed
  final Color brandOn; // texto/icono sobre un fondo de marca relleno
  final Color brandTint; // fondo tenue azul: icono circular, chip activo
  final Color sand; // acento secundario neutro -- decorativo puntual, nunca semántico
  final Color success;
  final Color warning; // SOLO icono o fondo tenue -- como texto no llega a 4.5:1, usa warningText
  final Color warningText; // variante oscurecida de warning para cumplir contraste de texto
  final Color error; // SOLO icono, borde o fondo tenue -- como texto usa errorText
  final Color errorText; // variante de error que sí cumple contraste de texto
  final Color overlay; // scrim bajo una hoja modal o diálogo

  static const light = ReparaColors(
    background: Color(0xFFF5F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0EEE7),
    surfaceSunken: Color(0xFFE8E5DD),
    border: Color(0xFFE5E3DE),
    ink: Color(0xFF203044),
    inkMuted: Color(0xFF687789),
    inkFaint: Color(0xFF9AA5B1),
    brand: Color(0xFF42658B),
    brandStrong: Color(0xFF183650),
    brandOn: Color(0xFFFFFFFF),
    brandTint: Color(0x1F42658B),
    sand: Color(0xFF42658B),
    success: Color(0xFF23856D),
    warning: Color(0xFFE5A23B),
    warningText: Color(0xFF8A5A1F),
    error: Color(0xFFE57373),
    errorText: Color(0xFFC23B3B),
    overlay: Color(0x26131A2B),
  );

  // Dark mode: no está en el alcance del briefing de "REPARA Professional"
  // (todas las referencias son de modo claro) -- se mantiene la paleta
  // anterior, solo con el campo 'border' nuevo añadido para que compile.
  // Si se quiere un dark mode a juego con la nueva identidad, es una
  // pasada aparte.
  static const dark = ReparaColors(
    background: Color(0xFF0F1422),
    surface: Color(0xFF1A2235),
    surfaceMuted: Color(0xFF212B42),
    surfaceSunken: Color(0xFF2A3550),
    border: Color(0x1FEEF1FA),
    ink: Color(0xFFEEF1FA),
    inkMuted: Color(0xFF9AA6C0),
    inkFaint: Color(0xFF6E7996),
    brand: Color(0xFF7C8CEF),
    brandStrong: Color(0xFF99A6F5),
    brandOn: Color(0xFF10142A),
    brandTint: Color(0x33A99AE8),
    sand: Color(0xFFBFB2F0),
    success: Color(0xFF4FB996),
    warning: Color(0xFFF0B860),
    warningText: Color(0xFFF3C88A),
    error: Color(0xFFE88888),
    errorText: Color(0xFFF2A7A7),
    overlay: Color(0x59000000),
  );

  @override
  ReparaColors copyWith({
    Color? background, Color? surface, Color? surfaceMuted, Color? surfaceSunken, Color? border,
    Color? ink, Color? inkMuted, Color? inkFaint,
    Color? brand, Color? brandStrong, Color? brandOn, Color? brandTint,
    Color? sand, Color? success, Color? warning, Color? warningText,
    Color? error, Color? errorText, Color? overlay,
  }) {
    return ReparaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandOn: brandOn ?? this.brandOn,
      brandTint: brandTint ?? this.brandTint,
      sand: sand ?? this.sand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      error: error ?? this.error,
      errorText: errorText ?? this.errorText,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  ReparaColors lerp(ThemeExtension<ReparaColors>? other, double t) {
    if (other is! ReparaColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Radios por rol, no uniformes -- ver design system (octubre 2026): antes
/// 16px en todo aplanaba la jerarquía igual que una sola tipografía.
class ReparaRadius {
  ReparaRadius._();
  static const double xs = 6; // miniaturas, badges pequeños
  static const double sm = 10; // botones, inputs, chips rectangulares
  static const double md = 14; // tarjetas y contenedores estándar
  static const double lg = 24; // esquinas superiores de una hoja modal
  static const double pill = 999; // chips de filtro/estado, avatares
}

/// Escala de 4px -- nunca un valor suelto porque "quedaba bien".
class ReparaSpace {
  ReparaSpace._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
}

extension ReparaThemeContextX on BuildContext {
  ReparaColors get colors => Theme.of(this).extension<ReparaColors>()!;
}

/// Fuente nativa del sistema -- SF Pro en iPhone, Roboto en Android, nunca una
/// fuente descargada -- exactamente lo que hace que WhatsApp o Instagram se
/// sientan "de app" y no de página web. Sustituye a Newsreader+Inter (CEO,
/// octubre 2026): la pareja serif/sans vía Google Fonts, aunque deliberada en
/// su momento para evitar el look por defecto de un diseño hecho con IA,
/// acabó leyéndose como tipografía editorial de web, no como una app nativa.
class ReparaText {
  ReparaText._();

  static String get fontFamily => defaultTargetPlatform == TargetPlatform.iOS ? '.SF Pro Text' : 'Roboto';

  static TextTheme uiTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final palette = brightness == Brightness.dark ? ReparaColors.dark : ReparaColors.light;
    final sistema = base.apply(
      fontFamily: fontFamily,
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );
    TextStyle display(double size, double height) => TextStyle(
          fontFamily: fontFamily,
          color: palette.ink,
          fontSize: size,
          height: height / size,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        );
    return sistema.copyWith(
      displayMedium: display(28, 34), // display-lg: recibo, estado vacío
      displaySmall: display(22, 28), // display-md: "Nuevo elemento", "RECIBO"
      headlineSmall: display(18, 24), // heading: título de sección
      labelSmall: sistema.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6), // label: eyebrow en mayúsculas
      bodyLarge: sistema.bodyLarge?.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400), // body
      titleMedium: sistema.titleMedium?.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600), // body-strong: título de fila
      bodySmall: sistema.bodySmall?.copyWith(fontSize: 12.5, height: 17 / 12.5, fontWeight: FontWeight.w500, color: palette.inkMuted), // caption
      labelLarge: sistema.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2), // button
    );
  }

  /// Importes -- siempre tabularNums para que las columnas de precio alineen.
  static TextStyle amount(BuildContext context, {bool large = false}) {
    final palette = Theme.of(context).extension<ReparaColors>()!;
    return TextStyle(
      fontFamily: fontFamily,
      color: palette.ink,
      fontSize: large ? 32 : 17,
      fontWeight: large ? FontWeight.w800 : FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

ThemeData _buildReparaTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? ReparaColors.dark : ReparaColors.light;
  final textTheme = ReparaText.uiTextTheme(brightness);
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    textTheme: textTheme,
    extensions: [palette],
    colorScheme: ColorScheme(
      brightness: brightness,
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
      titleTextStyle: TextStyle(
        fontFamily: ReparaText.fontFamily,
        color: palette.ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    // Borde fino como protagonista, sombra casi inexistente (briefing
    // "REPARA Professional": bordes finos, sombras mínimas) -- antes la
    // sombra hacía buena parte del trabajo; ahora lo hace el borde de
    // color explícito (palette.border), la sombra solo da una separación
    // mínima del fondo.
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shadowColor: palette.ink.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ReparaRadius.md),
        side: BorderSide(color: palette.border),
      ),
    ),
    dividerColor: palette.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ReparaRadius.sm),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: palette.inkMuted.withValues(alpha: 0.8)),
    ),
    // CTA principal en el azul marino profundo (brandStrong) -- es el tono
    // que lleva el botón "Siguiente", el FAB y el chip/nav activos en el
    // briefing, no el azul de interacción más claro (ese queda para
    // enlaces y botones secundarios, ver outlinedButtonTheme).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brandStrong,
        foregroundColor: palette.brandOn,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ReparaRadius.sm)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.brandStrong,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ReparaRadius.sm)),
      ),
    ),
    // Chip sin seleccionar como contorno, no bloque sólido -- más ligero,
    // patrón de "segmented control" en vez de botones de color plano.
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: palette.brandStrong,
      side: BorderSide(color: palette.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: palette.ink, fontSize: 13, fontWeight: FontWeight.w500),
      secondaryLabelStyle: TextStyle(color: palette.brandOn, fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.surface,
      selectedItemColor: palette.brandStrong,
      unselectedItemColor: palette.inkFaint,
      type: BottomNavigationBarType.fixed,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(color: palette.background),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

ThemeData buildReparaLightTheme() => _buildReparaTheme(Brightness.light);
ThemeData buildReparaDarkTheme() => _buildReparaTheme(Brightness.dark);
