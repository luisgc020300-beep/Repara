// lib/services/registro_service.dart
//
// Octubre 2026 -- reemplaza TrabajoService (y la mitad de EventoService que
// vivía como "nota" ligada a un trabajo): un registro es cada suceso de un
// Elemento, casas/{casaId}/elementos/{elementoId}/registros/{registroId}.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/elemento.dart';
import '../models/registro.dart';
import 'elemento_service.dart';
import 'stream_error_logging.dart';

class RegistroService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId, String elementoId) =>
      _db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).collection('registros');

  static Stream<List<Registro>> streamRegistros(String casaId, String elementoId) {
    return _col(casaId, elementoId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Registro.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Stream<Registro?> streamRegistro(String casaId, String elementoId, String registroId) {
    return _col(casaId, elementoId)
        .doc(registroId)
        .snapshots()
        .map((d) => d.exists ? Registro.fromDoc(d) : null)
        .conRegistroDeErrores();
  }

  /// `casaId` se guarda también como campo (no solo en la ruta) porque el
  /// resumen de "pendientes" lo necesita para su consulta collectionGroup
  /// del lado servidor (ver onRegistroEstadoCambiado en functions/index.js).
  static Future<String> crear(String casaId, String elementoId, Registro registro, {required String createdBy}) async {
    final ref = await _col(casaId, elementoId).add({
      ...registro.toMap(),
      'casaId': casaId,
      'createdBy': createdBy,
    });
    return ref.id;
  }

  static Future<void> actualizarEstado(String casaId, String elementoId, String registroId, EstadoRegistro estado) async {
    await _col(casaId, elementoId).doc(registroId).update({'estado': estado.name});
  }

  static Future<void> actualizar(String casaId, String elementoId, String registroId, Map<String, dynamic> cambios) async {
    await _col(casaId, elementoId).doc(registroId).update(cambios);
  }

  static Future<void> eliminar(String casaId, String elementoId, String registroId) async {
    await _col(casaId, elementoId).doc(registroId).delete();
  }

  /// El propietario cierra el registro directamente, o confirma que el
  /// profesional de verdad ha terminado (modelo de dos pasos).
  static Future<void> finalizar(String casaId, String elementoId, String registroId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('finalizarTrabajoPropietario');
    await callable.call<Map<String, dynamic>>({'casaId': casaId, 'elementoId': elementoId, 'registroId': registroId});
  }

  /// El profesional dice que ha terminado -- no cierra el registro todavía,
  /// solo lo deja pendiente de que el propietario lo confirme o lo rechace
  /// (modelo de dos pasos, auditoría de producto, octubre 2026).
  static Future<void> marcarFinalizadoProfesional(String casaId, String elementoId, String registroId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('marcarTrabajoFinalizadoProfesional');
    await callable.call<Map<String, dynamic>>({'casaId': casaId, 'elementoId': elementoId, 'registroId': registroId});
  }

  /// El propietario dice que todavía no está terminado -- devuelve el
  /// registro al estado en que estaba antes de que el profesional lo
  /// marcara, y avisa al profesional.
  static Future<void> rechazarFinalizacionProfesional(String casaId, String elementoId, String registroId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('rechazarFinalizacionProfesional');
    await callable.call<Map<String, dynamic>>({'casaId': casaId, 'elementoId': elementoId, 'registroId': registroId});
  }

  /// Banner de "pendientes" en Inicio -- un único documento mantenido por
  /// la Cloud Function onRegistroEstadoCambiado (ver el porqué, evitando
  /// una consulta collectionGroup directa, en firestore.rules).
  static Stream<List<Map<String, dynamic>>> streamPendientes(String casaId) {
    return _db
        .collection('casas')
        .doc(casaId)
        .collection('resumen')
        .doc('pendientes')
        .snapshots()
        .map((d) => List<Map<String, dynamic>>.from(
            (d.data()?['registros'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const []))
        .conRegistroDeErrores();
  }

  /// Botón "Trabajos pendientes" de Inicio: un elemento por cada uno que
  /// tenga al menos un registro con profesional todavía sin cerrar. Lectura
  /// puntual (no stream) recorriendo la subcolección de registros de cada
  /// elemento -- un registro nunca vive en una colección a nivel de casa,
  /// así que no hay una única consulta que lo traiga todo de golpe (mismo
  /// patrón que ExpedienteViviendaScreen._todosLosRegistros). Ordenado por
  /// fecha ascendente: el que lleva más tiempo esperando sale primero.
  static Future<List<({Elemento elemento, String registroTitulo, DateTime fecha})>> elementosConTrabajoPendiente(
      String casaId) async {
    final elementos = await ElementoService.streamElementos(casaId).first;
    final resultado = <({Elemento elemento, String registroTitulo, DateTime fecha})>[];
    for (final elemento in elementos) {
      final registros = await streamRegistros(casaId, elemento.id).first;
      final pendientes = registros
          .where((r) => r.esConProfesional && r.estado != EstadoRegistro.terminado && r.estado != EstadoRegistro.archivado)
          .toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
      if (pendientes.isEmpty) continue;
      resultado.add((elemento: elemento, registroTitulo: pendientes.first.titulo, fecha: pendientes.first.fecha));
    }
    resultado.sort((a, b) => a.fecha.compareTo(b.fecha));
    return resultado;
  }
}
