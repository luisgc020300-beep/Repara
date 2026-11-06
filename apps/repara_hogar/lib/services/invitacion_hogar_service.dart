// lib/services/invitacion_hogar_service.dart
//
// Espejo de invitacion_service.dart, dirección inversa -- ver
// lib/models/invitacion_hogar.dart.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:repara_core/stream_error_logging.dart';

import '../models/invitacion_hogar.dart';

/// Resultado de responderInvitacionHogar al aceptar: dónde quedó guardado
/// el trabajo real (casa/elemento/registro), para poder navegar allí
/// directamente tras aceptar.
class VinculoTrabajoHogar {
  const VinculoTrabajoHogar({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
  });
  final String casaId;
  final String elementoId;
  final String registroId;
}

class InvitacionHogarService {
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

  /// Invitaciones pendientes de respuesta para el propietario actual.
  static Stream<List<InvitacionHogar>> streamPendientesParaMi() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('invitacionesHogar')
        .where('propietarioUid', isEqualTo: uid)
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((s) => s.docs.map(InvitacionHogar.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Future<({String? titulo, String? profesionalNombre})> canjearCodigo(
    String codigo,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('canjearCodigoInvitacionHogar');
    final result = await callable.call<Map<String, dynamic>>({
      'codigo': codigo,
    });
    return (
      titulo: result.data['titulo'] as String?,
      profesionalNombre: result.data['profesionalNombre'] as String?,
    );
  }

  static Future<VinculoTrabajoHogar?> responder(
    String invitacionId, {
    required bool aceptar,
    String? casaId,
    // Elemento ya existente al que debe pertenecer el nuevo registro
    // (p.ej. "Pérgolas") -- si no se indica, el servidor crea uno nuevo con
    // el título del trabajo (ver responderInvitacionHogar).
    String? elementoId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable('responderInvitacionHogar');
    final result = await callable.call<Map<String, dynamic>>({
      'invitacionId': invitacionId,
      'aceptar': aceptar,
      'casaId': ?casaId,
      'elementoId': ?elementoId,
    });
    final vinculo = result.data['vinculo'] as Map<String, dynamic>?;
    if (vinculo == null) return null;
    return VinculoTrabajoHogar(
      casaId: vinculo['casaId'] as String,
      elementoId: vinculo['elementoId'] as String,
      registroId: vinculo['registroId'] as String,
    );
  }
}
