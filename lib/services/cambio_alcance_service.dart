// lib/services/cambio_alcance_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/cambio_alcance.dart';
import 'stream_error_logging.dart';

class CambioAlcanceService {
  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general.
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
      .collection('cambiosAlcance');

  /// La ruta de Storage tiene que coincidir exactamente con
  /// storage.rules (casas/{cid}/elementos/{eid}/registros/{rid}/
  /// cambiosAlcance/) -- antes de esta migración no coincidían (el upload
  /// nunca incluía el id del trabajo), así que un profesional no miembro
  /// de la casa no tenía permiso real para subir su propia foto y caía al
  /// catch-all genérico de la casa, que SÍ le denegaba. Corregido de paso.
  static Future<String> subirFoto(String casaId, String elementoId, String registroId, File archivo, String nombreArchivo) async {
    final ref = FirebaseStorage.instance.ref().child(
        'casas/$casaId/elementos/$elementoId/registros/$registroId/cambiosAlcance/${DateTime.now().millisecondsSinceEpoch}_$nombreArchivo');
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }

  static Stream<List<CambioAlcance>> streamCambios(String casaId, String elementoId, String registroId) {
    return _col(casaId, elementoId, registroId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CambioAlcance.fromDoc).toList())
        .conRegistroDeErrores();
  }

  /// [clientRequestId]: generado UNA SOLA VEZ por intento lógico de envío
  /// (ver lib/core/idempotency.dart) -- un reintento de red que reutilice el
  /// mismo valor no duplica la solicitud en servidor (DATA-6, auditoría de
  /// integridad económica, octubre 2026).
  static Future<void> crear({
    required String casaId,
    required String elementoId,
    required String registroId,
    required String titulo,
    String? descripcion,
    String? motivo,
    double? importeAdicional,
    double? tiempoAdicionalHoras,
    List<String> fotos = const [],
    String? presupuestoId,
    String? clientRequestId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('crearCambioAlcance');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'titulo': titulo,
      'descripcion': descripcion,
      'motivo': motivo,
      'importeAdicional': importeAdicional,
      'tiempoAdicionalHoras': tiempoAdicionalHoras,
      'fotos': fotos,
      'presupuestoId': presupuestoId,
      // ignore: use_null_aware_elements
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
    });
  }

  static Future<void> responder({
    required String casaId,
    required String elementoId,
    required String registroId,
    required String cambioAlcanceId,
    required bool aprobar,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('responderCambioAlcance');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'cambioAlcanceId': cambioAlcanceId,
      'aprobar': aprobar,
    });
  }

  static Future<void> cancelar({
    required String casaId,
    required String elementoId,
    required String registroId,
    required String cambioAlcanceId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('cancelarCambioAlcance');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'cambioAlcanceId': cambioAlcanceId,
    });
  }
}
