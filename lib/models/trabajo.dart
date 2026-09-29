// lib/models/trabajo.dart
//
// Un trabajo es una intervención puntual (avería, reparación, mantenimiento,
// reforma, instalación) sobre la casa o un elemento concreto. En v1 el
// profesional es texto libre (nombre/contacto), no una cuenta invitada por
// enlace -- ese flujo (sección 15 del spec) es una pieza grande de por sí y
// queda para una fase posterior; aquí ya se cumple el principio de "no
// obligar a un marketplace" porque no hace falta que el profesional tenga
// cuenta para que el trabajo quede registrado.
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoTrabajo { averia, reparacion, mantenimiento, reforma, instalacion, otro }

TipoTrabajo tipoTrabajoFromString(String? s) => TipoTrabajo.values.firstWhere(
      (t) => t.name == s,
      orElse: () => TipoTrabajo.otro,
    );

enum EstadoTrabajo { nuevo, presupuestado, enCurso, terminado, archivado }

EstadoTrabajo estadoTrabajoFromString(String? s) => EstadoTrabajo.values.firstWhere(
      (t) => t.name == s,
      orElse: () => EstadoTrabajo.nuevo,
    );

class Trabajo {
  const Trabajo({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.estado,
    this.descripcion,
    this.habitacionId,
    this.elementoId,
    this.profesionalNombre,
    this.profesionalContacto,
    this.presupuesto,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String titulo;
  final TipoTrabajo tipo;
  final EstadoTrabajo estado;
  final String? descripcion;
  final String? habitacionId;
  final String? elementoId;
  final String? profesionalNombre;
  final String? profesionalContacto;
  final double? presupuesto;
  final DateTime? createdAt;
  final String? createdBy;

  factory Trabajo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Trabajo(
      id: doc.id,
      titulo: data['titulo'] as String? ?? '',
      tipo: tipoTrabajoFromString(data['tipo'] as String?),
      estado: estadoTrabajoFromString(data['estado'] as String?),
      descripcion: data['descripcion'] as String?,
      habitacionId: data['habitacionId'] as String?,
      elementoId: data['elementoId'] as String?,
      profesionalNombre: data['profesionalNombre'] as String?,
      profesionalContacto: data['profesionalContacto'] as String?,
      presupuesto: (data['presupuesto'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'tipo': tipo.name,
        'estado': estado.name,
        if (descripcion != null) 'descripcion': descripcion,
        if (habitacionId != null) 'habitacionId': habitacionId,
        if (elementoId != null) 'elementoId': elementoId,
        if (profesionalNombre != null) 'profesionalNombre': profesionalNombre,
        if (profesionalContacto != null) 'profesionalContacto': profesionalContacto,
        if (presupuesto != null) 'presupuesto': presupuesto,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
