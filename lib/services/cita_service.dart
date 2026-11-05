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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cita.dart';
import 'stream_error_logging.dart';
import 'stream_sharing.dart';

class CitaService {
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
}
