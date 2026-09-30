// lib/models/invitacion.dart
//
// Puente entre un trabajo de una casa y un profesional que ya tiene cuenta
// en Repara (sección 15 del spec, simplificado: solo por email de una
// cuenta existente, sin enlace público -- ver decisión del CEO). El
// profesional debe aceptar explícitamente antes de quedar vinculado al
// trabajo; hasta entonces no puede leer nada de esa casa.
import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoInvitacion { pendiente, aceptada, rechazada }

EstadoInvitacion estadoInvitacionFromString(String? s) => EstadoInvitacion.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EstadoInvitacion.pendiente,
    );

class Invitacion {
  const Invitacion({
    required this.id,
    required this.casaId,
    required this.trabajoId,
    required this.trabajoTitulo,
    required this.casaNombre,
    required this.propietarioUid,
    required this.profesionalUid,
    required this.profesionalEmail,
    required this.estado,
    this.createdAt,
  });

  final String id;
  final String casaId;
  final String trabajoId;
  final String trabajoTitulo;
  final String casaNombre;
  final String propietarioUid;
  final String profesionalUid;
  final String profesionalEmail;
  final EstadoInvitacion estado;
  final DateTime? createdAt;

  factory Invitacion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Invitacion(
      id: doc.id,
      casaId: data['casaId'] as String? ?? '',
      trabajoId: data['trabajoId'] as String? ?? '',
      trabajoTitulo: data['trabajoTitulo'] as String? ?? '',
      casaNombre: data['casaNombre'] as String? ?? '',
      propietarioUid: data['propietarioUid'] as String? ?? '',
      profesionalUid: data['profesionalUid'] as String? ?? '',
      profesionalEmail: data['profesionalEmail'] as String? ?? '',
      estado: estadoInvitacionFromString(data['estado'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
