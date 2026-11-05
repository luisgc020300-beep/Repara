// lib/models/presupuesto.dart
//
// Presupuesto formal con líneas (sección 15-17 del spec de producto).
// Distinto del campo simple Trabajo.presupuesto, que se mantiene por
// compatibilidad y se sincroniza automáticamente al aceptar uno de estos
// (ver Cloud Function responderPresupuesto). Nunca se sobrescribe
// destructivamente: un presupuesto rechazado se versiona en un documento
// nuevo, nunca se edita en el sitio.
import 'package:cloud_firestore/cloud_firestore.dart';

class LineaPresupuesto {
  const LineaPresupuesto({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.ivaPorcentaje,
  });

  final String descripcion;
  final double cantidad;
  final double precioUnitario;
  final double ivaPorcentaje;

  double get importeSinIva => cantidad * precioUnitario;
  double get importeConIva => importeSinIva * (1 + ivaPorcentaje / 100);

  factory LineaPresupuesto.fromMap(Map<String, dynamic> map) => LineaPresupuesto(
        descripcion: map['descripcion'] as String? ?? '',
        cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
        precioUnitario: (map['precioUnitario'] as num?)?.toDouble() ?? 0,
        ivaPorcentaje: (map['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
      );

  Map<String, dynamic> toMap() => {
        'descripcion': descripcion,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'ivaPorcentaje': ivaPorcentaje,
      };
}

enum EstadoPresupuesto { borrador, enviado, aceptado, rechazado, cancelado }

EstadoPresupuesto estadoPresupuestoFromString(String? s) => EstadoPresupuesto.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EstadoPresupuesto.borrador,
    );

class Presupuesto {
  const Presupuesto({
    required this.id,
    required this.numero,
    required this.version,
    required this.estado,
    required this.lineas,
    required this.subtotal,
    required this.iva,
    required this.total,
    this.notas,
    this.presupuestoAnteriorId,
    this.creadoPorUid,
    this.respondidoPorUid,
    this.fechaCreacion,
    this.fechaEnvio,
    this.fechaRespuesta,
  });

  final String id;
  final int numero;
  final int version;
  final EstadoPresupuesto estado;
  final List<LineaPresupuesto> lineas;
  final double subtotal;
  final double iva;
  final double total;
  final String? notas;
  final String? presupuestoAnteriorId;
  final String? creadoPorUid;
  final String? respondidoPorUid;
  final DateTime? fechaCreacion;
  final DateTime? fechaEnvio;
  final DateTime? fechaRespuesta;

  factory Presupuesto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Presupuesto(
      id: doc.id,
      numero: (data['numero'] as num?)?.toInt() ?? 1,
      version: (data['version'] as num?)?.toInt() ?? 1,
      estado: estadoPresupuestoFromString(data['estado'] as String?),
      lineas: ((data['lineas'] as List?) ?? [])
          .map((l) => LineaPresupuesto.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      iva: (data['iva'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      notas: data['notas'] as String?,
      presupuestoAnteriorId: data['presupuestoAnteriorId'] as String?,
      creadoPorUid: data['creadoPorUid'] as String?,
      respondidoPorUid: data['respondidoPorUid'] as String?,
      fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate(),
      fechaEnvio: (data['fechaEnvio'] as Timestamp?)?.toDate(),
      fechaRespuesta: (data['fechaRespuesta'] as Timestamp?)?.toDate(),
    );
  }
}
