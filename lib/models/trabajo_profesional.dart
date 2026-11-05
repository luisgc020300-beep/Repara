// lib/models/trabajo_profesional.dart
//
// Trabajo privado del profesional (Fase 1, noviembre 2026) -- siempre
// ligado a un ClienteProfesional, vive en profesionales/{uid}/trabajosPro.
//
// [vinculo] (Fase 2, noviembre 2026): una vez el propietario acepta la
// invitación de responderInvitacionHogar, este trabajo privado deja de ser
// la fuente de verdad -- [vinculo] apunta al Registro real (dentro de la
// casa del propietario) que a partir de ahí lleva estado/presupuesto/pagos/
// notificaciones/citas de verdad. El documento privado se queda tal cual,
// como referencia de cómo empezó, pero su editor pasa a ser de solo
// lectura (ver trabajo_profesional_sheet.dart).
//
// [estado] es deliberadamente un enum nuevo y simple, NO EstadoRegistro: ese
// modelo asume dos partes que deben confirmarse mutuamente (propietario +
// profesional) -- aquí solo hay una, el propio profesional, así que no tiene
// sentido "pendienteConfirmacion" ni "pendientePago".
//
// [presupuestoEstimado] es un importe simple, sin líneas ni IVA ni Cloud
// Function -- no hay todavía una segunda parte que deba confiar en ese
// cálculo (herramienta interna del propio profesional). El presupuesto
// formal con líneas/IVA protegido por Cloud Function sigue siendo, siempre,
// el que ya existe para trabajos compartidos (ver PresupuestosSection).
import 'package:cloud_firestore/cloud_firestore.dart';

import 'profesional.dart';
import 'registro.dart';

enum EstadoTrabajoProfesional { abierto, enCurso, terminado }

EstadoTrabajoProfesional estadoTrabajoProfesionalFromString(String? s) =>
    EstadoTrabajoProfesional.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EstadoTrabajoProfesional.abierto,
    );

String nombreEstadoTrabajoProfesional(EstadoTrabajoProfesional e) =>
    switch (e) {
      EstadoTrabajoProfesional.abierto => 'Abierto',
      EstadoTrabajoProfesional.enCurso => 'En curso',
      EstadoTrabajoProfesional.terminado => 'Terminado',
    };

class TrabajoProfesional {
  const TrabajoProfesional({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.titulo,
    required this.tipo,
    required this.estado,
    this.descripcion,
    this.presupuestoEstimado,
    this.direccionIntervencion,
    this.fechaProgramada,
    this.createdAt,
    this.updatedAt,
    this.vinculo,
  });

  final String id;
  final String clienteId;

  /// Denormalizado al crearlo -- mismo criterio que RegistroProRef: listar
  /// trabajos nunca debería necesitar leer cada cliente aparte (N+1).
  final String clienteNombre;

  final String titulo;
  final String? descripcion;
  final TipoRegistro tipo;
  final EstadoTrabajoProfesional estado;
  final double? presupuestoEstimado;

  /// Solo si es distinta a la del cliente -- null cuando es la misma.
  final String? direccionIntervencion;
  final DateTime? fechaProgramada;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Solo lo escribe responderInvitacionHogar (Admin SDK) -- ver
  /// functions/index.js. No null a partir de ese momento.
  final RegistroProRef? vinculo;

  bool get estaVinculado => vinculo != null;

  factory TrabajoProfesional.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return TrabajoProfesional(
      id: doc.id,
      clienteId: data['clienteId'] as String? ?? '',
      clienteNombre: data['clienteNombre'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      tipo: tipoRegistroFromString(data['tipo'] as String?),
      estado: estadoTrabajoProfesionalFromString(data['estado'] as String?),
      presupuestoEstimado: (data['presupuestoEstimado'] as num?)?.toDouble(),
      direccionIntervencion: data['direccionIntervencion'] as String?,
      fechaProgramada: (data['fechaProgramada'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      vinculo: data['vinculo'] is Map
          ? RegistroProRef.fromMap(Map<String, dynamic>.from(data['vinculo'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'clienteId': clienteId,
    'clienteNombre': clienteNombre,
    'titulo': titulo,
    if (descripcion != null && descripcion!.isNotEmpty)
      'descripcion': descripcion,
    'tipo': tipo.name,
    'estado': estado.name,
    if (presupuestoEstimado != null)
      'presupuestoEstimado': presupuestoEstimado,
    if (direccionIntervencion != null && direccionIntervencion!.isNotEmpty)
      'direccionIntervencion': direccionIntervencion,
    if (fechaProgramada != null)
      'fechaProgramada': Timestamp.fromDate(fechaProgramada!),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
