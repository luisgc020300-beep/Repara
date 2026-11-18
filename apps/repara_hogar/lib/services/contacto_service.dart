// lib/services/contacto_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:repara_core/stream_error_logging.dart';

import '../models/contacto.dart';

class ContactoService {
  /// Seam de solo test -- nunca se asigna en código de producción. Ver
  /// casa_service.dart para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;

  static FirebaseFirestore get _db => debugFirestoreOverride ?? FirebaseFirestore.instance;

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

  static Future<void> alternarFavorito(String casaId, String contactoId, bool favorito) async {
    await _col(casaId).doc(contactoId).update({'favorito': favorito});
  }

  static String _soloDigitos(String telefono) => telefono.replaceAll(RegExp(r'[^0-9]'), '');

  /// Mismo contacto ya guardado con ese teléfono (comparado solo por
  /// dígitos, igual que importar_contactos_screen.dart) -- para avisar
  /// antes de crear un duplicado al añadir uno nuevo a mano. [excluirId] es
  /// el propio contacto al editar, para no chocar consigo mismo.
  static Contacto? buscarPorTelefono(
    List<Contacto> contactos,
    String telefono, {
    String? excluirId,
  }) {
    final buscado = _soloDigitos(telefono);
    if (buscado.isEmpty) return null;
    for (final c in contactos) {
      if (c.id == excluirId) continue;
      if (_soloDigitos(c.telefono) == buscado) return c;
    }
    return null;
  }
}
