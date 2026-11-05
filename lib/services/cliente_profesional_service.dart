// lib/services/cliente_profesional_service.dart
//
// Clientes privados del profesional (Fase 1, noviembre 2026). Escritura
// directa a Firestore, sin Cloud Function -- mismo criterio que
// CitaService: puramente del propio profesional, nadie más necesita
// confiar en estos datos todavía (ver firestore.rules).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cliente_profesional.dart';
import 'stream_error_logging.dart';

class ClienteProfesionalService {
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
    return _db.collection('profesionales').doc(uid).collection('clientesPro');
  }

  static Stream<List<ClienteProfesional>> streamClientes() {
    final col = _col();
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs.map(ClienteProfesional.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Future<String?> crear(ClienteProfesional cliente) async {
    final col = _col();
    if (col == null) return null;
    final ref = await col.add({
      ...cliente.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> actualizar(
    String clienteId,
    ClienteProfesional cliente,
  ) async {
    final col = _col();
    if (col == null) return;
    await col.doc(clienteId).update(cliente.toMap());
  }

  static Future<void> eliminar(String clienteId) async {
    final col = _col();
    if (col == null) return;
    await col.doc(clienteId).delete();
  }
}
