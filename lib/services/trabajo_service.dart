// lib/services/trabajo_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/trabajo.dart';
import 'stream_error_logging.dart';

class TrabajoService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('trabajos');

  static Stream<List<Trabajo>> streamTrabajos(String casaId) {
    return _col(casaId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Trabajo.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Stream<Trabajo?> streamTrabajo(String casaId, String trabajoId) {
    return _col(casaId)
        .doc(trabajoId)
        .snapshots()
        .map((d) => d.exists ? Trabajo.fromDoc(d) : null)
        .conRegistroDeErrores();
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

  /// El profesional dice que ha terminado -- no cierra el trabajo todavía,
  /// solo lo deja pendiente de que el propietario lo confirme o lo rechace
  /// (modelo de dos pasos, auditoría de producto, octubre 2026).
  static Future<void> marcarFinalizadoProfesional(String casaId, String trabajoId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('marcarTrabajoFinalizadoProfesional');
    await callable.call<Map<String, dynamic>>({'casaId': casaId, 'trabajoId': trabajoId});
  }

  /// El propietario dice que todavía no está terminado -- devuelve el
  /// trabajo al estado en que estaba antes de que el profesional lo
  /// marcara, y avisa al profesional.
  static Future<void> rechazarFinalizacionProfesional(String casaId, String trabajoId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('rechazarFinalizacionProfesional');
    await callable.call<Map<String, dynamic>>({'casaId': casaId, 'trabajoId': trabajoId});
  }
}
