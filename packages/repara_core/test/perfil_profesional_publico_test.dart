// packages/repara_core/test/perfil_profesional_publico_test.dart
//
// Mejora de perfiles profesionales (noviembre 2026): fotoUrl/descripcion en
// PerfilProfesionalPublico.fromDoc -- sincronizados por la Cloud Function
// onProfesionalEscritoActualizaPerfilPublico (ver functions/index.js), este
// test solo cubre el parseo del documento ya sincronizado.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/perfil_profesional_publico.dart';

void main() {
  test('PerfilProfesionalPublico.fromDoc() lee fotoUrl/descripcion cuando existen', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('profesionalesPublico').doc('pro-1').set({
      'nombreComercial': 'Fontanería X',
      'fotoUrl': 'https://ejemplo.com/foto.jpg',
      'descripcion': 'Más de 10 años de experiencia.',
    });
    final doc = await db.collection('profesionalesPublico').doc('pro-1').get();
    final perfil = PerfilProfesionalPublico.fromDoc(doc);

    expect(perfil.fotoUrl, 'https://ejemplo.com/foto.jpg');
    expect(perfil.descripcion, 'Más de 10 años de experiencia.');
  });

  test('PerfilProfesionalPublico.fromDoc() deja fotoUrl/descripcion en null si no existen', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('profesionalesPublico').doc('pro-2').set({'nombreComercial': 'Sin foto'});
    final doc = await db.collection('profesionalesPublico').doc('pro-2').get();
    final perfil = PerfilProfesionalPublico.fromDoc(doc);

    expect(perfil.fotoUrl, isNull);
    expect(perfil.descripcion, isNull);
  });
}
