// lib/services/contacto_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contacto.dart';
import 'stream_error_logging.dart';

class ContactoService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('contactos');

  static Stream<List<Contacto>> streamContactos(String casaId) {
    return _col(casaId)
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs.map(Contacto.fromDoc).toList())
        .conRegistroDeErrores();
  }

  static Future<void> crear(String casaId, Contacto contacto) async {
    await _col(casaId).add({...contacto.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }

  static Future<void> actualizar(String casaId, String contactoId, Contacto contacto) async {
    await _col(casaId).doc(contactoId).update(contacto.toMap());
  }

  static Future<void> eliminar(String casaId, String contactoId) async {
    await _col(casaId).doc(contactoId).delete();
  }
}
