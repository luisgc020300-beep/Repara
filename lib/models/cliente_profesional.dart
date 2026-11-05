// lib/models/cliente_profesional.dart
//
// Cliente privado del profesional (Fase 1, noviembre 2026): corrige el
// hallazgo más crítico de la auditoría funcional -- un profesional no podía
// registrar un cliente por iniciativa propia, todo dependía de que el
// propietario iniciara el proceso desde REPARA Hogar. Vive en
// profesionales/{uid}/clientesPro, nunca en una casa (ver firestore.rules);
// no tiene ninguna relación con una cuenta de REPARA Hogar todavía -- eso es
// la vinculación de una fase futura (Fase 2, no implementada aquí).
//
// [direccion] es texto libre a propósito -- Casa no tiene ningún campo de
// dirección estructurada hoy y esta fase no construye uno de cero sin que
// haya todavía ningún consumidor real (mapas, facturación formal).
import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteProfesional {
  const ClienteProfesional({
    required this.id,
    required this.nombre,
    this.telefono,
    this.email,
    this.direccion,
    this.notas,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? notas;
  final DateTime? createdAt;

  factory ClienteProfesional.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ClienteProfesional(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      telefono: data['telefono'] as String?,
      email: data['email'] as String?,
      direccion: data['direccion'] as String?,
      notas: data['notas'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (direccion != null && direccion!.isNotEmpty) 'direccion': direccion,
    if (notas != null && notas!.isNotEmpty) 'notas': notas,
  };
}
