// lib/perfil_profesional_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:repara_core/perfil_profesional_publico.dart';
import 'package:repara_core/profesional_cercano.dart';
import 'package:repara_core/stream_error_logging.dart';

class PerfilProfesionalService {
  /// Seams de solo test -- nunca se asignan en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid => debugFirestoreOverride != null
      ? debugUidOverride
      : FirebaseAuth.instance.currentUser?.uid;
  static const _region = 'europe-west1';

  static Stream<PerfilProfesionalPublico?> streamPerfilPublico(String uid) {
    return _db
        .collection('profesionalesPublico')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? PerfilProfesionalPublico.fromDoc(doc) : null)
        .conRegistroDeErrores();
  }

  /// Null si todavía no has valorado ese registro.
  static Stream<MiValoracion?> streamMiValoracion(String registroId) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('valoraciones')
        .doc('${registroId}_$uid')
        .snapshots()
        .map((doc) => doc.exists ? MiValoracion.fromDoc(doc) : null)
        .conRegistroDeErrores();
  }

  /// Lanza FirebaseFunctionsException con code 'already-exists' si ya habías
  /// valorado este registro, 'failed-precondition' si no está terminado o no
  /// tiene profesional vinculado -- la UI debe mostrar ese mensaje tal cual.
  static Future<void> crearValoracion({
    required String casaId,
    required String elementoId,
    required String registroId,
    required int puntuacion,
    String? comentario,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('crearValoracion');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'puntuacion': puntuacion,
      if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
    });
  }

  /// Reputación de REPARA Pro (noviembre 2026): todas las valoraciones
  /// recibidas por el profesional que ha iniciado sesión -- mismo criterio
  /// de consulta "solo mi propio uid" que ya usa InvitacionService.
  /// streamPendientesParaMi (firestore.rules ya lo permite sin cambios: la
  /// condición de lectura es justo esta igualdad). Sin orderBy en la propia
  /// consulta a propósito, mismo motivo que InvitacionService.
  /// streamAceptadasRecientes -- combinarlo con el where exigiría un índice
  /// compuesto nuevo; se ordena aquí mismo tras recibir el snapshot.
  static Stream<List<ValoracionRecibida>> streamMisValoracionesRecibidas() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('valoraciones')
        .where('profesionalUid', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final lista = s.docs.map(ValoracionRecibida.fromDoc).toList()
            ..sort((a, b) {
              final a0 = a.createdAt ?? DateTime(2000);
              final b0 = b.createdAt ?? DateTime(2000);
              return b0.compareTo(a0);
            });
          return lista;
        })
        .conRegistroDeErrores();
  }

  /// Cercanos (noviembre 2026): el servidor calcula la distancia y solo
  /// devuelve kilómetros redondeados, ya ordenados de más a menos cerca --
  /// nunca coordenadas (ver buscarProfesionalesCercanos en
  /// functions/index.js). Lanza FirebaseFunctionsException con code
  /// 'resource-exhausted' si se ha repetido demasiadas veces en el día.
  static Future<List<ProfesionalCercano>> buscarCercanos({
    required double lat,
    required double lng,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('buscarProfesionalesCercanos');
    final result = await callable.call<Map<String, dynamic>>({
      'lat': lat,
      'lng': lng,
    });
    final lista = (result.data['resultados'] as List?) ?? [];
    return lista
        .map((e) => ProfesionalCercano.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
