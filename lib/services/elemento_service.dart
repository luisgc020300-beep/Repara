// lib/services/elemento_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/elemento.dart';

class ElementoService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col(String casaId) =>
      _db.collection('casas').doc(casaId).collection('elementos');

  static Stream<List<Elemento>> streamElementos(String casaId, {String? habitacionId}) {
    Query<Map<String, dynamic>> q = _col(casaId);
    if (habitacionId != null) q = q.where('habitacionId', isEqualTo: habitacionId);
    return q.snapshots().map((s) => s.docs.map(Elemento.fromDoc).toList());
  }

  static Stream<Elemento?> streamElemento(String casaId, String elementoId) {
    return _col(casaId).doc(elementoId).snapshots().map((d) => d.exists ? Elemento.fromDoc(d) : null);
  }

  static Future<String> crear(String casaId, Elemento elemento) async {
    final ref = await _col(casaId).add({
      ...elemento.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> actualizar(String casaId, String elementoId, Elemento elemento) async {
    await _col(casaId).doc(elementoId).update(elemento.toMap());
  }

  static Future<void> eliminar(String casaId, String elementoId) async {
    await _col(casaId).doc(elementoId).delete();
  }

  /// Elementos con garantía a menos de 30 días -- usado en el dashboard de
  /// Inicio (sección 25 del spec: avisar de garantías próximas a vencer).
  static Future<List<Elemento>> conGarantiaProximaAVencer(String casaId) async {
    final snap = await _col(casaId).get();
    return snap.docs.map(Elemento.fromDoc).where((e) => e.garantiaProximaAVencer).toList();
  }
}
