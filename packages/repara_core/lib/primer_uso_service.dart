// lib/primer_uso_service.dart
//
// Ayuda contextual "solo la primera vez" (CEO, noviembre 2026: "quiero que
// un usuario que se descarga esta app sepa lo que tiene que hacer aunque no
// la haya usado nunca", en vez de tener que aprender a base de prueba y
// error). Recuerda, por dispositivo (SharedPreferences, mismo patrón que
// ThemeController), qué avisos de este tipo ya se han mostrado, para no
// repetirlos en cada visita a la misma acción.
import 'package:shared_preferences/shared_preferences.dart';

class PrimerUsoService {
  PrimerUsoService._();

  static const _prefijo = 'repara_primer_uso_';

  /// true si el aviso con esta [clave] ya se mostró antes en este dispositivo.
  static Future<bool> yaVisto(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefijo$clave') ?? false;
  }

  static Future<void> marcarVisto(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefijo$clave', true);
  }
}
