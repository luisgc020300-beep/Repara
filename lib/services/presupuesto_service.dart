// lib/services/presupuesto_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/presupuesto.dart';
import 'stream_error_logging.dart';

class PresupuestoService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId, String elementoId, String registroId) => _db
      .collection('casas')
      .doc(casaId)
      .collection('elementos')
      .doc(elementoId)
      .collection('registros')
      .doc(registroId)
      .collection('presupuestos');

  static Stream<List<Presupuesto>> streamPresupuestos(String casaId, String elementoId, String registroId) {
    return _col(casaId, elementoId, registroId)
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Presupuesto.fromDoc).toList())
        .conRegistroDeErrores();
  }

  /// Todas las escrituras pasan por Cloud Functions -- ver
  /// functions/index.js, sección "PRESUPUESTOS". Los totales siempre se
  /// recalculan en servidor, nunca se confía en lo que mande el cliente.
  static Future<void> crear({
    required String casaId,
    required String elementoId,
    required String registroId,
    required List<LineaPresupuesto> lineas,
    String? notas,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('crearPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'lineas': lineas.map((l) => l.toMap()).toList(),
      'notas': notas,
    });
  }

  static Future<void> actualizarLineas({
    required String casaId,
    required String elementoId,
    required String registroId,
    required String presupuestoId,
    required List<LineaPresupuesto> lineas,
    String? notas,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('actualizarLineasPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'presupuestoId': presupuestoId,
      'lineas': lineas.map((l) => l.toMap()).toList(),
      'notas': notas,
    });
  }

  static Future<void> enviar({
    required String casaId,
    required String elementoId,
    required String registroId,
    required String presupuestoId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('enviarPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'presupuestoId': presupuestoId,
    });
  }

  static Future<void> responder({
    required String casaId,
    required String elementoId,
    required String registroId,
    required String presupuestoId,
    required bool aceptar,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('responderPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'presupuestoId': presupuestoId,
      'aceptar': aceptar,
    });
  }

  static Future<void> crearNuevaVersion({
    required String casaId,
    required String elementoId,
    required String registroId,
    required String presupuestoAnteriorId,
    required List<LineaPresupuesto> lineas,
    String? notas,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('crearNuevaVersionPresupuesto');
    await callable.call<Map<String, dynamic>>({
      'casaId': casaId,
      'elementoId': elementoId,
      'registroId': registroId,
      'presupuestoAnteriorId': presupuestoAnteriorId,
      'lineas': lineas.map((l) => l.toMap()).toList(),
      'notas': notas,
    });
  }
}
