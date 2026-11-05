// lib/models/cambio_alcance.dart
//
// ScopeGuard (sección 19-21 del spec): cuando el profesional detecta algo no
// contemplado en el presupuesto original, lo registra aquí en vez de
// cambiarlo por su cuenta. El propietario aprueba o rechaza -- nunca el
// propio profesional (impuesto también en la Cloud Function
// responderCambioAlcance, no solo en la UI).
import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoCambioAlcance { pendiente, aprobado, rechazado, cancelado }

EstadoCambioAlcance estadoCambioAlcanceFromString(String? s) => EstadoCambioAlcance.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EstadoCambioAlcance.pendiente,
    );

class CambioAlcance {
  const CambioAlcance({
    required this.id,
    required this.titulo,
    required this.estado,
    this.descripcion,
    this.motivo,
    this.fotos = const [],
    this.importeAdicional,
    this.tiempoAdicionalHoras,
    this.presupuestoId,
    this.creadoPorUid,
    this.aprobadoPorUid,
    this.rechazadoPorUid,
    this.createdAt,
  });

  final String id;
  final String titulo;
  final EstadoCambioAlcance estado;
  final String? descripcion;
  final String? motivo;
  final List<String> fotos;
  final double? importeAdicional;
  final double? tiempoAdicionalHoras;
  final String? presupuestoId;
  final String? creadoPorUid;
  final String? aprobadoPorUid;
  final String? rechazadoPorUid;
  final DateTime? createdAt;

  factory CambioAlcance.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CambioAlcance(
      id: doc.id,
      titulo: data['titulo'] as String? ?? '',
      estado: estadoCambioAlcanceFromString(data['estado'] as String?),
      descripcion: data['descripcion'] as String?,
      motivo: data['motivo'] as String?,
      fotos: List<String>.from(data['fotos'] as List? ?? []),
      importeAdicional: (data['importeAdicional'] as num?)?.toDouble(),
      tiempoAdicionalHoras: (data['tiempoAdicionalHoras'] as num?)?.toDouble(),
      presupuestoId: data['presupuestoId'] as String?,
      creadoPorUid: data['creadoPorUid'] as String?,
      aprobadoPorUid: data['aprobadoPorUid'] as String?,
      rechazadoPorUid: data['rechazadoPorUid'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
