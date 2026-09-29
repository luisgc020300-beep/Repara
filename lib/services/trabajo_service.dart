// lib/services/trabajo_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trabajo.dart';

class TrabajoService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('trabajos');

  static Stream<List<Trabajo>> streamTrabajos(String casaId) {
    return _col(casaId).orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map(Trabajo.fromDoc).toList());
  }

  static Stream<Trabajo?> streamTrabajo(String casaId, String trabajoId) {
    return _col(casaId).doc(trabajoId).snapshots().map((d) => d.exists ? Trabajo.fromDoc(d) : null);
  }

  static Future<String> crear(String casaId, Trabajo trabajo, {required String createdBy}) async {
    final ref = await _col(casaId).add({...trabajo.toMap(), 'createdBy': createdBy});
    return ref.id;
  }

  static Future<void> actualizarEstado(String casaId, String trabajoId, EstadoTrabajo estado) async {
    await _col(casaId).doc(trabajoId).update({'estado': estado.name});
  }

  static Future<void> actualizar(String casaId, String trabajoId, Map<String, dynamic> cambios) async {
    await _col(casaId).doc(trabajoId).update(cambios);
  }

  static Future<void> eliminar(String casaId, String trabajoId) async {
    await _col(casaId).doc(trabajoId).delete();
  }
}
