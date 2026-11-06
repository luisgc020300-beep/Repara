// test/services/trabajo_profesional_service_test.dart
//
// Trabajos privados del profesional (Fase 1, noviembre 2026): escritura
// directa a Firestore bajo profesionales/{uid}/trabajosPro -- crear,
// listar (todos y por cliente), actualizar estado, eliminar y aislamiento
// por uid (mismo criterio que cliente_profesional_service_test.dart).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_pro/models/trabajo_profesional.dart';
import 'package:repara_pro/services/trabajo_profesional_service.dart';
import 'package:repara_core/registro.dart';

const _uid = 'pro-1';
const _otroUid = 'pro-2';

TrabajoProfesional _trabajo({
  String clienteId = 'cliente-1',
  String clienteNombre = 'María López',
  String titulo = 'Cambiar grifo',
  EstadoTrabajoProfesional estado = EstadoTrabajoProfesional.abierto,
}) => TrabajoProfesional(
  id: '',
  clienteId: clienteId,
  clienteNombre: clienteNombre,
  titulo: titulo,
  tipo: TipoRegistro.reparacion,
  estado: estado,
);

void main() {
  tearDown(() {
    TrabajoProfesionalService.debugFirestoreOverride = null;
    TrabajoProfesionalService.debugUidOverride = null;
  });

  test(
    'crear() guarda el trabajo bajo profesionales/{uid}/trabajosPro y streamTrabajos() lo devuelve',
    () async {
      final db = FakeFirebaseFirestore();
      TrabajoProfesionalService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugUidOverride = _uid;

      final id = await TrabajoProfesionalService.crear(_trabajo());
      expect(id, isNotNull);

      final trabajos = await TrabajoProfesionalService.streamTrabajos().first;
      expect(trabajos, hasLength(1));
      expect(trabajos.single.titulo, 'Cambiar grifo');
      expect(trabajos.single.estado, EstadoTrabajoProfesional.abierto);

      final doc = await db
          .collection('profesionales')
          .doc(_uid)
          .collection('trabajosPro')
          .get();
      expect(doc.docs, hasLength(1));
    },
  );

  test(
    'streamTrabajosDeCliente() solo devuelve los trabajos de ese cliente',
    () async {
      final db = FakeFirebaseFirestore();
      TrabajoProfesionalService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugUidOverride = _uid;

      await TrabajoProfesionalService.crear(
        _trabajo(clienteId: 'cliente-1', titulo: 'Trabajo de cliente 1'),
      );
      await TrabajoProfesionalService.crear(
        _trabajo(clienteId: 'cliente-2', titulo: 'Trabajo de cliente 2'),
      );

      final deCliente1 = await TrabajoProfesionalService.streamTrabajosDeCliente(
        'cliente-1',
      ).first;
      expect(deCliente1, hasLength(1));
      expect(deCliente1.single.titulo, 'Trabajo de cliente 1');
    },
  );

  test('actualizar() cambia los datos de un trabajo existente', () async {
    final db = FakeFirebaseFirestore();
    TrabajoProfesionalService.debugFirestoreOverride = db;
    TrabajoProfesionalService.debugUidOverride = _uid;

    final id = await TrabajoProfesionalService.crear(_trabajo());
    await TrabajoProfesionalService.actualizar(
      id!,
      _trabajo(titulo: 'Cambiar grifo y sifón', estado: EstadoTrabajoProfesional.enCurso),
    );

    final trabajos = await TrabajoProfesionalService.streamTrabajos().first;
    expect(trabajos.single.titulo, 'Cambiar grifo y sifón');
    expect(trabajos.single.estado, EstadoTrabajoProfesional.enCurso);
  });

  test('actualizarEstado() solo cambia ese campo', () async {
    final db = FakeFirebaseFirestore();
    TrabajoProfesionalService.debugFirestoreOverride = db;
    TrabajoProfesionalService.debugUidOverride = _uid;

    final id = await TrabajoProfesionalService.crear(_trabajo());
    await TrabajoProfesionalService.actualizarEstado(
      id!,
      EstadoTrabajoProfesional.terminado,
    );

    final trabajos = await TrabajoProfesionalService.streamTrabajos().first;
    expect(trabajos.single.estado, EstadoTrabajoProfesional.terminado);
    expect(trabajos.single.titulo, 'Cambiar grifo');
  });

  test('eliminar() quita el trabajo', () async {
    final db = FakeFirebaseFirestore();
    TrabajoProfesionalService.debugFirestoreOverride = db;
    TrabajoProfesionalService.debugUidOverride = _uid;

    final id = await TrabajoProfesionalService.crear(_trabajo());
    await TrabajoProfesionalService.eliminar(id!);

    expect(await TrabajoProfesionalService.streamTrabajos().first, isEmpty);
  });

  test(
    'un profesional nunca ve los trabajos privados de otro profesional',
    () async {
      final db = FakeFirebaseFirestore();
      TrabajoProfesionalService.debugFirestoreOverride = db;

      TrabajoProfesionalService.debugUidOverride = _uid;
      await TrabajoProfesionalService.crear(
        _trabajo(titulo: 'Trabajo de pro-1'),
      );

      TrabajoProfesionalService.debugUidOverride = _otroUid;
      await TrabajoProfesionalService.crear(
        _trabajo(titulo: 'Trabajo de pro-2'),
      );

      final deOtro = await TrabajoProfesionalService.streamTrabajos().first;
      expect(deOtro, hasLength(1));
      expect(deOtro.single.titulo, 'Trabajo de pro-2');
    },
  );

  test(
    'sin uid (sesión cerrada), streamTrabajos() devuelve vacío y crear() no escribe nada',
    () async {
      final db = FakeFirebaseFirestore();
      TrabajoProfesionalService.debugFirestoreOverride = db;
      TrabajoProfesionalService.debugUidOverride = null;

      expect(await TrabajoProfesionalService.streamTrabajos().first, isEmpty);
      final id = await TrabajoProfesionalService.crear(
        _trabajo(titulo: 'No debería guardarse'),
      );
      expect(id, isNull);

      final snap = await db.collectionGroup('trabajosPro').get();
      expect(snap.docs, isEmpty);
    },
  );
}
