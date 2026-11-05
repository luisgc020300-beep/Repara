// lib/models/profesional.dart
//
// Perfil profesional (sección 17 del spec): datos de trabajo, no un
// marketplace -- no incluye disponibilidad ni valoraciones en v1. Vive en su
// propia colección top-level con el mismo id que el usuario, para no
// duplicar la cuenta ni mezclarse con los datos de propietario.
import 'package:cloud_firestore/cloud_firestore.dart';

class Profesional {
  const Profesional({
    required this.uid,
    this.nombreComercial,
    this.especialidad,
    this.telefono,
    this.createdAt,
  });

  final String uid;
  final String? nombreComercial;
  final String? especialidad;
  final String? telefono;
  final DateTime? createdAt;

  factory Profesional.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Profesional(
      uid: doc.id,
      nombreComercial: data['nombreComercial'] as String?,
      especialidad: data['especialidad'] as String?,
      telefono: data['telefono'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Un registro aceptado por un profesional -- copia ligera guardada en
/// users/{uid}.registrosProRefs, suficiente para listar "Trabajos"/"Clientes"
/// sin que el profesional necesite permiso de lectura sobre la casa entera
/// ni sobre el elemento padre (ver Registro.elementoNombre).
class RegistroProRef {
  const RegistroProRef({
    required this.casaId,
    required this.elementoId,
    required this.elementoNombre,
    required this.registroId,
    required this.registroTitulo,
    required this.casaNombre,
    this.fotoUrl,
  });

  final String casaId;
  final String elementoId;
  final String elementoNombre;
  final String registroId;
  final String registroTitulo;
  final String casaNombre;

  /// Foto del registro, o si no tiene, la del elemento -- ya resuelta en
  /// servidor al aceptar la invitación (ver invitarProfesional/
  /// responderInvitacion en functions/index.js). Null en trabajos aceptados
  /// antes de que existiera este campo.
  final String? fotoUrl;

  factory RegistroProRef.fromMap(Map<String, dynamic> map) => RegistroProRef(
    casaId: map['casaId'] as String? ?? '',
    elementoId: map['elementoId'] as String? ?? '',
    elementoNombre: map['elementoNombre'] as String? ?? '',
    registroId: map['registroId'] as String? ?? '',
    registroTitulo: map['registroTitulo'] as String? ?? '',
    casaNombre: map['casaNombre'] as String? ?? '',
    fotoUrl: map['fotoUrl'] as String?,
  );
}
