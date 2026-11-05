// lib/services/trabajo_profesional_service.dart
//
// Trabajos privados del profesional (Fase 1, noviembre 2026). Escritura
// directa a Firestore, sin Cloud Function -- mismo criterio que
// CitaService/ClienteProfesionalService.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/trabajo_profesional.dart';
import 'stream_error_logging.dart';

class TrabajoProfesionalService {
  /// Seams de solo test -- nunca se asignan en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid => debugFirestoreOverride != null
      ? debugUidOverride
      : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('profesionales').doc(uid).collection('trabajosPro');
  }

  static Stream<List<TrabajoProfesional>> streamTrabajos() {
    final col = _col();
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TrabajoProfesional.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Stream<List<TrabajoProfesional>> streamTrabajosDeCliente(
    String clienteId,
  ) {
    final col = _col();
    if (col == null) return Stream.value(const []);
    return col
        .where('clienteId', isEqualTo: clienteId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TrabajoProfesional.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Future<String?> crear(TrabajoProfesional trabajo) async {
    final col = _col();
    if (col == null) return null;
    final ref = await col.add({
      ...trabajo.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> actualizar(
    String trabajoId,
    TrabajoProfesional trabajo,
  ) async {
    final col = _col();
    if (col == null) return;
    await col.doc(trabajoId).update(trabajo.toMap());
  }

  static Future<void> actualizarEstado(
    String trabajoId,
    EstadoTrabajoProfesional estado,
  ) async {
    final col = _col();
    if (col == null) return;
    await col.doc(trabajoId).update({
      'estado': estado.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> eliminar(String trabajoId) async {
    final col = _col();
    if (col == null) return;
    await col.doc(trabajoId).delete();
  }
}
