// lib/services/casa_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/casa.dart';
import 'stream_error_logging.dart';

class CasaService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static Stream<String?> streamActiveCasaId() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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

  static Future<({String casaId, String joinCode})> createCasa(String nombre) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('createCasa');
    final result = await callable.call<Map<String, dynamic>>({'nombre': nombre});
    final data = result.data;
    return (casaId: data['casaId'] as String, joinCode: data['joinCode'] as String);
  }

  static Future<String> joinCasa(String joinCode) async {
    final callable = FirebaseFunctions.instanceFor(region: _region).httpsCallable('joinCasa');
    final result = await callable.call<Map<String, dynamic>>({'joinCode': joinCode});
    return result.data['casaId'] as String;
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
