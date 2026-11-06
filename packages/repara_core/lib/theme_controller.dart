// packages/repara_core/lib/theme_controller.dart
//
// Preferencia de tema, local al dispositivo -- mismo patrón que Convive
// (theme/theme_controller.dart): no tiene sentido sincronizarla entre
// dispositivos, es "cómo quiero ver la pantalla en este móvil".
//
// [clavePrefs] (Fase 2B.2, noviembre 2026): cada app (Hogar, Pro) llama a
// [load] con su propia clave de SharedPreferences, para que cada una guarde
// su preferencia de tema de forma independiente -- aunque hoy cada app vive
// en su propio sandbox del sistema y nunca comparten almacenamiento, el
// paquete compartido no debe asumir que solo existe una app usándolo. Sin
// argumento, mantiene la clave histórica de Hogar (`repara_theme_mode`), así
// que ningún llamador existente cambia de comportamiento.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clavePorDefecto = 'repara_theme_mode';

class ThemeController extends ChangeNotifier {
  ThemeController._(this._mode, this._clavePrefs);

  static ThemeController? _instance;

  /// Solo válido después de que main() haya llamado a [load] una vez --
  /// justo cuando arranca la app, antes de montar ningún widget.
  static ThemeController get instance => _instance!;

  /// Solo para tests -- [load] cachea la instancia (una sola por proceso,
  /// como en la app real), así que sin esto un test no podría comprobar más
  /// de una combinación de preferencia guardada/clave por archivo.
  @visibleForTesting
  static void debugReset() => _instance = null;

  final String _clavePrefs;
  ThemeMode _mode;
  ThemeMode get mode => _mode;

  static Future<ThemeController> load({
    String clavePrefs = _clavePorDefecto,
  }) async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(clavePrefs);
    final modo = switch (guardado) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _instance = ThemeController._(modo, clavePrefs);
    return _instance!;
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePrefs, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
