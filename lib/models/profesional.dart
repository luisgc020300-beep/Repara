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

/// Un trabajo aceptado por un profesional -- copia ligera guardada en
/// users/{uid}.trabajosProRefs, suficiente para listar "Trabajos"/"Clientes"
/// sin que el profesional necesite permiso de lectura sobre la casa entera.
class TrabajoProRef {
  const TrabajoProRef({
    required this.casaId,
    required this.trabajoId,
    required this.trabajoTitulo,
    required this.casaNombre,
  });

  final String casaId;
  final String trabajoId;
  final String trabajoTitulo;
  final String casaNombre;

  factory TrabajoProRef.fromMap(Map<String, dynamic> map) => TrabajoProRef(
        casaId: map['casaId'] as String? ?? '',
        trabajoId: map['trabajoId'] as String? ?? '',
        trabajoTitulo: map['trabajoTitulo'] as String? ?? '',
        casaNombre: map['casaNombre'] as String? ?? '',
      );
}
