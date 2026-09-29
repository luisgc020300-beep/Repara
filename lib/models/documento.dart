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
    this.elementoId,
    this.eventoId,
    this.trabajoId,
    this.estadoIA = EstadoIA.manual,
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
  final String? elementoId;
  final String? eventoId;
  final String? trabajoId;
  final EstadoIA estadoIA;
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
      elementoId: data['elementoId'] as String?,
      eventoId: data['eventoId'] as String?,
      trabajoId: data['trabajoId'] as String?,
      estadoIA: estadoIAFromString(data['estadoIA'] as String?),
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
        if (elementoId != null) 'elementoId': elementoId,
        if (eventoId != null) 'eventoId': eventoId,
        if (trabajoId != null) 'trabajoId': trabajoId,
        'estadoIA': estadoIA.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
