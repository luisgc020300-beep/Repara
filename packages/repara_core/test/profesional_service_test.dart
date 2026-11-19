// packages/repara_core/test/profesional_service_test.dart
//
// Mejora de perfiles profesionales (noviembre 2026): fotoUrl/descripcion en
// Profesional.fromDoc y en ProfesionalService.actualizarPerfil/actualizarFoto.
// Primer test directo de este servicio -- hasta ahora solo se ejercitaba
// indirectamente desde tests de pantalla (ver apps/repara_pro/test/screens/
// activar_profesional_gate_screen_test.dart para el mismo seam de
// debugFirestoreOverride/debugUidOverride).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/profesional.dart';
import 'package:repara_core/profesional_service.dart';

const _uid = 'pro-1';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    ProfesionalService.debugFirestoreOverride = db;
    ProfesionalService.debugUidOverride = _uid;
  });

  tearDown(() {
    ProfesionalService.debugFirestoreOverride = null;
    ProfesionalService.debugUidOverride = null;
  });

  test('actualizarPerfil() guarda nombreComercial/especialidad/telefono/descripcion', () async {
    await ProfesionalService.actualizarPerfil(
      nombreComercial: 'Fontanería X',
      especialidad: 'Fontanero',
      telefono: '600111222',
      descripcion: 'Más de 10 años de experiencia en fontanería.',
    );

    final perfil = await ProfesionalService.streamPerfilPropio().first;
    expect(perfil, isNotNull);
    expect(perfil!.nombreComercial, 'Fontanería X');
    expect(perfil.especialidad, 'Fontanero');
    expect(perfil.telefono, '600111222');
    expect(perfil.descripcion, 'Más de 10 años de experiencia en fontanería.');
  });

  test('actualizarPerfil() con un solo campo no borra los demás ya guardados', () async {
    await ProfesionalService.actualizarPerfil(nombreComercial: 'Fontanería X');
    await ProfesionalService.actualizarPerfil(descripcion: 'Trabajo limpio y puntual.');

    final perfil = await ProfesionalService.streamPerfilPropio().first;
    expect(perfil!.nombreComercial, 'Fontanería X');
    expect(perfil.descripcion, 'Trabajo limpio y puntual.');
  });

  test('actualizarFoto() guarda la URL y actualizarFoto(null) la borra', () async {
    await ProfesionalService.actualizarFoto('https://ejemplo.com/foto.jpg');
    var perfil = await ProfesionalService.streamPerfilPropio().first;
    expect(perfil!.fotoUrl, 'https://ejemplo.com/foto.jpg');

    await ProfesionalService.actualizarFoto(null);
    perfil = await ProfesionalService.streamPerfilPropio().first;
    expect(perfil!.fotoUrl, isNull);
  });

  test('Profesional.fromDoc() lee fotoUrl/descripcion cuando existen, null si no', () async {
    await db.collection('profesionales').doc(_uid).set({
      'nombreComercial': 'Electricidad Y',
      'fotoUrl': 'https://ejemplo.com/foto.jpg',
      'descripcion': 'Instalaciones eléctricas residenciales.',
    });
    final doc = await db.collection('profesionales').doc(_uid).get();
    final perfil = Profesional.fromDoc(doc);
    expect(perfil.fotoUrl, 'https://ejemplo.com/foto.jpg');
    expect(perfil.descripcion, 'Instalaciones eléctricas residenciales.');

    await db.collection('profesionales').doc('pro-sin-foto').set({'nombreComercial': 'Sin foto'});
    final docSinFoto = await db.collection('profesionales').doc('pro-sin-foto').get();
    final perfilSinFoto = Profesional.fromDoc(docSinFoto);
    expect(perfilSinFoto.fotoUrl, isNull);
    expect(perfilSinFoto.descripcion, isNull);
  });
}
