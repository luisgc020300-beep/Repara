// lib/services/invitacion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/invitacion.dart';

/// Resultado de invitarProfesional: 'directa' si ya existía una cuenta
/// profesional con ese email (invitación normal); 'abierta' si no existía
/// cuenta y se generó un código para compartir a mano.
class ResultadoInvitacion {
  const ResultadoInvitacion({required this.esDirecta, this.codigo});
  final bool esDirecta;
  final String? codigo;
}

class InvitacionService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static Future<ResultadoInvitacion> invitarProfesional({
    required String casaId,
    required String trabajoId,
    String? emailProfesional,
    String? telefonoProfesional,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('invitarProfesional');
    final result = await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'emailProfesional': ?emailProfesional,
      'telefonoProfesional': ?telefonoProfesional,
    });
    final tipo = result.data['tipo'] as String?;
    return ResultadoInvitacion(esDirecta: tipo == 'directa', codigo: result.data['codigo'] as String?);
  }

  /// Lo llama quien recibe un código de invitación (sección "idea 1" del
  /// bucle viral): no necesita tener cuenta profesional activada de
  /// antemano, esta función la activa si hace falta.
  static Future<({String casaNombre, String trabajoTitulo})> canjearCodigo(String codigo) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('canjearCodigoInvitacion');
    final result = await callable.call<Map<String, dynamic>>({'codigo': codigo});
    return (
      casaNombre: result.data['casaNombre'] as String? ?? '',
      trabajoTitulo: result.data['trabajoTitulo'] as String? ?? '',
    );
  }

  static Future<void> responder(String invitacionId, {required bool aceptar}) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('responderInvitacion');
    await callable.call<Map<String, dynamic>>({'invitacionId': invitacionId, 'aceptar': aceptar});
  }

  /// Para cuando el profesional invitado nunca responde -- sin esto el
  /// propietario se queda sin ninguna vía para invitar a otra persona.
  static Future<void> cancelar(String invitacionId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('cancelarInvitacion');
    await callable.call<Map<String, dynamic>>({'invitacionId': invitacionId});
  }

  /// La última invitación enviada para un trabajo (puede no haber ninguna).
  static Stream<Invitacion?> streamUltimaInvitacionDe(String trabajoId) {
    return _db
        .collection('invitaciones')
        .where('trabajoId', isEqualTo: trabajoId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : Invitacion.fromDoc(s.docs.first));
  }

  /// Invitaciones pendientes de respuesta para el profesional actual.
  static Stream<List<Invitacion>> streamPendientesParaMi() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('invitaciones')
        .where('profesionalUid', isEqualTo: uid)
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((s) => s.docs.map(Invitacion.fromDoc).toList());
  }
}
