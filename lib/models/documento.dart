// lib/models/documento.dart
//
// Un documento nunca es solo "factura.pdf" (sección 22 del spec): siempre
// puede colgar de una casa, un elemento, un evento o un trabajo. El estado
// de IA distingue "hemos clasificado esto automáticamente y falta que el
// propietario lo confirme" de "el propietario ya lo confirmó" -- nunca se da
// por buena una clasificación de la IA sin paso de confirmación explícito.
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoDocumento { factura, presupuesto, garantia, manual, contrato, otro }

TipoDocumento tipoDocumentoFromString(String? s) => TipoDocumento.values.firstWhere(
      (t) => t.name == s,
      orElse: () => TipoDocumento.otro,
    );

/// pendiente: guardado como borrador, sin revisar ni volcar al historial.
/// sugerido: la IA propuso datos pero el usuario aún no los confirmó (no
/// debería persistir así -- se usa solo en memoria, ver SugerenciaIA).
/// confirmado: el usuario revisó y confirmó los datos (venían de IA o no).
/// manual: el usuario lo rellenó a mano sin pasar por la IA.
enum EstadoIA { pendiente, sugerido, confirmado, manual }

EstadoIA estadoIAFromString(String? s) => EstadoIA.values.firstWhere(
      (t) => t.name == s,
      orElse: () => EstadoIA.manual,
    );

class Documento {
  const Documento({
    required this.id,
    required this.url,
    required this.nombreArchivo,
    required this.tipo,
    this.fecha,
    this.proveedor,
    this.importe,
    this.numeroReferencia,
    this.fechaVencimiento,
    this.nifCif,
    this.baseImponible,
    this.impuestos,
    this.moneda,
    this.descripcionTrabajo,
    this.garantiaTexto,
    this.observaciones,
    this.archivosAdicionales = const [],
    this.elementoId,
    this.eventoId,
    this.trabajoId,
    this.habitacionId,
    this.estadoIA = EstadoIA.manual,
    this.creadoPorIA = false,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String url;
  final String nombreArchivo;
  final TipoDocumento tipo;
  final DateTime? fecha;
  final String? proveedor;
  final double? importe;
  final String? numeroReferencia;
  final DateTime? fechaVencimiento;
  final String? nifCif;
  final double? baseImponible;
  final double? impuestos;
  final String? moneda;
  final String? descripcionTrabajo;
  final String? garantiaTexto;
  final String? observaciones;
  // Páginas adicionales de un mismo documento (fotos o archivos) -- la
  // primera página es [url]/[nombreArchivo], el resto son estas URLs.
  final List<String> archivosAdicionales;
  final String? elementoId;
  final String? eventoId;
  final String? trabajoId;
  final String? habitacionId;
  final EstadoIA estadoIA;
  final bool creadoPorIA;
  final DateTime? createdAt;
  final String? createdBy;

  factory Documento.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Documento(
      id: doc.id,
      url: data['url'] as String? ?? '',
      nombreArchivo: data['nombreArchivo'] as String? ?? '',
      tipo: tipoDocumentoFromString(data['tipo'] as String?),
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      proveedor: data['proveedor'] as String?,
      importe: (data['importe'] as num?)?.toDouble(),
      numeroReferencia: data['numeroReferencia'] as String?,
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
      nifCif: data['nifCif'] as String?,
      baseImponible: (data['baseImponible'] as num?)?.toDouble(),
      impuestos: (data['impuestos'] as num?)?.toDouble(),
      moneda: data['moneda'] as String?,
      descripcionTrabajo: data['descripcionTrabajo'] as String?,
      garantiaTexto: data['garantiaTexto'] as String?,
      observaciones: data['observaciones'] as String?,
      archivosAdicionales: List<String>.from(data['archivosAdicionales'] as List? ?? []),
      elementoId: data['elementoId'] as String?,
      eventoId: data['eventoId'] as String?,
      trabajoId: data['trabajoId'] as String?,
      habitacionId: data['habitacionId'] as String?,
      estadoIA: estadoIAFromString(data['estadoIA'] as String?),
      creadoPorIA: data['creadoPorIA'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        'nombreArchivo': nombreArchivo,
        'tipo': tipo.name,
        if (fecha != null) 'fecha': Timestamp.fromDate(fecha!),
        if (proveedor != null) 'proveedor': proveedor,
        if (importe != null) 'importe': importe,
        if (numeroReferencia != null) 'numeroReferencia': numeroReferencia,
        if (fechaVencimiento != null) 'fechaVencimiento': Timestamp.fromDate(fechaVencimiento!),
        if (nifCif != null) 'nifCif': nifCif,
        if (baseImponible != null) 'baseImponible': baseImponible,
        if (impuestos != null) 'impuestos': impuestos,
        if (moneda != null) 'moneda': moneda,
        if (descripcionTrabajo != null) 'descripcionTrabajo': descripcionTrabajo,
        if (garantiaTexto != null) 'garantiaTexto': garantiaTexto,
        if (observaciones != null) 'observaciones': observaciones,
        'archivosAdicionales': archivosAdicionales,
        if (elementoId != null) 'elementoId': elementoId,
        if (eventoId != null) 'eventoId': eventoId,
        if (trabajoId != null) 'trabajoId': trabajoId,
        if (habitacionId != null) 'habitacionId': habitacionId,
        'estadoIA': estadoIA.name,
        'creadoPorIA': creadoPorIA,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
