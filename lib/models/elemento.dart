// lib/models/elemento.dart
//
// La entidad central de Repara (ver CLAUDE de producto): cada aparato o
// instalación importante de la casa tiene su propia identidad digital, con
// marca/modelo/coste/garantía y un historial de eventos propio. No es un
// campo dentro de "trabajo" -- es al revés, un trabajo puede referenciar un
// elemento.
import 'package:cloud_firestore/cloud_firestore.dart';

class Elemento {
  const Elemento({
    required this.id,
    required this.nombre,
    this.habitacionId,
    this.marca,
    this.modelo,
    this.fechaInstalacion,
    this.coste,
    this.profesionalNombre,
    this.garantiaHasta,
    this.fotoUrl,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final String? habitacionId;
  final String? marca;
  final String? modelo;
  final DateTime? fechaInstalacion;
  final double? coste;
  final String? profesionalNombre;
  final DateTime? garantiaHasta;
  final String? fotoUrl;
  final DateTime? createdAt;

  bool get garantiaProximaAVencer {
    if (garantiaHasta == null) return false;
    final dias = garantiaHasta!.difference(DateTime.now()).inDays;
    return dias >= 0 && dias <= 30;
  }

  factory Elemento.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Elemento(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      habitacionId: data['habitacionId'] as String?,
      marca: data['marca'] as String?,
      modelo: data['modelo'] as String?,
      fechaInstalacion: (data['fechaInstalacion'] as Timestamp?)?.toDate(),
      coste: (data['coste'] as num?)?.toDouble(),
      profesionalNombre: data['profesionalNombre'] as String?,
      garantiaHasta: (data['garantiaHasta'] as Timestamp?)?.toDate(),
      fotoUrl: data['fotoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        if (habitacionId != null) 'habitacionId': habitacionId,
        if (marca != null) 'marca': marca,
        if (modelo != null) 'modelo': modelo,
        if (fechaInstalacion != null) 'fechaInstalacion': Timestamp.fromDate(fechaInstalacion!),
        if (coste != null) 'coste': coste,
        if (profesionalNombre != null) 'profesionalNombre': profesionalNombre,
        if (garantiaHasta != null) 'garantiaHasta': Timestamp.fromDate(garantiaHasta!),
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
      };
}
