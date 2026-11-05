// test/services/cliente_profesional_service_test.dart
//
// Clientes privados del profesional (Fase 1, noviembre 2026): escritura
// directa a Firestore bajo profesionales/{uid}/clientesPro -- crear,
// actualizar, eliminar y aislamiento por uid (mismo criterio que
// cita_service_test.dart).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/cliente_profesional.dart';
import 'package:repara/services/cliente_profesional_service.dart';

const _uid = 'pro-1';
const _otroUid = 'pro-2';

void main() {
  tearDown(() {
    ClienteProfesionalService.debugFirestoreOverride = null;
    ClienteProfesionalService.debugUidOverride = null;
  });

  test(
    'crear() guarda el cliente bajo profesionales/{uid}/clientesPro y streamClientes() lo devuelve',
    () async {
      final db = FakeFirebaseFirestore();
      ClienteProfesionalService.debugFirestoreOverride = db;
      ClienteProfesionalService.debugUidOverride = _uid;

      final id = await ClienteProfesionalService.crear(
        const ClienteProfesional(id: '', nombre: 'María López'),
      );
      expect(id, isNotNull);

      final clientes = await ClienteProfesionalService.streamClientes().first;
      expect(clientes, hasLength(1));
      expect(clientes.single.nombre, 'María López');

      final doc = await db
          .collection('profesionales')
          .doc(_uid)
          .collection('clientesPro')
          .get();
      expect(doc.docs, hasLength(1));
    },
  );

  test('actualizar() cambia los datos de un cliente existente', () async {
    final db = FakeFirebaseFirestore();
    ClienteProfesionalService.debugFirestoreOverride = db;
    ClienteProfesionalService.debugUidOverride = _uid;

    final id = await ClienteProfesionalService.crear(
      const ClienteProfesional(id: '', nombre: 'Original'),
    );

    await ClienteProfesionalService.actualizar(
      id!,
      const ClienteProfesional(
        id: '',
        nombre: 'Actualizado',
        telefono: '600111222',
      ),
    );

    final clientes = await ClienteProfesionalService.streamClientes().first;
    expect(clientes.single.nombre, 'Actualizado');
    expect(clientes.single.telefono, '600111222');
  });

  test('eliminar() quita el cliente', () async {
    final db = FakeFirebaseFirestore();
    ClienteProfesionalService.debugFirestoreOverride = db;
    ClienteProfesionalService.debugUidOverride = _uid;

    final id = await ClienteProfesionalService.crear(
      const ClienteProfesional(id: '', nombre: 'Para borrar'),
    );
    await ClienteProfesionalService.eliminar(id!);

    expect(await ClienteProfesionalService.streamClientes().first, isEmpty);
  });

  test(
    'un profesional nunca ve los clientes privados de otro profesional',
    () async {
      final db = FakeFirebaseFirestore();
      ClienteProfesionalService.debugFirestoreOverride = db;

      ClienteProfesionalService.debugUidOverride = _uid;
      await ClienteProfesionalService.crear(
        const ClienteProfesional(id: '', nombre: 'Cliente de pro-1'),
      );

      ClienteProfesionalService.debugUidOverride = _otroUid;
      await ClienteProfesionalService.crear(
        const ClienteProfesional(id: '', nombre: 'Cliente de pro-2'),
      );

      final deOtro = await ClienteProfesionalService.streamClientes().first;
      expect(deOtro, hasLength(1));
      expect(deOtro.single.nombre, 'Cliente de pro-2');

      ClienteProfesionalService.debugUidOverride = _uid;
      final deUno = await ClienteProfesionalService.streamClientes().first;
      expect(deUno, hasLength(1));
      expect(deUno.single.nombre, 'Cliente de pro-1');
    },
  );

  test(
    'sin uid (sesión cerrada), streamClientes() devuelve vacío y crear() no escribe nada',
    () async {
      final db = FakeFirebaseFirestore();
      ClienteProfesionalService.debugFirestoreOverride = db;
      ClienteProfesionalService.debugUidOverride = null;

      expect(await ClienteProfesionalService.streamClientes().first, isEmpty);
      final id = await ClienteProfesionalService.crear(
        const ClienteProfesional(id: '', nombre: 'No debería guardarse'),
      );
      expect(id, isNull);

      final snap = await db.collectionGroup('clientesPro').get();
      expect(snap.docs, isEmpty);
    },
  );
}
