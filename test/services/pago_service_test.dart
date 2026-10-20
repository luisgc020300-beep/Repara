// test/services/pago_service_test.dart
//
// Contra un Firestore falso (fake_cloud_firestore), nunca Firebase real.
// crear()/actualizar() ya no se prueban aquí: desde la corrección DATA-1 de
// integridad económica (octubre 2026) pasan por Cloud Function
// (registrarPago/actualizarPago), que no se puede fakear en este repo (ver
// pago_service.dart). Esa lógica -- incluida la comprobación de que
// createdBy viene siempre del uid autenticado, nunca de la petición -- se
// prueba contra el emulador en functions-tests/payments.test.js. Aquí solo
// se cubren los métodos de solo lectura, que siguen siendo Firestore
// directo, sembrando el Firestore falso a mano en vez de con crear().
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repara/services/pago_service.dart';

void main() {
  const casaId = 'casa-1';
  const elementoId = 'elemento-1';
  const registroId = 'registro-1';

  tearDown(() {
    PagoService.debugFirestoreOverride = null;
  });

  CollectionReference<Map<String, dynamic>> pagosCol(FakeFirebaseFirestore db) => db
      .collection('casas')
      .doc(casaId)
      .collection('elementos')
      .doc(elementoId)
      .collection('registros')
      .doc(registroId)
      .collection('pagos');

  test('streamPagos() devuelve los pagos del registro ordenados por fecha descendente', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;

    await pagosCol(db).add({'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)), 'importe': 10, 'createdBy': 'owner-a'});
    await pagosCol(db).add({'fecha': Timestamp.fromDate(DateTime(2026, 3, 1)), 'importe': 20, 'createdBy': 'owner-a'});

    final pagos = await PagoService.streamPagos(casaId, elementoId, registroId).first;
    expect(pagos, hasLength(2));
    expect(pagos.first.importe, 20); // el más reciente primero
  });

  test('totalPagado() suma el importe de todos los pagos del registro', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;

    await pagosCol(db).add({'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)), 'importe': 30, 'createdBy': 'owner-a'});
    await pagosCol(db).add({'fecha': Timestamp.fromDate(DateTime(2026, 2, 1)), 'importe': 15.5, 'createdBy': 'owner-a'});

    final total = await PagoService.totalPagado(casaId, elementoId, registroId);
    expect(total, 45.5);
  });

  test('obtenerPago() lee un pago concreto por id', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;

    final ref = await pagosCol(db).add({'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)), 'importe': 12, 'createdBy': 'owner-a'});

    final pago = await PagoService.obtenerPago(casaId, elementoId, registroId, ref.id);
    expect(pago, isNotNull);
    expect(pago!.importe, 12);
  });
}
