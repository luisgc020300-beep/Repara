// test/services/invitacion_hogar_service_test.dart
//
// Fase 2 (noviembre 2026). Solo streamPendientesParaMi() se prueba aquí --
// es una consulta Firestore pura, testeable con FakeFirebaseFirestore. Los
// 3 métodos restantes (canjearCodigo/responder, vía FirebaseFunctions.
// httpsCallable) se prueban contra el emulador real en
// functions-tests/invitacion_hogar.test.js -- mismo criterio que
// InvitacionService, que tampoco tiene test Dart propio para sus llamadas a
// Cloud Functions.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/services/invitacion_hogar_service.dart';

void main() {
  tearDown(() {
    InvitacionHogarService.debugFirestoreOverride = null;
    InvitacionHogarService.debugUidOverride = null;
  });

  test('streamPendientesParaMi() solo devuelve las pendientes de este propietario', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('invitacionesHogar').add({
      'propietarioUid': 'owner-1', 'profesionalUid': 'pro-1', 'titulo': 'Mía, pendiente', 'estado': 'pendiente',
    });
    await db.collection('invitacionesHogar').add({
      'propietarioUid': 'owner-1', 'profesionalUid': 'pro-1', 'titulo': 'Mía, ya aceptada', 'estado': 'aceptada',
    });
    await db.collection('invitacionesHogar').add({
      'propietarioUid': 'owner-2', 'profesionalUid': 'pro-1', 'titulo': 'De otro propietario', 'estado': 'pendiente',
    });
    InvitacionHogarService.debugFirestoreOverride = db;
    InvitacionHogarService.debugUidOverride = 'owner-1';

    final lista = await InvitacionHogarService.streamPendientesParaMi().first;

    expect(lista.length, 1);
    expect(lista.single.titulo, 'Mía, pendiente');
  });

  test('sin sesión (uid null), devuelve vacío sin leer Firestore', () async {
    InvitacionHogarService.debugFirestoreOverride = FakeFirebaseFirestore();
    InvitacionHogarService.debugUidOverride = null;

    final lista = await InvitacionHogarService.streamPendientesParaMi().first;

    expect(lista, isEmpty);
  });
}
