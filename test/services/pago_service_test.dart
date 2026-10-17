// test/services/pago_service_test.dart
//
// Contra un Firestore falso (fake_cloud_firestore), nunca Firebase real --
// ver pago_service.dart para los seams de solo test (debugFirestoreOverride/
// debugUidOverride). Cubre sobre todo crear(), que es el camino relacionado
// con el fix de seguridad de octubre 2026 (createdBy debe venir siempre del
// usuario autenticado, nunca de lo que mande la UI).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repara/models/pago.dart';
import 'package:repara/services/pago_service.dart';

void main() {
  const casaId = 'casa-1';
  const elementoId = 'elemento-1';
  const registroId = 'registro-1';

  tearDown(() {
    PagoService.debugFirestoreOverride = null;
    PagoService.debugUidOverride = null;
  });

  test('crear() guarda createdBy a partir del uid autenticado, nunca de un valor externo', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;
    PagoService.debugUidOverride = 'owner-a';

    await PagoService.crear(casaId, elementoId, registroId, Pago(id: '', fecha: DateTime(2026, 1, 1), importe: 50));

    final snap = await db
        .collection('casas')
        .doc(casaId)
        .collection('elementos')
        .doc(elementoId)
        .collection('registros')
        .doc(registroId)
        .collection('pagos')
        .get();
    expect(snap.docs, hasLength(1));
    expect(snap.docs.first.data()['createdBy'], 'owner-a');
    expect(snap.docs.first.data()['importe'], 50);
  });

  test('streamPagos() devuelve los pagos del registro ordenados por fecha descendente', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;
    PagoService.debugUidOverride = 'owner-a';

    await PagoService.crear(casaId, elementoId, registroId, Pago(id: '', fecha: DateTime(2026, 1, 1), importe: 10));
    await PagoService.crear(casaId, elementoId, registroId, Pago(id: '', fecha: DateTime(2026, 3, 1), importe: 20));

    final pagos = await PagoService.streamPagos(casaId, elementoId, registroId).first;
    expect(pagos, hasLength(2));
    expect(pagos.first.importe, 20); // el más reciente primero
  });

  test('totalPagado() suma el importe de todos los pagos del registro', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;
    PagoService.debugUidOverride = 'owner-a';

    await PagoService.crear(casaId, elementoId, registroId, Pago(id: '', fecha: DateTime(2026, 1, 1), importe: 30));
    await PagoService.crear(casaId, elementoId, registroId, Pago(id: '', fecha: DateTime(2026, 2, 1), importe: 15.5));

    final total = await PagoService.totalPagado(casaId, elementoId, registroId);
    expect(total, 45.5);
  });
}
