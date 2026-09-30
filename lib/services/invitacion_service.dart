// lib/services/invitacion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/invitacion.dart';

class InvitacionService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static Future<void> invitarProfesional({
    required String casaId,
    required String trabajoId,
    required String emailProfesional,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('invitarProfesional');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'emailProfesional': emailProfesional,
    });
  }

  static Future<void> responder(String invitacionId, {required bool aceptar}) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('responderInvitacion');
    await callable.call<Map<String, dynamic>>({'invitacionId': invitacionId, 'aceptar': aceptar});
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
