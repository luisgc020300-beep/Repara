// lib/models/contacto.dart
//
// Libreta privada de profesionales de confianza de ESTA casa (no una
// cuenta de Repara ni un listado público -- ver decisión explícita del
// CEO de no construir un marketplace). El objetivo es que llamar o avisar
// a "tu fontanero de siempre" sea más rápido que buscarlo en la agenda del
// teléfono, no encontrar gente nueva.
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoContacto { particular, empresa }

TipoContacto tipoContactoFromString(String? s) => TipoContacto.values.firstWhere(
      (t) => t.name == s,
      orElse: () => TipoContacto.particular,
    );

class Contacto {
  const Contacto({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.tipo,
    this.especialidad,
    this.notas,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final String telefono;
  final TipoContacto tipo;
  final String? especialidad;
  final String? notas;
  final DateTime? createdAt;

  factory Contacto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Contacto(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      tipo: tipoContactoFromString(data['tipo'] as String?),
      especialidad: data['especialidad'] as String?,
      notas: data['notas'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'telefono': telefono,
        'tipo': tipo.name,
        if (especialidad != null) 'especialidad': especialidad,
        if (notas != null) 'notas': notas,
      };
}
