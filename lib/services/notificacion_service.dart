// lib/services/notificacion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:repara_core/stream_error_logging.dart';

import '../models/notificacion.dart';

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

  /// "Marcar todas como leídas" (sección 2.6 del encargo de avisos
  /// inteligentes) -- batched, cada escritura individual sigue tocando solo
  /// `leida` (lo único que permite firestore.rules), así que no hace falta
  /// ningún permiso nuevo.
  static Future<void> marcarTodasLeidas(List<String> notificacionIds) async {
    if (notificacionIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in notificacionIds) {
      batch.update(_db.collection('notificaciones').doc(id), {'leida': true});
    }
    await batch.commit();
  }

  /// Preferencias de notificación (sección 6) -- dato puramente personal del
  /// propio usuario, sin ninguna regla nueva (users/{uid} ya es de solo
  /// isOwner). Las claves ausentes se tratan como `true` (todo activado por
  /// defecto) -- nunca al revés, para que una cuenta recién creada siga
  /// recibiendo avisos sin tener que entrar primero a activarlos a mano.
  static Stream<Map<String, dynamic>> streamPreferencias() {
    final uid = _uid;
    if (uid == null) return Stream.value(const {});
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => (s.data()?['notifPrefs'] as Map<String, dynamic>?) ?? const {})
        .conRegistroDeErrores();
  }

  static Future<void> actualizarPreferencia(String clave, bool activada) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'notifPrefs': {clave: activada},
    }, SetOptions(merge: true));
  }
}
