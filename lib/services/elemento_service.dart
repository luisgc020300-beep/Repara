// lib/services/elemento_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/elemento.dart';
import 'stream_error_logging.dart';

class ElementoService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('elementos');

  static Stream<List<Elemento>> streamElementos(String casaId, {String? habitacionId}) {
    Query<Map<String, dynamic>> q = _col(casaId);
    if (habitacionId != null) q = q.where('habitacionId', isEqualTo: habitacionId);
    return q.snapshots().map((s) => s.docs.map(Elemento.fromDoc).toList()).conRegistroDeErrores();
  }

  static Stream<Elemento?> streamElemento(String casaId, String elementoId) {
    return _col(casaId)
        .doc(elementoId)
        .snapshots()
        .map((d) => d.exists ? Elemento.fromDoc(d) : null)
        .conRegistroDeErrores();
  }

  static Future<String> crear(String casaId, Elemento elemento) async {
    final ref = await _col(casaId).add({
      ...elemento.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// A diferencia de [crear] (que usa toMap(), omitiendo las claves nulas --
  /// perfecto para un documento nuevo), aquí hay que escribir explícitamente
  /// null en cada campo editable para que vaciar un campo en el formulario
  /// (p.ej. borrar un typo en "Marca") de verdad lo borre en Firestore --
  /// `.update()` nunca toca una clave que no se le pase (auditoría de
  /// producto, octubre 2026). `fotoUrl` queda fuera a propósito: ningún
  /// formulario lo edita todavía, así que nunca debe tocarse aquí.
  static Future<void> actualizar(String casaId, String elementoId, Elemento elemento) async {
    await _col(casaId).doc(elementoId).update({
      'nombre': elemento.nombre,
      'habitacionId': elemento.habitacionId,
      'marca': elemento.marca,
      'modelo': elemento.modelo,
      'fechaInstalacion': elemento.fechaInstalacion != null ? Timestamp.fromDate(elemento.fechaInstalacion!) : null,
      'coste': elemento.coste,
      'profesionalNombre': elemento.profesionalNombre,
      'garantiaHasta': elemento.garantiaHasta != null ? Timestamp.fromDate(elemento.garantiaHasta!) : null,
      'intervaloMantenimientoMeses': elemento.intervaloMantenimientoMeses,
      'proximoMantenimiento': elemento.proximoMantenimiento != null ? Timestamp.fromDate(elemento.proximoMantenimiento!) : null,
    });
  }

  static Future<void> eliminar(String casaId, String elementoId) async {
    await _col(casaId).doc(elementoId).delete();
  }

  /// Elementos con garantía a menos de 30 días -- usado en el dashboard de
  /// Inicio (sección 25 del spec: avisar de garantías próximas a vencer).
  static Future<List<Elemento>> conGarantiaProximaAVencer(String casaId) async {
    final snap = await _col(casaId).get();
    return snap.docs.map(Elemento.fromDoc).where((e) => e.garantiaProximaAVencer).toList();
  }

  /// Elementos con revisión periódica próxima o ya atrasada -- calendario
  /// de mantenimiento autogenerado, mismo dashboard de Inicio.
  static Future<List<Elemento>> conRevisionPendiente(String casaId) async {
    final snap = await _col(casaId).get();
    return snap.docs.map(Elemento.fromDoc).where((e) => e.revisionPendiente).toList();
  }

  /// TODOS los elementos con una fecha de garantía guardada, pendiente o no
  /// -- el aviso de Inicio solo enseña lo urgente (<=30 días), pero "encontrar
  /// una garantía" (auditoría de producto, octubre 2026) necesita poder
  /// consultar también las que vencen más adelante, no solo las que aprietan.
  static Future<List<Elemento>> conGarantia(String casaId) async {
    final snap = await _col(casaId).get();
    final elementos = snap.docs.map(Elemento.fromDoc).where((e) => e.garantiaHasta != null).toList();
    elementos.sort((a, b) => a.garantiaHasta!.compareTo(b.garantiaHasta!));
    return elementos;
  }

  /// TODOS los elementos con un calendario de mantenimiento configurado,
  /// pendiente o no -- mismo motivo que [conGarantia]: "ver qué mantenimiento
  /// está pendiente" no debe depender de que ya esté a punto de vencer.
  static Future<List<Elemento>> conMantenimientoConfigurado(String casaId) async {
    final snap = await _col(casaId).get();
    final elementos = snap.docs.map(Elemento.fromDoc).where((e) => e.proximoMantenimiento != null).toList();
    elementos.sort((a, b) => a.proximoMantenimiento!.compareTo(b.proximoMantenimiento!));
    return elementos;
  }

  /// Avanza la próxima revisión [intervaloMeses] meses desde HOY (no desde
  /// la fecha antigua) -- si estaba muy atrasada, no tiene sentido arrastrar
  /// ese retraso para siempre.
  static Future<void> marcarRevisionHecha(String casaId, String elementoId, int intervaloMeses) async {
    final ahora = DateTime.now();
    final proxima = DateTime(ahora.year, ahora.month + intervaloMeses, ahora.day);
    await _col(casaId).doc(elementoId).update({'proximoMantenimiento': Timestamp.fromDate(proxima)});
  }

  /// Edición manual del calendario de mantenimiento -- por si la sugerencia
  /// de la IA no encajaba o el propietario quiere cambiarla más tarde.
  /// Ambos valores pueden ser null para quitar el recordatorio por completo.
  static Future<void> actualizarMantenimiento(
    String casaId,
    String elementoId, {
    required int? intervaloMeses,
    required DateTime? proximoMantenimiento,
  }) async {
    await _col(casaId).doc(elementoId).update({
      'intervaloMantenimientoMeses': intervaloMeses,
      'proximoMantenimiento': proximoMantenimiento != null ? Timestamp.fromDate(proximoMantenimiento) : null,
    });
  }

  /// Pide a la IA un intervalo típico de revisión según el tipo de
  /// elemento -- solo SUGIERE, nunca se guarda sin que el propietario lo
  /// confirme (mismo principio que DocumentoService.clasificarConIA).
  static Future<({int? intervaloMeses, String? motivo})> sugerirIntervaloMantenimiento({
    required String nombre,
    String? marca,
    String? modelo,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('sugerirIntervaloMantenimiento');
    final result = await callable.call<Map<String, dynamic>>({'nombre': nombre, 'marca': marca, 'modelo': modelo});
    return (
      intervaloMeses: (result.data['intervaloMeses'] as num?)?.toInt(),
      motivo: result.data['motivo'] as String?,
    );
  }
}
