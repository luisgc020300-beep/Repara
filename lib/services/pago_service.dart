// lib/services/pago_service.dart
//
// crear()/actualizar() pasan por Cloud Function (registrarPago/
// actualizarPago) desde la corrección DATA-1 de integridad económica
// (octubre 2026): antes se escribía directo a Firestore, comprobando el
// total pagado contra el presupuesto en el cliente ANTES de escribir --
// esa lectura y esa escritura nunca eran una operación atómica, así que dos
// pagos simultáneos podían sumar entre los dos más que el presupuesto. Las
// Cloud Functions repiten esa comprobación dentro de una transacción en
// servidor, donde sí es atómica. eliminar() sigue siendo escritura directa
// -- borrar un pago nunca puede hacer que la suma supere el presupuesto.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/pago.dart';
import 'stream_error_logging.dart';

class PagoService {
  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general. crear()/actualizar() no
  /// tienen seam propio: no hay forma de fakear FirebaseFunctions en este
  /// repo todavía (mismo criterio que presupuesto_service.dart).
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  static const _region = 'europe-west1';

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

  /// [clientRequestId]: generado UNA SOLA VEZ por intento lógico de guardado
  /// (ver lib/core/idempotency.dart) -- un reintento de red que reutilice el
  /// mismo valor no duplica el pago en servidor.
  static Future<void> crear(String casaId, String elementoId, String registroId, Pago pago, {String? clientRequestId}) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('registrarPago');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'importe': pago.importe,
      'fecha': pago.fecha.millisecondsSinceEpoch,
      'concepto': pago.concepto,
      'descripcion': pago.descripcion,
      'metodo': pago.metodo?.name,
      // ignore: use_null_aware_elements
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
    });
  }

  static Future<void> actualizar(String casaId, String elementoId, String registroId, String pagoId, Pago pago) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('actualizarPago');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'pagoId': pagoId,
      'importe': pago.importe,
      'fecha': pago.fecha.millisecondsSinceEpoch,
      'concepto': pago.concepto,
      'descripcion': pago.descripcion,
      'metodo': pago.metodo?.name,
    });
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
