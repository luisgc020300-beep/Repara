// lib/services/casa_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/casa.dart';
import 'stream_error_logging.dart';

class CasaService {
  /// Seams de solo test -- nunca se asignan en código de producción. Permiten
  /// probar la lógica de consultas/streams contra un Firestore falso
  /// (fake_cloud_firestore) sin tocar la firma pública de ningún método.
  /// Operaciones que necesitan el User completo de FirebaseAuth (email,
  /// refresco de token) siguen usando FirebaseAuth.instance.currentUser
  /// directamente -- no hay en este repo un paquete de auth-mock para eso.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;
  // debugUidOverride != null NO basta como señal de "estamos en test" --
  // un test que simula "sin sesión" necesita poder poner el override a
  // null a propósito. Usamos debugFirestoreOverride (siempre presente en
  // cualquier test que toque _uid) como la señal real de modo test.
  static String? get _uid => debugFirestoreOverride != null ? debugUidOverride : FirebaseAuth.instance.currentUser?.uid;

  static const _region = 'europe-west1';

  static Stream<String?> streamActiveCasaId() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['activeCasaId'] as String?)
        .conRegistroDeErrores();
  }

  static Stream<Casa> streamCasa(String casaId) {
    return _db
        .collection('casas')
        .doc(casaId)
        .snapshots()
        .where((d) => d.exists)
        .map(Casa.fromDoc)
        .conRegistroDeErrores();
  }

  /// Todas las casas a las que pertenece el usuario (octubre 2026: selector
  /// de varias casas) -- no solo la activa. createCasa/joinCasa ya la
  /// mantienen actualizada con arrayUnion.
  static Stream<List<String>> streamCasaIds() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => List<String>.from(doc.data()?['casaIds'] as List? ?? const []))
        .conRegistroDeErrores();
  }

  /// Lectura puntual (no stream) de una casa por id -- para listar nombres
  /// en el selector sin abrir un stream permanente por cada una.
  static Future<Casa?> obtenerCasa(String casaId) async {
    final doc = await _db.collection('casas').doc(casaId).get();
    return doc.exists ? Casa.fromDoc(doc) : null;
  }

  /// Cambia la casa activa a otra a la que el usuario ya pertenece. Pasa por
  /// Cloud Function (no escritura directa) para que el servidor valide que
  /// de verdad está en casaIds, mismo criterio que activarModoProfesional.
  static Future<void> cambiarCasaActiva(String casaId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('cambiarCasaActiva');
    await callable.call<Map<String, dynamic>>({'casaId': casaId});
  }

  static Future<({String casaId, String joinCode})> createCasa(String nombre) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('createCasa');
    final result = await callable.call<Map<String, dynamic>>({'nombre': nombre});
    await _refrescarToken();
    final data = result.data;
    return (casaId: data['casaId'] as String, joinCode: data['joinCode'] as String);
  }

  static Future<String> joinCasa(String joinCode) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('joinCasa');
    final result = await callable.call<Map<String, dynamic>>({'joinCode': joinCode});
    await _refrescarToken();
    return result.data['casaId'] as String;
  }

  /// El servidor ya recalculó los custom claims (casaIds/registrosProId --
  /// ver sincronizarClaimsUid en functions/index.js) como parte de
  /// createCasa/joinCasa -- esto solo hace que el cliente los recoja ya,
  /// sin esperar a la próxima renovación automática del token (hasta una
  /// hora). Sin esto, justo después de crear o unirte a una casa, Storage
  /// seguiría rechazando las subidas con el token viejo.
  static Future<void> _refrescarToken() => FirebaseAuth.instance.currentUser?.getIdToken(true) ?? Future.value();

  /// Backfill para cuentas que ya tenían casaIds antes de que existieran
  /// estas claims, y refresco general -- se llama una vez por sesión al
  /// iniciar la app (ver main.dart).
  static Future<void> sincronizarClaims() async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('sincronizarClaims');
    await callable.call<Map<String, dynamic>>();
    await _refrescarToken();
  }

  /// El nombre de la casa es el único campo del documento editable en
  /// directo desde el cliente (ver firestore.rules) -- todo lo demás
  /// (miembros, joinCode) pasa por una Cloud Function transaccional.
  static Future<void> renombrarCasa(String casaId, String nombre) async {
    await _db.collection('casas').doc(casaId).update({'nombre': nombre});
  }

  static Future<void> asegurarPerfilUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final displayName = (user.email ?? 'Propietario').split('@').first;
    await ref.set({
      'displayName': displayName,
      'activeCasaId': null,
      'casaIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
