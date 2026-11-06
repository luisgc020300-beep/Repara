// packages/repara_core/test/theme_controller_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeController.debugReset();
  });

  test('load() sin nada guardado empieza en ThemeMode.system', () async {
    final c = await ThemeController.load();
    expect(c.mode, ThemeMode.system);
  });

  test('load() respeta un modo ya guardado con la clave por defecto', () async {
    SharedPreferences.setMockInitialValues({'repara_theme_mode': 'dark'});
    final c = await ThemeController.load();
    expect(c.mode, ThemeMode.dark);
  });

  test('setMode() guarda y notifica, y vuelve a cargar ya guardado', () async {
    final c = await ThemeController.load();
    var notificado = false;
    c.addListener(() => notificado = true);

    await c.setMode(ThemeMode.light);
    expect(c.mode, ThemeMode.light);
    expect(notificado, isTrue);

    ThemeController.debugReset();
    final recargado = await ThemeController.load();
    expect(recargado.mode, ThemeMode.light);
  });

  test('setMode() con el mismo modo actual no notifica (no-op)', () async {
    final c = await ThemeController.load();
    var notificaciones = 0;
    c.addListener(() => notificaciones++);

    await c.setMode(ThemeMode.system);
    expect(notificaciones, 0);
  });

  test(
    'load() con clavePrefs propia (Pro) es independiente de la clave por defecto (Hogar)',
    () async {
      SharedPreferences.setMockInitialValues({
        'repara_theme_mode': 'dark',
        'repara_pro_theme_mode': 'light',
      });
      final pro = await ThemeController.load(clavePrefs: 'repara_pro_theme_mode');
      expect(pro.mode, ThemeMode.light);
    },
  );

  test('instance devuelve la misma instancia que load() resolvió', () async {
    final cargado = await ThemeController.load();
    expect(ThemeController.instance, same(cargado));
  });
}
