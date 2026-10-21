// lib/services/historial_service.dart
//
// Solo lectura -- el historial lo escriben únicamente las Cloud Functions
// (ver firestore.rules: `historial` tiene `allow write: if false`). No hay
// aquí ningún método de escritura a propósito.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/historial_evento.dart';
import 'stream_error_logging.dart';

class HistorialService {
  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;

  static Stream<List<HistorialEvento>> streamHistorial(
    String casaId,
    String elementoId,
    String registroId,
  ) {
    return _db
        .collection('casas')
        .doc(casaId)
        .collection('elementos')
        .doc(elementoId)
        .collection('registros')
        .doc(registroId)
        .collection('historial')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(HistorialEvento.fromDoc).toList())
        .conRegistroDeErrores();
  }
}
