// lib/models/invitacion_hogar.dart
//
// Puente entre un TrabajoProfesional privado (CRM del profesional, sin
// ninguna cuenta real detrás) y una cuenta real de REPARA Hogar -- Fase 2,
// noviembre 2026. Dirección inversa de Invitacion (lib/models/
// invitacion.dart): aquí es el PROFESIONAL quien invita, y el PROPIETARIO
// quien acepta/rechaza. Al aceptar, el servidor crea un Elemento+Registro
// reales en la casa del propietario -- ver responderInvitacionHogar en
// functions/index.js.
import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoInvitacionHogar { pendiente, aceptada, rechazada, cancelada }

EstadoInvitacionHogar estadoInvitacionHogarFromString(String? s) =>
    EstadoInvitacionHogar.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EstadoInvitacionHogar.pendiente,
    );

class InvitacionHogar {
  const InvitacionHogar({
    required this.id,
    required this.titulo,
    required this.propietarioUid,
    required this.profesionalUid,
    required this.profesionalNombre,
    required this.estado,
    this.descripcion,
    this.presupuestoEstimado,
    this.createdAt,
  });

  final String id;
  final String titulo;
  final String? descripcion;
  final double? presupuestoEstimado;
  final String propietarioUid;
  final String profesionalUid;
  final String? profesionalNombre;
  final EstadoInvitacionHogar estado;
  final DateTime? createdAt;

  factory InvitacionHogar.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InvitacionHogar(
      id: doc.id,
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      presupuestoEstimado: (data['presupuestoEstimado'] as num?)?.toDouble(),
      propietarioUid: data['propietarioUid'] as String? ?? '',
      profesionalUid: data['profesionalUid'] as String? ?? '',
      profesionalNombre: data['profesionalNombre'] as String?,
      estado: estadoInvitacionHogarFromString(data['estado'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
