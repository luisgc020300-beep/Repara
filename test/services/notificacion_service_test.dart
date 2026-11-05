// test/services/notificacion_service_test.dart
//
// Centro de notificaciones y preferencias (avisos inteligentes, noviembre
// 2026): "marcar todas como leídas" solo toca el campo leida de cada doc
// (lo único que permite firestore.rules), y las preferencias viven en
// users/{uid}.notifPrefs, con todo activado por defecto cuando no existe
// ninguna clave guardada.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/notificacion_service.dart';

const _uid = 'owner-1';

void main() {
  tearDown(() {
    NotificacionService.debugFirestoreOverride = null;
    NotificacionService.debugUidOverride = null;
  });

  test('marcarTodasLeidas() marca leida=true en todos los ids dados', () async {
    final db = FakeFirebaseFirestore();
    NotificacionService.debugFirestoreOverride = db;
    NotificacionService.debugUidOverride = _uid;

    final ref1 = await db.collection('notificaciones').add({
      'uid': _uid, 'tipo': 'presupuesto_enviado', 'titulo': 't1', 'cuerpo': 'c1', 'leida': false,
    });
    final ref2 = await db.collection('notificaciones').add({
      'uid': _uid, 'tipo': 'pago_registrado', 'titulo': 't2', 'cuerpo': 'c2', 'leida': false,
    });

    await NotificacionService.marcarTodasLeidas([ref1.id, ref2.id]);

    final notis = await NotificacionService.streamMisNotificaciones().first;
    expect(notis.every((n) => n.leida), isTrue);
  });

  test('marcarTodasLeidas() con lista vacía no hace ninguna escritura', () async {
    final db = FakeFirebaseFirestore();
    NotificacionService.debugFirestoreOverride = db;
    NotificacionService.debugUidOverride = _uid;

    await NotificacionService.marcarTodasLeidas([]);

    final snap = await db.collection('notificaciones').get();
    expect(snap.docs, isEmpty);
  });

  test('streamPreferencias() devuelve vacío cuando el usuario no ha guardado ninguna preferencia', () async {
    final db = FakeFirebaseFirestore();
    NotificacionService.debugFirestoreOverride = db;
    NotificacionService.debugUidOverride = _uid;
    await db.collection('users').doc(_uid).set({'activeCasaId': 'c1'});

    final prefs = await NotificacionService.streamPreferencias().first;
    expect(prefs, isEmpty);
  });

  test('actualizarPreferencia() guarda la clave sin pisar las demás ya guardadas', () async {
    final db = FakeFirebaseFirestore();
    NotificacionService.debugFirestoreOverride = db;
    NotificacionService.debugUidOverride = _uid;

    await NotificacionService.actualizarPreferencia('presupuestos', false);
    await NotificacionService.actualizarPreferencia('pushHabilitado', false);

    final prefs = await NotificacionService.streamPreferencias().first;
    expect(prefs['presupuestos'], isFalse);
    expect(prefs['pushHabilitado'], isFalse);
  });
}
