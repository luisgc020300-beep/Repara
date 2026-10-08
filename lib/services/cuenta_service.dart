// lib/services/cuenta_service.dart
//
// Borrado de cuenta (derecho de supresión RGPD + requisito de Apple/Google
// de poder borrar la cuenta desde dentro de la app). Toda la lógica de
// cascada vive en la Cloud Function eliminarCuenta -- aquí solo se llama.
import 'package:cloud_functions/cloud_functions.dart';

import 'security/security_preferences_service.dart';

class CuentaService {
  static const _region = 'europe-west1';

  /// Lanza FirebaseFunctionsException con code 'failed-precondition' si el
  /// usuario es propietario de una casa con otros miembros -- la UI debe
  /// mostrar ese mensaje tal cual, no uno genérico.
  static Future<void> eliminarCuenta() async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('eliminarCuenta');
    await callable.call<Map<String, dynamic>>();
    // La cuenta ya no existe -- los ajustes de seguridad local (bloqueo
    // biométrico, timeout, protección de documentos) son del dispositivo,
    // no de Firebase, así que la Cloud Function no los toca.
    await SecurityPreferencesService.instance.limpiarTodo();
  }
}
