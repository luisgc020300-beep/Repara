// test/services/registro_service_saldo_pendiente_test.dart
//
// RegistroService.tieneSaldoPendiente() (auditoría R6, octubre 2026): misma
// fórmula y misma tolerancia (0.01) que el servidor (tieneSaldoPendiente en
// functions/index.js), usada aquí solo como ayuda visual -- comprobada de
// forma aislada, sin pasar por ningún widget. Usa FakeFirebaseFirestore,
// nada de Firebase real.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/registro.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/registro_service.dart';

Registro _registro({required String id, double? presupuesto}) => Registro(
  id: id,
  elementoNombre: 'Caldera',
  tipo: TipoRegistro.reparacion,
  esConProfesional: true,
  titulo: 'Reparación',
  estado: EstadoRegistro.terminado,
  fecha: DateTime(2026, 1, 1),
  presupuesto: presupuesto,
);

void main() {
  tearDown(() {
    RegistroService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
  });

  test('un registro sin presupuesto (null) nunca cuenta como saldo pendiente', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;

    final resultado = await RegistroService.tieneSaldoPendiente('c1', 'e1', [
      _registro(id: 'r1', presupuesto: null),
    ]);
    expect(resultado, isFalse);
  });

  test('sin ningún pago registrado, un presupuesto positivo es saldo pendiente', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;

    final resultado = await RegistroService.tieneSaldoPendiente('c1', 'e1', [
      _registro(id: 'r1', presupuesto: 100),
    ]);
    expect(resultado, isTrue);
  });

  test('pagos parciales que no cubren el presupuesto siguen siendo saldo pendiente', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;
    await db
        .collection('casas').doc('c1')
        .collection('elementos').doc('e1')
        .collection('registros').doc('r1')
        .collection('pagos').add({'importe': 30, 'fecha': Timestamp.fromDate(DateTime(2026, 1, 2))});
    await db
        .collection('casas').doc('c1')
        .collection('elementos').doc('e1')
        .collection('registros').doc('r1')
        .collection('pagos').add({'importe': 20, 'fecha': Timestamp.fromDate(DateTime(2026, 1, 3))});

    final resultado = await RegistroService.tieneSaldoPendiente('c1', 'e1', [
      _registro(id: 'r1', presupuesto: 100),
    ]);
    expect(resultado, isTrue, reason: '30 + 20 = 50 de 100 -- quedan 50 pendientes');
  });

  test('pagos que suman exactamente el presupuesto ya no cuentan como pendiente', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;
    await db
        .collection('casas').doc('c1')
        .collection('elementos').doc('e1')
        .collection('registros').doc('r1')
        .collection('pagos').add({'importe': 60, 'fecha': Timestamp.fromDate(DateTime(2026, 1, 2))});
    await db
        .collection('casas').doc('c1')
        .collection('elementos').doc('e1')
        .collection('registros').doc('r1')
        .collection('pagos').add({'importe': 40, 'fecha': Timestamp.fromDate(DateTime(2026, 1, 3))});

    final resultado = await RegistroService.tieneSaldoPendiente('c1', 'e1', [
      _registro(id: 'r1', presupuesto: 100),
    ]);
    expect(resultado, isFalse);
  });

  test('si cualquiera de varios registros tiene saldo pendiente, el resultado es true', () async {
    final db = FakeFirebaseFirestore();
    PagoService.debugFirestoreOverride = db;
    await db
        .collection('casas').doc('c1')
        .collection('elementos').doc('e1')
        .collection('registros').doc('r1')
        .collection('pagos').add({'importe': 100, 'fecha': Timestamp.fromDate(DateTime(2026, 1, 2))});
    // r2 no tiene ningún pago registrado todavía.

    final resultado = await RegistroService.tieneSaldoPendiente('c1', 'e1', [
      _registro(id: 'r1', presupuesto: 100),
      _registro(id: 'r2', presupuesto: 50),
    ]);
    expect(resultado, isTrue);
  });
}
