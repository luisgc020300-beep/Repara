// lib/services/profesional_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/profesional.dart';
import 'stream_error_logging.dart';

class ProfesionalService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static Future<void> activarModoProfesional() async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('activarModoProfesional');
    await callable.call<Map<String, dynamic>>();
  }

  /// null mientras carga, false/true una vez se conoce el estado real.
  static Stream<bool> streamEsProfesional() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => d.data()?['esProfesional'] as bool? ?? false)
        .conRegistroDeErrores();
  }

  static Stream<Profesional?> streamPerfilPropio() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('profesionales')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? Profesional.fromDoc(d) : null)
        .conRegistroDeErrores();
  }

  static Future<void> actualizarPerfil({String? nombreComercial, String? especialidad, String? telefono}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('profesionales').doc(uid).set({
      'nombreComercial': ?nombreComercial,
      'especialidad': ?especialidad,
      'telefono': ?telefono,
    }, SetOptions(merge: true));
  }

  /// Trabajos aceptados por el profesional -- copia ligera guardada por la
  /// Cloud Function al aceptar una invitación (ver responderInvitacion),
  /// para no necesitar permiso de lectura sobre casas ajenas.
  static Stream<List<TrabajoProRef>> streamTrabajosProRefs() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db.collection('users').doc(uid).snapshots().map((d) {
      final lista = (d.data()?['trabajosProRefs'] as List?) ?? [];
      return lista.map((e) => TrabajoProRef.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }).conRegistroDeErrores();
  }
}
