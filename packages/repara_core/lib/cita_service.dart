// lib/services/cita_service.dart
//
// Agenda del profesional (ampliación funcional REPARA Pro, Fase 4 --
// CEO, noviembre 2026). Escritura directa a Firestore, sin Cloud
// Function -- a diferencia de presupuestos/pagos/cambios de alcance, una
// cita nunca mueve dinero ni afecta a otro usuario (ver firestore.rules:
// solo el propio profesional puede leer o escribir su subcolección de
// citas), así que no hay nada que proteger con una transacción de
// servidor. Mismo criterio ya usado en
// ProfesionalService.actualizarPerfil (perfil profesional, escritura
// directa también).
//
// EXCEPCIÓN (noviembre 2026, "que el propietario pueda responder de
// verdad"): `responderComoPropietario`/`proponerOtraFecha`, al final de
// este archivo, SÍ cruzan de la cuenta del propietario a un documento del
// profesional -- esas dos SÍ son Cloud Functions
// (`responderCitaPropietario`/`proponerOtraFechaCita`), mismo principio
// que CambioAlcanceService. `responderContrapropuesta` sigue siendo
// escritura directa porque es el profesional respondiendo sobre su propio
// documento.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:repara_core/cita.dart';
import 'package:repara_core/stream_error_logging.dart';
import 'package:repara_core/stream_sharing.dart';

class CitaService {
  static const _region = 'europe-west1';

  /// Seams de solo test -- nunca se asignan en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid => debugFirestoreOverride != null
      ? debugUidOverride
      : FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('profesionales').doc(uid).collection('citas');
  }

  /// Todas las citas del profesional -- el filtrado por día/semana/mes de
  /// la agenda se hace en el cliente (ver agenda_pro_tab.dart), no aquí:
  /// una cita por trabajo, nunca muchas por usuario, así que no hace falta
  /// paginar ni acotar por rango en la propia consulta.
  static Stream<List<Cita>> streamCitas() {
    final col = _col();
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('fecha')
        .snapshots()
        .map((s) => s.docs.map(Cita.fromDoc).toList())
        .conRegistroDeErrores();
  }

  /// Lado Hogar (noviembre 2026): lee la agenda de UN profesional concreto
  /// -- no la del uid autenticado, por eso no usa [_col] -- filtrando solo
  /// las citas de este trabajo. [compartida] se filtra en cliente: como
  /// mucho hay un puñado de citas por trabajo, no merece un índice
  /// compuesto nuevo solo para esto. firestore.rules es quien de verdad
  /// protege el acceso -- una cita no compartida de este mismo trabajo
  /// simplemente no llega aquí (el propietario no tiene permiso de
  /// lectura sobre ella), así que el filtro de cliente es solo una
  /// comodidad, no la barrera de seguridad real.
  static Stream<List<Cita>> streamCitasCompartidas({
    required String profesionalUid,
    required String registroId,
  }) {
    return _db
        .collection('profesionales')
        .doc(profesionalUid)
        .collection('citas')
        .where('registroId', isEqualTo: registroId)
        .snapshots()
        .map(
          (s) => s.docs
              .map(Cita.fromDoc)
              .where((c) => c.compartida)
              .toList()
            ..sort((a, b) => a.fecha.compareTo(b.fecha)),
        )
        .conRegistroDeErrores()
        .compartido('citasCompartidas:$profesionalUid:$registroId');
  }

  static Future<void> crear(Cita cita) async {
    final col = _col();
    if (col == null) return;
    await col.add({...cita.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }

  static Future<void> actualizar(String citaId, Cita cita) async {
    final col = _col();
    if (col == null) return;
    await col.doc(citaId).update(cita.toMap());
  }

  static Future<void> marcarCompletada(String citaId, bool completada) async {
    final col = _col();
    if (col == null) return;
    await col.doc(citaId).update({'completada': completada});
  }

  static Future<void> eliminar(String citaId) async {
    final col = _col();
    if (col == null) return;
    await col.doc(citaId).delete();
  }

  /// Respuesta del PROFESIONAL a la contrapropuesta de fecha del
  /// propietario (`EstadoCita.contrapropuestaPropietario`) -- sigue siendo
  /// su propio documento, así que es escritura directa, sin Cloud
  /// Function, igual que el resto de este archivo. Las acciones del
  /// PROPIETARIO (confirmar/rechazar/proponer otra fecha) SÍ pasan por
  /// Cloud Functions -- ver `responderCitaPropietario`/
  /// `proponerOtraFechaCita` en functions/index.js -- porque esas cruzan
  /// de la cuenta del propietario a un documento del profesional.
  ///
  /// `FieldValue.delete()` explícito en vez de depender de `toMap()`: esa
  /// función omite las claves null en vez de limpiarlas, así que un
  /// `.update()` con ella nunca borraría `fechaPropuesta`/`horaFinPropuesta`
  /// ya guardadas.
  static Future<void> responderContrapropuesta({
    required String citaId,
    required bool aceptar,
  }) async {
    final col = _col();
    if (col == null) return;
    if (aceptar) {
      final snap = await col.doc(citaId).get();
      final data = snap.data();
      final fechaPropuesta = (data?['fechaPropuesta'] as Timestamp?)?.toDate();
      if (fechaPropuesta == null) return;
      final horaFinPropuesta = (data?['horaFinPropuesta'] as Timestamp?)?.toDate();
      await col.doc(citaId).update({
        'fecha': Timestamp.fromDate(fechaPropuesta),
        if (horaFinPropuesta != null)
          'horaFin': Timestamp.fromDate(horaFinPropuesta)
        else
          'horaFin': FieldValue.delete(),
        'fechaPropuesta': FieldValue.delete(),
        'horaFinPropuesta': FieldValue.delete(),
        'estado': EstadoCita.confirmada.name,
      });
    } else {
      await col.doc(citaId).update({
        'fechaPropuesta': FieldValue.delete(),
        'horaFinPropuesta': FieldValue.delete(),
        'estado': EstadoCita.pendienteConfirmacion.name,
      });
    }
  }

  /// Lado Hogar: confirmar o rechazar la fecha que el profesional ha
  /// propuesto. Cloud Function -- ver comentario de cabecera.
  static Future<void> responderComoPropietario({
    required String profesionalUid,
    required String citaId,
    required bool confirmar,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('responderCitaPropietario');
    await callable.call<Map<String, dynamic>>({
      'profesionalUid': profesionalUid,
      'citaId': citaId,
      'respuesta': confirmar ? 'confirmar' : 'rechazar',
    });
  }

  /// Lado Hogar: proponer una fecha/hora distinta a la del profesional.
  /// Cloud Function -- ver comentario de cabecera.
  static Future<void> proponerOtraFecha({
    required String profesionalUid,
    required String citaId,
    required DateTime fecha,
    DateTime? horaFin,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('proponerOtraFechaCita');
    await callable.call<Map<String, dynamic>>({
      'profesionalUid': profesionalUid,
      'citaId': citaId,
      'fecha': fecha.toIso8601String(),
      if (horaFin != null) 'horaFin': horaFin.toIso8601String(),
    });
  }
}
