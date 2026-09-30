// lib/services/presupuesto_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/presupuesto.dart';

class PresupuestoService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId, String trabajoId) =>
      _db.collection('casas').doc(casaId).collection('trabajos').doc(trabajoId).collection('presupuestos');

  static Stream<List<Presupuesto>> streamPresupuestos(String casaId, String trabajoId) {
    return _col(casaId, trabajoId).orderBy('fechaCreacion', descending: true).snapshots().map(
        (s) => s.docs.map(Presupuesto.fromDoc).toList());
  }

  /// Todas las escrituras pasan por Cloud Functions -- ver
  /// functions/index.js, sección "PRESUPUESTOS". Los totales siempre se
  /// recalculan en servidor, nunca se confía en lo que mande el cliente.
  static Future<void> crear({
    required String casaId,
    required String trabajoId,
    required List<LineaPresupuesto> lineas,
    String? notas,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('crearPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'lineas': lineas.map((l) => l.toMap()).toList(),
      'notas': notas,
    });
  }

  static Future<void> actualizarLineas({
    required String casaId,
    required String trabajoId,
    required String presupuestoId,
    required List<LineaPresupuesto> lineas,
    String? notas,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('actualizarLineasPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'presupuestoId': presupuestoId,
      'lineas': lineas.map((l) => l.toMap()).toList(),
      'notas': notas,
    });
  }

  static Future<void> enviar({required String casaId, required String trabajoId, required String presupuestoId}) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('enviarPresupuesto');
    await callable.call<Map<String, dynamic>>({'casaId': casaId, 'trabajoId': trabajoId, 'presupuestoId': presupuestoId});
  }

  static Future<void> responder({
    required String casaId,
    required String trabajoId,
    required String presupuestoId,
    required bool aceptar,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('responderPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'presupuestoId': presupuestoId,
      'aceptar': aceptar,
    });
  }

  static Future<void> crearNuevaVersion({
    required String casaId,
    required String trabajoId,
    required String presupuestoAnteriorId,
    required List<LineaPresupuesto> lineas,
    String? notas,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('crearNuevaVersionPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'trabajoId': trabajoId,
      'presupuestoAnteriorId': presupuestoAnteriorId,
      'lineas': lineas.map((l) => l.toMap()).toList(),
      'notas': notas,
    });
  }
}
