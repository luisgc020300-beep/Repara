// lib/models/registro.dart
//
// Un registro es cada suceso de un Elemento (octubre 2026, fusión de lo que
// antes eran Trabajo y Evento por separado): desde "compré una freidora"
// (registro simple, sin profesional) hasta "me cambiaron la depuradora de
// la piscina" (con presupuesto, pagos, invitación de profesional y modelo
// de dos pasos). [esConProfesional] es lo que decide, al crearlo, cuál de
// los dos flujos se activa -- no se deriva solo de [tipo], porque una
// "reparación" puede ser tanto DIY como contratada.
//
// El profesional puede ser solo texto libre (nombre/contacto, sin cuenta --
// cumple el principio de "no obligar a un marketplace") o, si se invita a
// una cuenta profesional real de Repara y acepta (ver InvitacionService),
// quedar vinculado por [profesionalUid]. Cuando hay [profesionalUid], ese
// profesional puede leer ESTE registro (nunca el Elemento padre) y
// actualizar su estado aunque no sea miembro de la casa (ver
// firestore.rules) -- por eso [elementoNombre] va denormalizado aquí: el
// lado Pro nunca necesita permiso de lectura sobre el elemento en sí.
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoRegistro { compra, averia, reparacion, mantenimiento, instalacion, reforma, sustitucion, nota }

TipoRegistro tipoRegistroFromString(String? s) => TipoRegistro.values.firstWhere(
      (t) => t.name == s,
      orElse: () => TipoRegistro.nota,
    );

String nombreTipoRegistro(TipoRegistro t) => switch (t) {
      TipoRegistro.compra => 'Compra',
      TipoRegistro.averia => 'Avería',
      TipoRegistro.reparacion => 'Reparación',
      TipoRegistro.mantenimiento => 'Mantenimiento',
      TipoRegistro.instalacion => 'Instalación',
      TipoRegistro.reforma => 'Reforma/Mejora',
      TipoRegistro.sustitucion => 'Sustitución',
      TipoRegistro.nota => 'Nota',
    };

// pendienteConfirmacion: el profesional dice que ha terminado, pero el
// propietario todavía no lo ha confirmado ni rechazado -- modelo de dos
// pasos (auditoría de producto, octubre 2026) en vez de que cualquiera de
// las dos partes pueda cerrar el registro unilateralmente sin que la otra
// esté de acuerdo. Solo aplica cuando esConProfesional es true -- un
// registro simple nace directamente "terminado".
enum EstadoRegistro { nuevo, presupuestado, enCurso, pendienteConfirmacion, terminado, archivado }

EstadoRegistro estadoRegistroFromString(String? s) => EstadoRegistro.values.firstWhere(
      (t) => t.name == s,
      orElse: () => EstadoRegistro.nuevo,
    );

class Registro {
  const Registro({
    required this.id,
    required this.elementoNombre,
    required this.tipo,
    required this.esConProfesional,
    required this.titulo,
    required this.estado,
    required this.fecha,
    this.descripcion,
    this.garantiaHasta,
    this.coste,
    this.fotoUrl,
    this.documentoIds = const [],
    this.profesionalNombre,
    this.profesionalContacto,
    this.profesionalUid,
    this.presupuesto,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String elementoNombre;
  final TipoRegistro tipo;
  final bool esConProfesional;
  final String titulo;
  final EstadoRegistro estado;
  final DateTime fecha;
  final String? descripcion;
  final DateTime? garantiaHasta;
  final double? coste;
  final String? fotoUrl;
  final List<String> documentoIds;
  final String? profesionalNombre;
  final String? profesionalContacto;
  final String? profesionalUid;
  final double? presupuesto;
  final DateTime? createdAt;
  final String? createdBy;

  factory Registro.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Registro(
      id: doc.id,
      elementoNombre: data['elementoNombre'] as String? ?? '',
      tipo: tipoRegistroFromString(data['tipo'] as String?),
      esConProfesional: data['esConProfesional'] as bool? ?? false,
      titulo: data['titulo'] as String? ?? '',
      estado: estadoRegistroFromString(data['estado'] as String?),
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      descripcion: data['descripcion'] as String?,
      garantiaHasta: (data['garantiaHasta'] as Timestamp?)?.toDate(),
      coste: (data['coste'] as num?)?.toDouble(),
      fotoUrl: data['fotoUrl'] as String?,
      documentoIds: List<String>.from(data['documentoIds'] as List? ?? []),
      profesionalNombre: data['profesionalNombre'] as String?,
      profesionalContacto: data['profesionalContacto'] as String?,
      profesionalUid: data['profesionalUid'] as String?,
      presupuesto: (data['presupuesto'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'elementoNombre': elementoNombre,
        'tipo': tipo.name,
        'esConProfesional': esConProfesional,
        'titulo': titulo,
        'estado': estado.name,
        'fecha': Timestamp.fromDate(fecha),
        if (descripcion != null) 'descripcion': descripcion,
        if (garantiaHasta != null) 'garantiaHasta': Timestamp.fromDate(garantiaHasta!),
        if (coste != null) 'coste': coste,
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        'documentoIds': documentoIds,
        if (profesionalNombre != null) 'profesionalNombre': profesionalNombre,
        if (profesionalContacto != null) 'profesionalContacto': profesionalContacto,
        if (profesionalUid != null) 'profesionalUid': profesionalUid,
        if (presupuesto != null) 'presupuesto': presupuesto,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
