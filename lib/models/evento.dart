// lib/models/evento.dart
//
// Un evento es una entrada en "la historia de la casa" (sección 12 del spec
// de producto): instalación, revisión, reparación, sustitución, reforma o
// nota libre. Vive a nivel de casa (no anidado en el elemento) para que la
// pantalla de Historial pueda mostrar una única timeline sin consultas
// agregadas entre colecciones -- el filtrado por elemento/habitación se hace
// con un campo, no con la jerarquía.
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoEvento { instalacion, revision, reparacion, sustitucion, reforma, nota }

TipoEvento tipoEventoFromString(String? s) => TipoEvento.values.firstWhere(
      (t) => t.name == s,
      orElse: () => TipoEvento.nota,
    );

class Evento {
  const Evento({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.descripcion,
    this.elementoId,
    this.habitacionId,
    this.trabajoId,
    this.coste,
    this.profesionalNombre,
    this.documentoIds = const [],
    required this.fecha,
    this.createdBy,
    this.esFinalizacion = false,
  });

  final String id;
  final TipoEvento tipo;
  final String titulo;
  final String? descripcion;
  final String? elementoId;
  final String? habitacionId;
  final String? trabajoId;
  final double? coste;
  final String? profesionalNombre;
  final List<String> documentoIds;
  final DateTime fecha;
  final String? createdBy;

  /// true solo en el evento que de verdad cierra un trabajo (lo pone
  /// finalizarTrabajoPropietario, nunca el cliente) -- otros eventos
  /// también llevan trabajoId/coste (presupuesto aceptado, cambio de
  /// alcance aprobado...) pero no representan el cierre del trabajo.
  final bool esFinalizacion;

  factory Evento.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Evento(
      id: doc.id,
      tipo: tipoEventoFromString(data['tipo'] as String?),
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      elementoId: data['elementoId'] as String?,
      habitacionId: data['habitacionId'] as String?,
      trabajoId: data['trabajoId'] as String?,
      coste: (data['coste'] as num?)?.toDouble(),
      profesionalNombre: data['profesionalNombre'] as String?,
      documentoIds: List<String>.from(data['documentoIds'] as List? ?? []),
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
      esFinalizacion: data['esFinalizacion'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.name,
        'titulo': titulo,
        if (descripcion != null) 'descripcion': descripcion,
        if (elementoId != null) 'elementoId': elementoId,
        if (habitacionId != null) 'habitacionId': habitacionId,
        if (trabajoId != null) 'trabajoId': trabajoId,
        if (coste != null) 'coste': coste,
        if (profesionalNombre != null) 'profesionalNombre': profesionalNombre,
        'documentoIds': documentoIds,
        'fecha': Timestamp.fromDate(fecha),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
