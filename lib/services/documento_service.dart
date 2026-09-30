// lib/services/documento_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/documento.dart';

class SugerenciaIA {
  const SugerenciaIA({
    required this.tipo,
    this.fecha,
    this.fechaVencimiento,
    this.proveedor,
    this.nifCif,
    this.numeroReferencia,
    this.importe,
    this.baseImponible,
    this.impuestos,
    this.moneda,
    this.descripcionTrabajo,
    this.garantiaTexto,
    this.observaciones,
    this.elementoSugerido,
    this.trabajoSugerido,
    this.confianza,
  });

  final TipoDocumento tipo;
  final DateTime? fecha;
  final DateTime? fechaVencimiento;
  final String? proveedor;
  final String? nifCif;
  final String? numeroReferencia;
  final double? importe;
  final double? baseImponible;
  final double? impuestos;
  final String? moneda;
  final String? descripcionTrabajo;
  final String? garantiaTexto;
  final String? observaciones;
  final String? elementoSugerido;
  final String? trabajoSugerido;
  final String? confianza;

  factory SugerenciaIA.fromMap(Map<String, dynamic> map) {
    DateTime? parseFecha(String? s) => s == null ? null : DateTime.tryParse(s);
    return SugerenciaIA(
      tipo: tipoDocumentoFromString(map['tipo'] as String?),
      fecha: parseFecha(map['fecha'] as String?),
      fechaVencimiento: parseFecha(map['fechaVencimiento'] as String?),
      proveedor: map['proveedor'] as String?,
      nifCif: map['nifCif'] as String?,
      numeroReferencia: map['numeroReferencia'] as String?,
      importe: (map['importe'] as num?)?.toDouble(),
      baseImponible: (map['baseImponible'] as num?)?.toDouble(),
      impuestos: (map['impuestos'] as num?)?.toDouble(),
      moneda: map['moneda'] as String?,
      descripcionTrabajo: map['descripcionTrabajo'] as String?,
      garantiaTexto: map['garantiaTexto'] as String?,
      observaciones: map['observaciones'] as String?,
      elementoSugerido: map['elementoSugerido'] as String?,
      trabajoSugerido: map['trabajoSugerido'] as String?,
      confianza: map['confianza'] as String?,
    );
  }
}

class PaginaDocumento {
  const PaginaDocumento({required this.archivo, required this.mediaType, required this.nombre});
  final File archivo;
  final String mediaType;
  final String nombre;
}

class DocumentoService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('documentos');

  static Stream<List<Documento>> streamDocumentos(
    String casaId, {
    String? elementoId,
    String? trabajoId,
  }) {
    Query<Map<String, dynamic>> q = _col(casaId).orderBy('createdAt', descending: true);
    if (elementoId != null) q = q.where('elementoId', isEqualTo: elementoId);
    if (trabajoId != null) q = q.where('trabajoId', isEqualTo: trabajoId);
    return q.snapshots().map((s) => s.docs.map(Documento.fromDoc).toList());
  }

  /// Todos los documentos de la casa -- incluye los borradores sin elemento
  /// ni trabajo asociado (sección 2 del spec: "sección de documentos").
  static Stream<List<Documento>> streamTodos(String casaId) {
    return _col(casaId).orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map(Documento.fromDoc).toList());
  }

  static Future<String> subirArchivo(String casaId, File archivo, String nombreArchivo) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('casas/$casaId/documentos/${DateTime.now().millisecondsSinceEpoch}_$nombreArchivo');
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }

  /// Pide a la IA una sugerencia a partir de las páginas del propio
  /// documento (no del archivo ya subido) -- así funciona igual antes de
  /// decidir si el documento se guarda o se descarta. Varias páginas se
  /// tratan como el mismo documento (sección 3 del spec).
  static Future<SugerenciaIA?> clasificarConIA(
    List<PaginaDocumento> paginas, {
    List<String> elementosDisponibles = const [],
    List<String> trabajosDisponibles = const [],
  }) async {
    final paginasCodificadas = await Future.wait(paginas.map((p) async {
      final bytes = await p.archivo.readAsBytes();
      return {'data': base64Encode(bytes), 'mediaType': p.mediaType};
    }));
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('classifyDocument');
    final result = await callable.call<Map<String, dynamic>>({
      'paginas': paginasCodificadas,
      'elementosDisponibles': elementosDisponibles,
      'trabajosDisponibles': trabajosDisponibles,
    });
    final sugerencia = result.data['sugerencia'] as Map<String, dynamic>?;
    if (sugerencia == null) return null;
    return SugerenciaIA.fromMap(sugerencia);
  }

  static Future<String> crear(String casaId, Documento documento, {required String createdBy}) async {
    final ref = await _col(casaId).add({...documento.toMap(), 'createdBy': createdBy});
    return ref.id;
  }

  static Future<void> confirmar(String casaId, String documentoId) async {
    await _col(casaId).doc(documentoId).update({'estadoIA': EstadoIA.confirmado.name});
  }

  static Future<void> eliminar(String casaId, String documentoId) async {
    await _col(casaId).doc(documentoId).delete();
  }

  /// Heurística simple de duplicado (sección 10 del spec): mismo proveedor,
  /// mismo importe (±1 céntimo) y misma fecha exacta. No es infalible --
  /// solo evita el caso más común de volver a escanear la misma factura sin
  /// darse cuenta, no sustituye un sistema de deduplicación real.
  static Future<bool> posibleDuplicado(
    String casaId, {
    required String? proveedor,
    required double? importe,
    required DateTime? fecha,
  }) async {
    if (proveedor == null || importe == null || fecha == null) return false;
    final snap = await _col(casaId).where('proveedor', isEqualTo: proveedor).get();
    return snap.docs.any((doc) {
      final d = Documento.fromDoc(doc);
      if (d.importe == null || d.fecha == null) return false;
      final mismaFecha = d.fecha!.year == fecha.year && d.fecha!.month == fecha.month && d.fecha!.day == fecha.day;
      return mismaFecha && (d.importe! - importe).abs() < 0.01;
    });
  }
}
