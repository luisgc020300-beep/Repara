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
    this.favorito = false,
    this.createdAt,
    this.profesionalUidVinculado,
  });

  final String id;
  final String nombre;
  final String telefono;
  final TipoContacto tipo;
  final String? especialidad;
  final String? notas;

  /// Marcado a mano por el propietario (noviembre 2026, organización de
  /// Contactos) -- ningún criterio automático, solo lo que el usuario
  /// decide destacar.
  final bool favorito;
  final DateTime? createdAt;

  /// Vinculación de contactos (noviembre 2026): la cuenta profesional real
  /// de REPARA Pro que corresponde a este contacto, solo cuando
  /// responderInvitacion (Cloud Function) la ha verificado -- nunca por
  /// coincidencia de nombre o teléfono. Null mientras no haya ninguna
  /// invitación aceptada que lo confirme; no es escribible por el cliente
  /// (ver firestore.rules). Mientras sea null, no debe mostrarse ninguna
  /// valoración para este contacto.
  final String? profesionalUidVinculado;

  factory Contacto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Contacto(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      tipo: tipoContactoFromString(data['tipo'] as String?),
      especialidad: data['especialidad'] as String?,
      notas: data['notas'] as String?,
      favorito: data['favorito'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      profesionalUidVinculado: data['profesionalUidVinculado'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'telefono': telefono,
        'tipo': tipo.name,
        if (especialidad != null) 'especialidad': especialidad,
        if (notas != null) 'notas': notas,
        'favorito': favorito,
      };

  Contacto copyWith({bool? favorito}) => Contacto(
        id: id,
        nombre: nombre,
        telefono: telefono,
        tipo: tipo,
        especialidad: especialidad,
        notas: notas,
        favorito: favorito ?? this.favorito,
        createdAt: createdAt,
        profesionalUidVinculado: profesionalUidVinculado,
      );
}
