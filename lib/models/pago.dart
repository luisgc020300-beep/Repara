// lib/models/pago.dart
//
// Un pago concreto hecho por el propietario para un trabajo -- idea del CEO:
// "no solo importa que ya te hayan reparado algo, también importa el
// haberlo pagado del todo". El propietario es quien crea/edita/borra estos
// registros; el profesional asignado a ese trabajo solo los lee, con todo
// el detalle, sin poder tocarlos (ver firestore.rules). El precio de
// referencia contra el que se compara la suma de todos los pagos sigue
// siendo [Trabajo.presupuesto], venga de donde venga ese precio.
import 'package:cloud_firestore/cloud_firestore.dart';

enum MetodoPago { bizum, transferencia, efectivo, tarjeta, otro }

MetodoPago? metodoPagoFromString(String? s) {
  if (s == null) return null;
  return MetodoPago.values.firstWhere((m) => m.name == s, orElse: () => MetodoPago.otro);
}

class Pago {
  const Pago({
    required this.id,
    required this.fecha,
    required this.importe,
    this.concepto,
    this.descripcion,
    this.metodo,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final DateTime fecha;
  final double importe;
  final String? concepto;
  final String? descripcion;
  final MetodoPago? metodo;
  final DateTime? createdAt;
  final String? createdBy;

  factory Pago.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Pago(
      id: doc.id,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      importe: (data['importe'] as num?)?.toDouble() ?? 0,
      concepto: data['concepto'] as String?,
      descripcion: data['descripcion'] as String?,
      metodo: metodoPagoFromString(data['metodo'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'fecha': Timestamp.fromDate(fecha),
        'importe': importe,
        if (concepto != null) 'concepto': concepto,
        if (descripcion != null) 'descripcion': descripcion,
        if (metodo != null) 'metodo': metodo!.name,
      };
}
