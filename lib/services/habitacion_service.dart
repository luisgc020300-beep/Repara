// lib/services/habitacion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/habitacion.dart';
import 'stream_error_logging.dart';

class HabitacionService {
  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('habitaciones');

  static Stream<List<Habitacion>> streamHabitaciones(String casaId) {
    return _col(casaId)
        .orderBy('orden')
        .snapshots()
        .map((s) => s.docs.map(Habitacion.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Future<void> crear(String casaId, String nombre, {String? icono, required int orden}) async {
    await _col(casaId).add(Habitacion(id: '', nombre: nombre, orden: orden, icono: icono).toMap());
  }

  static Future<void> eliminar(String casaId, String habitacionId) async {
    await _col(casaId).doc(habitacionId).delete();
  }
}
