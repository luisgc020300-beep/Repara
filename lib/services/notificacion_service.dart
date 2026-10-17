// lib/services/notificacion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/notificacion.dart';
import 'stream_error_logging.dart';

class NotificacionService {
  /// Seams de solo test -- nunca se asignan en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  // Ver casa_service.dart: debugFirestoreOverride (no debugUidOverride) es
  // la señal real de "estamos en test", para poder simular uid null aposta.
  static String? get _uid => debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static Stream<List<Notificacion>> streamMisNotificaciones() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('notificaciones')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(Notificacion.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Future<void> marcarLeida(String notificacionId) async {
    await _db.collection('notificaciones').doc(notificacionId).update({'leida': true});
  }
}
