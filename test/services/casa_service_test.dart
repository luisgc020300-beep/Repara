// test/services/casa_service_test.dart
//
// Contra un Firestore falso, ver casa_service.dart para los seams
// (debugFirestoreOverride/debugUidOverride). No cubre createCasa/joinCasa/
// cambiarCasaActiva/sincronizarClaims -- son Cloud Functions, sin seam para
// fakearlas en este repo.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repara/services/casa_service.dart';

void main() {
  tearDown(() {
    CasaService.debugFirestoreOverride = null;
    CasaService.debugUidOverride = null;
  });

  test('streamActiveCasaId() devuelve null sin lanzar si no hay uid (usuario deslogueado)', () async {
    CasaService.debugFirestoreOverride = FakeFirebaseFirestore();
    CasaService.debugUidOverride = null;
    final id = await CasaService.streamActiveCasaId().first;
    expect(id, isNull);
  });

  test('streamActiveCasaId() lee activeCasaId del documento de usuario', () async {
    final db = FakeFirebaseFirestore();
    CasaService.debugFirestoreOverride = db;
    CasaService.debugUidOverride = 'owner-a';
    await db.collection('users').doc('owner-a').set({'activeCasaId': 'casa-1', 'casaIds': ['casa-1']});

    final id = await CasaService.streamActiveCasaId().first;
    expect(id, 'casa-1');
  });

  test('streamCasaIds() devuelve lista vacía sin uid, nunca null ni excepción', () async {
    CasaService.debugFirestoreOverride = FakeFirebaseFirestore();
    CasaService.debugUidOverride = null;
    final ids = await CasaService.streamCasaIds().first;
    expect(ids, isEmpty);
  });

  test('renombrarCasa() solo toca el campo nombre', () async {
    final db = FakeFirebaseFirestore();
    CasaService.debugFirestoreOverride = db;
    await db.collection('casas').doc('casa-1').set({'nombre': 'Casa vieja', 'ownerUid': 'owner-a', 'members': ['owner-a']});

    await CasaService.renombrarCasa('casa-1', 'Casa nueva');

    final casa = await CasaService.obtenerCasa('casa-1');
    expect(casa!.nombre, 'Casa nueva');
    expect(casa.ownerUid, 'owner-a'); // intacto
  });
}
