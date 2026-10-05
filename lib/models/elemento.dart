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
    this.intervaloMantenimientoMeses,
    this.proximoMantenimiento,
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
  // Calendario de mantenimiento autogenerado (idea para diferenciarse de
  // Dwellin): la IA sugiere este intervalo al crear el elemento según su
  // tipo, pero es libremente editable y puede dejarse en blanco -- nunca es
  // una obligación. [proximoMantenimiento] avanza [intervaloMantenimientoMeses]
  // meses cada vez que se marca una revisión como hecha.
  final int? intervaloMantenimientoMeses;
  final DateTime? proximoMantenimiento;
  final DateTime? createdAt;

  bool get garantiaProximaAVencer {
    if (garantiaHasta == null) return false;
    final dias = garantiaHasta!.difference(DateTime.now()).inDays;
    return dias >= 0 && dias <= 30;
  }

  /// true tanto si la revisión está próxima (<=30 días) como si ya está
  /// atrasada (días negativos) -- a diferencia de la garantía, una revisión
  /// atrasada sigue siendo algo accionable, no un dato ya cerrado.
  bool get revisionPendiente {
    if (proximoMantenimiento == null) return false;
    return proximoMantenimiento!.difference(DateTime.now()).inDays <= 30;
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
      intervaloMantenimientoMeses: (data['intervaloMantenimientoMeses'] as num?)?.toInt(),
      proximoMantenimiento: (data['proximoMantenimiento'] as Timestamp?)?.toDate(),
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
        if (intervaloMantenimientoMeses != null) 'intervaloMantenimientoMeses': intervaloMantenimientoMeses,
        if (proximoMantenimiento != null) 'proximoMantenimiento': Timestamp.fromDate(proximoMantenimiento!),
      };
}
