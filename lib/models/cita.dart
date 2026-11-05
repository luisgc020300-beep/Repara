// lib/models/cita.dart
//
// Agenda del profesional (ampliación funcional REPARA Pro, Fase 4 -- CEO,
// noviembre 2026): una cita es trabajo programado, una visita, una tarea
// pendiente o cualquier otra fecha importante -- puramente personal del
// profesional, nunca un dato del propietario. Vive en
// profesionales/{uid}/citas, nunca en una casa (ver firestore.rules).
//
// [fecha] es la fecha/hora PROGRAMADA -- nunca se confunde con
// [createdAt], que es cuándo se creó esta cita (CEO: "no confundas la
// fecha de creación de un trabajo con la fecha en la que está
// programado"). [todoElDia] decide si se enseña una hora concreta o solo
// el día.
import 'package:cloud_firestore/cloud_firestore.dart';

class Cita {
  const Cita({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.todoElDia = false,
    this.horaFin,
    this.descripcion,
    this.casaId,
    this.elementoId,
    this.registroId,
    this.registroTitulo,
    this.casaNombre,
    this.completada = false,
    this.compartida = false,
    this.createdAt,
  });

  final String id;
  final String titulo;
  final String? descripcion;
  final DateTime fecha;
  final bool todoElDia;

  /// Hora de fin (opcional, CEO noviembre 2026: "mismo diseño que
  /// oficio-ai", que muestra un rango "21:14 -- 22:44" en cada cita).
  /// Comparte fecha con [fecha] -- solo la hora/minuto importan. Null
  /// cuando la cita no tiene una duración conocida, o es "todo el día".
  final DateTime? horaFin;

  /// Trabajo al que enlaza esta cita, si lo hay -- los tres van siempre
  /// juntos o ninguno. Null cuando es una cita suelta (p.ej. "visita de
  /// presupuesto" antes de que exista ningún trabajo todavía).
  final String? casaId;
  final String? elementoId;
  final String? registroId;

  /// Denormalizados en el momento de enlazar -- mismo criterio que
  /// RegistroProRef: el profesional nunca necesita volver a leer la casa
  /// solo para mostrar estos dos nombres en la agenda.
  final String? registroTitulo;
  final String? casaNombre;

  final bool completada;

  /// Visible de solo lectura para el propietario del trabajo al que enlaza
  /// (noviembre 2026, "avisos inteligentes + registro de actividad
  /// compartido") -- solo tiene efecto cuando [enlazaTrabajo] es true; una
  /// cita suelta nunca es compartible porque no hay ningún trabajo al que
  /// asociar el permiso de lectura (ver firestore.rules). El profesional
  /// sigue siendo el único que la crea/edita/cancela.
  final bool compartida;
  final DateTime? createdAt;

  bool get enlazaTrabajo =>
      registroId != null && elementoId != null && casaId != null;

  factory Cita.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Cita(
      id: doc.id,
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String?,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      todoElDia: data['todoElDia'] as bool? ?? false,
      horaFin: (data['horaFin'] as Timestamp?)?.toDate(),
      casaId: data['casaId'] as String?,
      elementoId: data['elementoId'] as String?,
      registroId: data['registroId'] as String?,
      registroTitulo: data['registroTitulo'] as String?,
      casaNombre: data['casaNombre'] as String?,
      completada: data['completada'] as bool? ?? false,
      compartida: data['compartida'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    if (descripcion != null && descripcion!.isNotEmpty)
      'descripcion': descripcion,
    'fecha': Timestamp.fromDate(fecha),
    'todoElDia': todoElDia,
    if (horaFin != null) 'horaFin': Timestamp.fromDate(horaFin!),
    if (casaId != null) 'casaId': casaId,
    if (elementoId != null) 'elementoId': elementoId,
    if (registroId != null) 'registroId': registroId,
    if (registroTitulo != null) 'registroTitulo': registroTitulo,
    if (casaNombre != null) 'casaNombre': casaNombre,
    'completada': completada,
    'compartida': compartida,
  };
}
