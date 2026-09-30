// lib/services/cambio_alcance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/cambio_alcance.dart';

class CambioAlcanceService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId, String trabajoId) =>
      _db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId).collection('cambiosAlcance');

  static Stream<List<CambioAlcance>> streamCambios(String casaId, String trabajoId) {
    return _col(casaId, trabajoId).orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map(CambioAlcance.fromDoc).toList());
  }

  static Future<void> crear({
    required String casaId,
    required String trabajoId,
    required String titulo,
    String? descripcion,
    String? motivo,
    double? importeAdicional,
    double? tiempoAdicionalHoras,
    List<String> fotos = const [],
    String? presupuestoId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('crearCambioAlcance');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'titulo': titulo,
      'descripcion': descripcion,
      'motivo': motivo,
      'importeAdicional': importeAdicional,
      'tiempoAdicionalHoras': tiempoAdicionalHoras,
      'fotos': fotos,
      'presupuestoId': presupuestoId,
    });
  }

  static Future<void> responder({
    required String casaId,
    required String trabajoId,
    required String cambioAlcanceId,
    required bool aprobar,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('responderCambioAlcance');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'cambioAlcanceId': cambioAlcanceId,
      'aprobar': aprobar,
    });
  }

  static Future<void> cancelar({required String casaId, required String trabajoId, required String cambioAlcanceId}) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('cancelarCambioAlcance');
    await callable.call<Map<String, dynamic>>({'casaId': casaId, 'trabajoId': trabajoId, 'cambioAlcanceId': cambioAlcanceId});
  }
}
