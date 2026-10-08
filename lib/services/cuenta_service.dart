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

  /// Invalida los refresh tokens de la cuenta (Fase H de la misión de
  /// seguridad local). El propio dispositivo que llama a esto debe hacer
  /// signOut() local justo después -- esto NO lo hace por sí solo, y otros
  /// dispositivos con sesión abierta no se desconectan al instante (ver
  /// comentario de cerrarSesionesEnTodosLosDispositivos en functions/index.js).
  static Future<void> cerrarSesionesEnTodosLosDispositivos() async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('cerrarSesionesEnTodosLosDispositivos');
    await callable.call<Map<String, dynamic>>();
  }
}
