// lib/models/registro.dart
//
// Un registro es cada suceso de un Elemento (octubre 2026, fusión de lo que
// antes eran Trabajo y Evento por separado): desde "compré una freidora"
// (registro simple, sin profesional) hasta "me cambiaron la depuradora de
// la piscina" (con presupuesto, pagos, invitación de profesional y modelo
// de dos pasos). [esConProfesional] es lo que decide, al crearlo, cuál de
// los dos flujos se activa -- no se deriva solo de [tipo], porque una
// "reparación" puede ser tanto DIY como contratada.
//
// El profesional puede ser solo texto libre (nombre/contacto, sin cuenta --
// cumple el principio de "no obligar a un marketplace") o, si se invita a
// una cuenta profesional real de Repara y acepta (ver InvitacionService),
// quedar vinculado por [profesionalUid]. Cuando hay [profesionalUid], ese
// profesional puede leer ESTE registro (nunca el Elemento padre) y
// actualizar su estado aunque no sea miembro de la casa (ver
// firestore.rules) -- por eso [elementoNombre] va denormalizado aquí: el
// lado Pro nunca necesita permiso de lectura sobre el elemento en sí.
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoRegistro {
  compra,
  averia,
  reparacion,
  mantenimiento,
  instalacion,
  reforma,
  sustitucion,
  nota,
}

TipoRegistro tipoRegistroFromString(String? s) => TipoRegistro.values
    .firstWhere((t) => t.name == s, orElse: () => TipoRegistro.nota);

String nombreTipoRegistro(TipoRegistro t) => switch (t) {
  TipoRegistro.compra => 'Compra',
  TipoRegistro.averia => 'Avería',
  TipoRegistro.reparacion => 'Reparación',
  TipoRegistro.mantenimiento => 'Mantenimiento',
  TipoRegistro.instalacion => 'Instalación',
  TipoRegistro.reforma => 'Reforma/Mejora',
  TipoRegistro.sustitucion => 'Sustitución',
  TipoRegistro.nota => 'Nota',
};

// pendienteConfirmacion: el profesional dice que ha terminado, pero el
// propietario todavía no lo ha confirmado ni rechazado -- modelo de dos
// pasos (auditoría de producto, octubre 2026) en vez de que cualquiera de
// las dos partes pueda cerrar el registro unilateralmente sin que la otra
// esté de acuerdo. Solo aplica cuando esConProfesional es true.
//
// pendientePago (CEO, octubre 2026): "terminado" significa el proceso
// entero -- trabajo hecho Y cobrado -- no solo el trabajo. Un registro
// llega aquí en vez de a "terminado" cuando el trabajo ya está confirmado
// pero coste/presupuesto todavía no está cubierto por la suma de sus pagos
// (ver montoDebido en registro_service.dart/functions/index.js). Cuenta
// como "trabajo activo" a todos los efectos (RegistroService.esTrabajoActivo,
// aviso de Inicio, bloqueo de archivado) para que no se olvide que falta
// cobrar. Transición automática en ambos sentidos, gestionada siempre por
// Cloud Function al registrar/editar/borrar un pago o al finalizar: nunca
// se escribe a mano desde el cliente (ver _estadoControlado en
// registro_detail_screen.dart).
enum EstadoRegistro {
  nuevo,
  presupuestado,
  enCurso,
  pendienteConfirmacion,
  pendientePago,
  terminado,
  archivado,
}

// Importe del que depende si un registro está realmente cobrado: el
// presupuesto cuando va con profesional, el coste cuando es simple -- nunca
// los dos a la vez en la práctica. Mismo criterio en los tres sitios que lo
// necesitan (aquí, expediente_vivienda_screen.dart y, repetido en servidor
// porque la decisión de cambiar `estado` se toma ahí, functions/index.js).
double? montoDebidoRegistro(Registro r) => r.presupuesto ?? r.coste;

// Un registro simple (sin profesional) solo tiene algo que cobrar si se le
// puso un coste > 0 al crearlo -- si no, nace "terminado" directo, nunca
// "pendientePago" sin nada pendiente de verdad.
EstadoRegistro estadoInicialRegistroSimple(double? coste) =>
    (coste != null && coste > 0)
    ? EstadoRegistro.pendientePago
    : EstadoRegistro.terminado;

EstadoRegistro estadoRegistroFromString(String? s) => EstadoRegistro.values
    .firstWhere((t) => t.name == s, orElse: () => EstadoRegistro.nuevo);

class Registro {
  const Registro({
    required this.id,
    required this.elementoNombre,
    required this.tipo,
    required this.esConProfesional,
    required this.titulo,
    required this.estado,
    required this.fecha,
    this.descripcion,
    this.garantiaHasta,
    this.coste,
    this.fotoUrl,
    this.fotoUrls = const [],
    this.documentoIds = const [],
    this.profesionalNombre,
    this.profesionalContacto,
    this.profesionalUid,
    this.presupuesto,
    this.plazoFrecuenciaMeses,
    this.plazoImporte,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String elementoNombre;
  final TipoRegistro tipo;
  final bool esConProfesional;
  final String titulo;
  final EstadoRegistro estado;
  final DateTime fecha;
  final String? descripcion;
  final DateTime? garantiaHasta;
  final double? coste;
  // Foto única heredada -- se conserva tal cual para la ficha del elemento
  // (Elemento.fotoUrl, que sigue siendo de una sola foto) y para
  // registros creados antes de la galería nueva. [fotoUrls] es la galería
  // (CEO, octubre 2026: primero solo en el registro simple, ahora también
  // en el de con profesional -- ver RegistroCabecera, compartida entre
  // ambos) -- ver [fotos] más abajo para el criterio de compatibilidad con
  // los registros antiguos que solo tienen [fotoUrl].
  final String? fotoUrl;
  final List<String> fotoUrls;
  final List<String> documentoIds;
  final String? profesionalNombre;
  final String? profesionalContacto;
  final String? profesionalUid;
  final double? presupuesto;
  // Pago a plazos (CEO, octubre 2026) -- puramente informativo, para que la
  // ficha pueda calcular un "próximo pago estimado"; no cambia en nada
  // cuándo pasa a terminado (eso sigue dependiendo solo de los pagos reales
  // en Pagos, ver estadoTrasCambioDePago). Los dos van juntos o ninguno --
  // no tiene sentido una frecuencia sin importe ni al revés.
  final int? plazoFrecuenciaMeses;
  final double? plazoImporte;
  final DateTime? createdAt;
  final String? createdBy;

  factory Registro.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Registro(
      id: doc.id,
      elementoNombre: data['elementoNombre'] as String? ?? '',
      tipo: tipoRegistroFromString(data['tipo'] as String?),
      esConProfesional: data['esConProfesional'] as bool? ?? false,
      titulo: data['titulo'] as String? ?? '',
      estado: estadoRegistroFromString(data['estado'] as String?),
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      descripcion: data['descripcion'] as String?,
      garantiaHasta: (data['garantiaHasta'] as Timestamp?)?.toDate(),
      coste: (data['coste'] as num?)?.toDouble(),
      fotoUrl: data['fotoUrl'] as String?,
      fotoUrls: List<String>.from(data['fotoUrls'] as List? ?? []),
      documentoIds: List<String>.from(data['documentoIds'] as List? ?? []),
      profesionalNombre: data['profesionalNombre'] as String?,
      profesionalContacto: data['profesionalContacto'] as String?,
      profesionalUid: data['profesionalUid'] as String?,
      presupuesto: (data['presupuesto'] as num?)?.toDouble(),
      plazoFrecuenciaMeses: (data['plazoFrecuenciaMeses'] as num?)?.toInt(),
      plazoImporte: (data['plazoImporte'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'elementoNombre': elementoNombre,
    'tipo': tipo.name,
    'esConProfesional': esConProfesional,
    'titulo': titulo,
    'estado': estado.name,
    'fecha': Timestamp.fromDate(fecha),
    if (descripcion != null) 'descripcion': descripcion,
    if (garantiaHasta != null)
      'garantiaHasta': Timestamp.fromDate(garantiaHasta!),
    if (coste != null) 'coste': coste,
    if (fotoUrl != null) 'fotoUrl': fotoUrl,
    if (fotoUrls.isNotEmpty) 'fotoUrls': fotoUrls,
    'documentoIds': documentoIds,
    if (profesionalNombre != null) 'profesionalNombre': profesionalNombre,
    if (profesionalContacto != null) 'profesionalContacto': profesionalContacto,
    if (profesionalUid != null) 'profesionalUid': profesionalUid,
    if (presupuesto != null) 'presupuesto': presupuesto,
    if (plazoFrecuenciaMeses != null)
      'plazoFrecuenciaMeses': plazoFrecuenciaMeses,
    if (plazoImporte != null) 'plazoImporte': plazoImporte,
    'createdAt': FieldValue.serverTimestamp(),
  };

  // Galería del registro simple (CEO, octubre 2026): [fotoUrls] si ya se
  // usó la galería nueva; si no, cae a la [fotoUrl] única de un registro
  // creado antes de esta mejora -- así un evento antiguo con una sola foto
  // se ve exactamente igual en la nueva galería, sin ninguna migración de
  // datos.
  List<String> get fotos => fotoUrls.isNotEmpty ? fotoUrls : [?fotoUrl];

  // Próximo pago estimado: fecha del último pago registrado (o, si todavía
  // no hay ninguno, la fecha de creación del registro) + la frecuencia del
  // plan. Mismo patrón que proximoMantenimiento en nuevo_elemento_screen.
  // dart -- DateTime normaliza el desbordamiento de mes él solo, sin
  // necesidad de un cálculo de calendario más elaborado.
  DateTime? proximoPagoEstimado(DateTime? fechaUltimoPago) {
    final frecuencia = plazoFrecuenciaMeses;
    if (frecuencia == null) return null;
    final base = fechaUltimoPago ?? fecha;
    return DateTime(base.year, base.month + frecuencia, base.day);
  }
}
