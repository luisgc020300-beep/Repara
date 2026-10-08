// lib/services/notificacion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notificacion.dart';
import 'stream_error_logging.dart';

class NotificacionService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<Notificacion>> streamMisNotificaciones() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
