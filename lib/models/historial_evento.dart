// lib/models/historial_evento.dart
//
// Lado de lectura del historial append-only que ya escriben las Cloud
// Functions en casas/{cid}/elementos/{eid}/registros/{rid}/historial (ver
// registrarHistorial en functions/index.js) -- hasta ahora nada en Flutter
// lo leía. Nunca se escribe desde el cliente (firestore.rules: `allow write:
// if false`), así que este modelo es de solo lectura por diseño.
import 'package:cloud_firestore/cloud_firestore.dart';

enum EntidadHistorial { presupuesto, cambioAlcance, pago, desconocida }

EntidadHistorial entidadHistorialFromString(String? s) => switch (s) {
  'presupuesto' => EntidadHistorial.presupuesto,
  'cambioAlcance' => EntidadHistorial.cambioAlcance,
  'pago' => EntidadHistorial.pago,
  _ => EntidadHistorial.desconocida,
};

class HistorialEvento {
  const HistorialEvento({
    required this.id,
    required this.entidad,
    required this.accion,
    this.entidadId,
    this.actorUid,
    this.estadoAnterior,
    this.estadoNuevo,
    this.importe,
    this.version,
    this.motivo,
    this.timestamp,
  });

  final String id;
  final EntidadHistorial entidad;
  final String accion;
  final String? entidadId;
  final String? actorUid;
  final String? estadoAnterior;
  final String? estadoNuevo;
  final double? importe;
  final int? version;
  final String? motivo;
  final DateTime? timestamp;

  factory HistorialEvento.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HistorialEvento(
      id: doc.id,
      entidad: entidadHistorialFromString(data['entidad'] as String?),
      accion: data['accion'] as String? ?? '',
      entidadId: data['entidadId'] as String?,
      actorUid: data['actorUid'] as String?,
      estadoAnterior: data['estadoAnterior'] as String?,
      estadoNuevo: data['estadoNuevo'] as String?,
      importe: (data['importe'] as num?)?.toDouble(),
      version: (data['version'] as num?)?.toInt(),
      motivo: data['motivo'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
