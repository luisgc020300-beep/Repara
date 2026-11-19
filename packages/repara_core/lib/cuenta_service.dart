// lib/cuenta_service.dart
//
// Borrado de cuenta (derecho de supresión RGPD + requisito de Apple/Google
// de poder borrar la cuenta desde dentro de la app) -- movido del monolito
// a repara_core en noviembre 2026 para que Hogar y Pro lo reutilicen sin
// duplicarlo. Toda la lógica de cascada vive en la Cloud Function
// eliminarCuenta -- aquí solo se llama.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'security_preferences_service.dart';

class CuentaService {
  static const _region = 'europe-west1';

  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general. Solo [streamDescripcionPerfil]/
  /// [actualizarDescripcionPerfil] lo usan (el resto de este archivo son
  /// Cloud Functions, no escrituras directas).
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;

  /// El nombre real que ven los demás (no el displayName de FirebaseAuth,
  /// que ninguna de las dos apps escribe nunca) -- ver
  /// [actualizarNombrePerfil]. null mientras no exista el documento o no
  /// tenga nombre todavía.
  static Stream<String?> streamNombrePerfil(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['displayName'] as String?);
  }

  /// Breve presentación personal (mejora de perfiles, noviembre 2026) --
  /// solo visible en la propia CuentaScreen de Hogar (ver
  /// permitirEditarDescripcion), nunca a otros miembros de la casa: a
  /// diferencia de displayName, no se copia en memberProfiles porque ninguna
  /// pantalla muestra hoy el perfil de otro miembro, así que no hace falta
  /// pasar por Cloud Function -- escritura directa, igual que
  /// users/{uid}.displayName ya permitía firestore.rules antes de que
  /// existiera actualizarNombrePerfil.
  static Stream<String?> streamDescripcionPerfil(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['descripcion'] as String?);
  }

  static Future<void> actualizarDescripcionPerfil(
    String uid,
    String descripcion,
  ) async {
    await _db.collection('users').doc(uid).set({
      'descripcion': descripcion,
    }, SetOptions(merge: true));
  }

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

  /// Cambia el nombre que ven los demás (saludo de Inicio, "Miembros de
  /// esta casa", notificaciones) -- pasa por Cloud Function, no por una
  /// escritura directa a users/{uid}, porque ese nombre está copiado dentro
  /// de memberProfiles de cada casa a la que perteneces; la función
  /// actualiza el original y propaga la copia a todas ellas en una sola
  /// operación (rediseño de registro/perfil de Hogar, noviembre 2026).
  static Future<void> actualizarNombrePerfil(String nombre) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('actualizarNombrePerfil');
    await callable.call<Map<String, dynamic>>({'nombre': nombre});
  }
}
