// lib/theme/theme_controller.dart
//
// Preferencia de tema, local al dispositivo -- mismo patrón que Convive
// (theme/theme_controller.dart): no tiene sentido sincronizarla entre
// dispositivos, es "cómo quiero ver la pantalla en este móvil".
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clavePrefs = 'repara_theme_mode';

class ThemeController extends ChangeNotifier {
  ThemeController._(this._mode);

  static ThemeController? _instance;

  /// Solo válido después de que main() haya llamado a [load] una vez --
  /// justo cuando arranca la app, antes de montar ningún widget.
  static ThemeController get instance => _instance!;

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  static Future<ThemeController> load() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clavePrefs);
    final modo = switch (guardado) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _instance = ThemeController._(modo);
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
