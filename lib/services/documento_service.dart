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
    this.proveedor,
    this.importe,
    this.elementoSugerido,
    this.confianza,
  });

  final TipoDocumento tipo;
  final DateTime? fecha;
  final String? proveedor;
  final double? importe;
  final String? elementoSugerido;
  final String? confianza;

  factory SugerenciaIA.fromMap(Map<String, dynamic> map) {
    DateTime? fecha;
    final fechaStr = map['fecha'] as String?;
    if (fechaStr != null) fecha = DateTime.tryParse(fechaStr);
    return SugerenciaIA(
      tipo: tipoDocumentoFromString(map['tipo'] as String?),
      fecha: fecha,
      proveedor: map['proveedor'] as String?,
      importe: (map['importe'] as num?)?.toDouble(),
      elementoSugerido: map['elementoSugerido'] as String?,
      confianza: map['confianza'] as String?,
    );
  }
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

  static Future<String> subirArchivo(String casaId, File archivo, String nombreArchivo) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('casas/$casaId/documentos/${DateTime.now().millisecondsSinceEpoch}_$nombreArchivo');
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }

  /// Pide a la IA una sugerencia de clasificación a partir de la propia
  /// imagen del documento (no del archivo ya subido) -- así funciona igual
  /// antes de decidir si el documento se guarda o se descarta.
  static Future<SugerenciaIA?> clasificarConIA(
    File archivo, {
    required String mediaType,
    List<String> elementosDisponibles = const [],
  }) async {
    final bytes = await archivo.readAsBytes();
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('classifyDocument');
    final result = await callable.call<Map<String, dynamic>>({
      'imageBase64': base64Encode(bytes),
      'mediaType': mediaType,
      'elementosDisponibles': elementosDisponibles,
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
}
