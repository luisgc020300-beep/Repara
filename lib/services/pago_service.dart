// lib/services/pago_service.dart
//
// Escritura directa a Firestore, no vía Cloud Function: a diferencia de
// presupuestos/cambiosAlcance (que necesitan impedir que el profesional se
// autoapruebe), aquí solo escribe el propietario sus propios pagos -- no
// hay ninguna aprobación entre dos partes que proteger.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/pago.dart';
import 'stream_error_logging.dart';

class PagoService {
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

  static CollectionReference<Map<String, dynamic>> _col(String casaId, String elementoId, String registroId) => _db
      .collection('casas')
      .doc(casaId)
      .collection('elementos')
      .doc(elementoId)
      .collection('registros')
      .doc(registroId)
      .collection('pagos');

  static Stream<List<Pago>> streamPagos(String casaId, String elementoId, String registroId) {
    return _col(casaId, elementoId, registroId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Pago.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Future<void> crear(String casaId, String elementoId, String registroId, Pago pago) async {
    await _col(casaId, elementoId, registroId).add({...pago.toMap(), 'createdAt': FieldValue.serverTimestamp(), 'createdBy': _uid});
  }

  static Future<void> actualizar(String casaId, String elementoId, String registroId, String pagoId, Pago pago) async {
    await _col(casaId, elementoId, registroId).doc(pagoId).update(pago.toMap());
  }

  static Future<void> eliminar(String casaId, String elementoId, String registroId, String pagoId) async {
    await _col(casaId, elementoId, registroId).doc(pagoId).delete();
  }

  /// Lectura puntual (no stream) usada antes de finalizar un registro, para
  /// avisar si falta algo por pagar sin tener que mantener un segundo campo
  /// cacheado en el propio registro que pudiera desincronizarse.
  static Future<double> totalPagado(String casaId, String elementoId, String registroId) async {
    final snap = await _col(casaId, elementoId, registroId).get();
    return snap.docs.fold<double>(0, (acc, d) => acc + ((d.data()['importe'] as num?)?.toDouble() ?? 0));
  }

  /// Lectura puntual de un pago concreto -- usada al abrir la notificación
  /// de "te han registrado un pago" (ver notificaciones_screen.dart).
  static Future<Pago?> obtenerPago(String casaId, String elementoId, String registroId, String pagoId) async {
    final doc = await _col(casaId, elementoId, registroId).doc(pagoId).get();
    return doc.exists ? Pago.fromDoc(doc) : null;
  }
}
