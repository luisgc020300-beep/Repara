// packages/repara_core/test/cuenta_service_test.dart
//
// Mejora de perfiles (noviembre 2026): descripción personal, visible solo en
// la propia CuentaScreen de Hogar (ver CuentaScreen.permitirEditarDescripcion).
// Escritura directa a users/{uid} -- no pasa por Cloud Function porque, a
// diferencia de displayName, no se copia en memberProfiles de ninguna casa.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/cuenta_service.dart';

const _uid = 'owner-1';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    CuentaService.debugFirestoreOverride = db;
  });

  tearDown(() {
    CuentaService.debugFirestoreOverride = null;
  });

  test('streamDescripcionPerfil() es null mientras no se ha guardado nada', () async {
    final descripcion = await CuentaService.streamDescripcionPerfil(_uid).first;
    expect(descripcion, isNull);
  });

  test('actualizarDescripcionPerfil() guarda la descripción y streamDescripcionPerfil() la refleja', () async {
    await CuentaService.actualizarDescripcionPerfil(_uid, 'Encantado de conocerte.');

    final descripcion = await CuentaService.streamDescripcionPerfil(_uid).first;
    expect(descripcion, 'Encantado de conocerte.');
  });

  test('actualizarDescripcionPerfil() no borra otros campos ya guardados en users/{uid}', () async {
    await db.collection('users').doc(_uid).set({'displayName': 'Ana', 'activeCasaId': 'casa-1'});

    await CuentaService.actualizarDescripcionPerfil(_uid, 'Vivo aquí desde 2020.');

    final doc = await db.collection('users').doc(_uid).get();
    expect(doc.data()?['displayName'], 'Ana');
    expect(doc.data()?['activeCasaId'], 'casa-1');
    expect(doc.data()?['descripcion'], 'Vivo aquí desde 2020.');
  });
}
