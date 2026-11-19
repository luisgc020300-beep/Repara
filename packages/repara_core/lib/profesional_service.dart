// lib/services/profesional_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:repara_core/profesional.dart';
import 'package:repara_core/stream_error_logging.dart';

class ProfesionalService {
  /// Seams de solo test -- nunca se asignan en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  // Ver casa_service.dart: debugFirestoreOverride (no debugUidOverride) es
  // la señal real de "estamos en test", para poder simular uid null aposta.
  static String? get _uid => debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;
  static const _region = 'europe-west1';

  static Future<void> activarModoProfesional() async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('activarModoProfesional');
    await callable.call<Map<String, dynamic>>();
  }

  /// Backfill de custom claims (casaIds/registrosProId) para cuentas que ya
  /// existían antes de que Storage las necesitara (ver storage.rules) --
  /// mismo criterio y misma Cloud Function genérica que
  /// CasaService.sincronizarClaims() (Hogar/monolito), aquí sin duplicar la
  /// lógica: la función del servidor no depende de casaIds, también
  /// recalcula registrosProId a partir de users/{uid}.registrosProRefs, que
  /// es justo lo que Pro necesita. Se llama una vez por evento de inicio de
  /// sesión (ver main.dart).
  static Future<void> sincronizarClaims() async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('sincronizarClaims');
    await callable.call<Map<String, dynamic>>();
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

  /// null mientras carga, false/true una vez se conoce el estado real.
  static Stream<bool> streamEsProfesional() {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => d.data()?['esProfesional'] as bool? ?? false)
        .conRegistroDeErrores();
  }

  static Stream<Profesional?> streamPerfilPropio() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('profesionales')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? Profesional.fromDoc(d) : null)
        .conRegistroDeErrores();
  }

  static Future<void> actualizarPerfil({
    String? nombreComercial,
    String? especialidad,
    String? telefono,
    String? descripcion,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('profesionales').doc(uid).set({
      'nombreComercial': ?nombreComercial,
      'especialidad': ?especialidad,
      'telefono': ?telefono,
      'descripcion': ?descripcion,
    }, SetOptions(merge: true));
  }

  /// Foto del perfil profesional (mejora de perfiles, noviembre 2026) --
  /// aparte de actualizarPerfil porque el flujo real es distinto (subir a
  /// Storage primero, ver ElementoService.subirFoto para el mismo patrón),
  /// no un campo de texto más. null borra la foto (no el archivo en
  /// Storage), igual que ElementoService.actualizarFoto.
  static Future<void> actualizarFoto(String? fotoUrl) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('profesionales').doc(uid).set({
      'fotoUrl': fotoUrl,
    }, SetOptions(merge: true));
  }

  /// Cercanos (noviembre 2026): el propio profesional opta por hacerse
  /// visible en las búsquedas de "cerca de mí" de REPARA Hogar, compartiendo
  /// una posición aproximada. Mismo patrón de escritura directa que
  /// actualizarPerfil (firestore.rules: solo el propio dueño lee/escribe su
  /// ficha) -- no hace falta Cloud Function para esto, nadie más la lee
  /// salvo buscarProfesionalesCercanos con Admin SDK. Al desactivar, se
  /// borran lat/lng en vez de dejarlas obsoletas -- no hay motivo para
  /// conservar una ubicación que ya no se usa para nada.
  static Future<void> actualizarVisibilidadCercana({
    required bool visible,
    double? lat,
    double? lng,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('profesionales').doc(uid).set({
      'visibleCercano': visible,
      if (visible && lat != null && lng != null) 'lat': lat,
      if (visible && lat != null && lng != null) 'lng': lng,
      if (!visible) 'lat': FieldValue.delete(),
      if (!visible) 'lng': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Registros aceptados por el profesional -- copia ligera guardada por la
  /// Cloud Function al aceptar una invitación (ver responderInvitacion),
  /// para no necesitar permiso de lectura sobre casas ajenas.
  static Stream<List<RegistroProRef>> streamRegistrosProRefs() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db.collection('users').doc(uid).snapshots().map((d) {
      final lista = (d.data()?['registrosProRefs'] as List?) ?? [];
      return lista.map((e) => RegistroProRef.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }).conRegistroDeErrores();
  }
}
