// lib/models/notificacion.dart
//
// Notificación interna persistente (sección 29 del spec: "si todavía no
// existe infraestructura push, empieza con notificaciones internas
// persistentes"). Sin push real todavía -- se consulta dentro de la app.
import 'package:cloud_firestore/cloud_firestore.dart';

class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.leida,
    this.casaId,
    this.trabajoId,
    this.presupuestoId,
    this.cambioAlcanceId,
    this.createdAt,
  });

  final String id;
  final String tipo;
  final String titulo;
  final String cuerpo;
  final bool leida;
  final String? casaId;
  final String? trabajoId;
  final String? presupuestoId;
  final String? cambioAlcanceId;
  final DateTime? createdAt;

  /// Algunos tipos de notificación solo tienen sentido para quien actúa como
  /// profesional en ESE trabajo (p.ej. que le acepten un presupuesto), nunca
  /// para el propietario -- y viceversa. Como la misma cuenta puede ser
  /// propietaria de una casa y profesional en otra (sección "modo dual" del
  /// spec), hay que separarlas: una notificación de modo Pro no debe
  /// aparecer mientras se navega en modo Hogar, ni al revés.
  static const _tiposParaProfesional = {
    'presupuesto_aceptado',
    'presupuesto_rechazado',
    'cambio_alcance_aprobado',
    'cambio_alcance_rechazado',
  };

  bool get esParaProfesional => _tiposParaProfesional.contains(tipo);

  factory Notificacion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Notificacion(
      id: doc.id,
      tipo: data['tipo'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      cuerpo: data['cuerpo'] as String? ?? '',
      leida: data['leida'] as bool? ?? false,
      casaId: data['casaId'] as String?,
      trabajoId: data['trabajoId'] as String?,
      presupuestoId: data['presupuestoId'] as String?,
      cambioAlcanceId: data['cambioAlcanceId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
