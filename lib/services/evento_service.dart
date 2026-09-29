// lib/services/evento_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/evento.dart';

class EventoService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('eventos');

  /// Timeline completa de la casa, más reciente primero -- es la pantalla
  /// "Historial" (sección 12 del spec de producto).
  static Stream<List<Evento>> streamHistorial(String casaId, {String? elementoId}) {
    Query<Map<String, dynamic>> q = _col(casaId).orderBy('fecha', descending: true);
    if (elementoId != null) q = q.where('elementoId', isEqualTo: elementoId);
    return q.snapshots().map((s) => s.docs.map(Evento.fromDoc).toList());
  }

  static Future<String> crear(String casaId, Evento evento, {required String createdBy}) async {
    final ref = await _col(casaId).add({...evento.toMap(), 'createdBy': createdBy});
    return ref.id;
  }

  static Future<void> eliminar(String casaId, String eventoId) async {
    await _col(casaId).doc(eventoId).delete();
  }
}
