// test/services/cita_service_test.dart
//
// Agenda del profesional (ampliación REPARA Pro, Fase 4, noviembre 2026):
// escritura directa a Firestore bajo profesionales/{uid}/citas -- crear,
// actualizar, marcar completada y eliminar, y sin uid no se escribe nada
// (mismo criterio que el resto de servicios Pro con este seam).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/cita.dart';
import 'package:repara_core/cita_service.dart';

const _uid = 'pro-1';

void main() {
  tearDown(() {
    CitaService.debugFirestoreOverride = null;
    CitaService.debugUidOverride = null;
  });

  test(
    'crear() guarda la cita bajo profesionales/{uid}/citas y streamCitas() la devuelve',
    () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;

      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Visita de presupuesto',
          fecha: DateTime(2026, 11, 10, 9, 30),
        ),
      );

      final citas = await CitaService.streamCitas().first;
      expect(citas, hasLength(1));
      expect(citas.single.titulo, 'Visita de presupuesto');
      expect(citas.single.todoElDia, isFalse);

      final doc = await db
          .collection('profesionales')
          .doc(_uid)
          .collection('citas')
          .get();
      expect(doc.docs, hasLength(1));
    },
  );

  test('actualizar() cambia los datos de una cita existente', () async {
    final db = FakeFirebaseFirestore();
    CitaService.debugFirestoreOverride = db;
    CitaService.debugUidOverride = _uid;

    await CitaService.crear(
      Cita(id: '', titulo: 'Original', fecha: DateTime(2026, 11, 10)),
    );
    final creada = (await CitaService.streamCitas().first).single;

    await CitaService.actualizar(
      creada.id,
      Cita(
        id: creada.id,
        titulo: 'Actualizada',
        fecha: DateTime(2026, 11, 12),
        todoElDia: true,
      ),
    );

    final citas = await CitaService.streamCitas().first;
    expect(citas.single.titulo, 'Actualizada');
    expect(citas.single.todoElDia, isTrue);
  });

  test('marcarCompletada() solo cambia ese campo', () async {
    final db = FakeFirebaseFirestore();
    CitaService.debugFirestoreOverride = db;
    CitaService.debugUidOverride = _uid;

    await CitaService.crear(
      Cita(id: '', titulo: 'Tarea', fecha: DateTime(2026, 11, 10)),
    );
    final creada = (await CitaService.streamCitas().first).single;
    expect(creada.completada, isFalse);

    await CitaService.marcarCompletada(creada.id, true);

    final citas = await CitaService.streamCitas().first;
    expect(citas.single.completada, isTrue);
    expect(citas.single.titulo, 'Tarea');
  });

  test('eliminar() quita la cita', () async {
    final db = FakeFirebaseFirestore();
    CitaService.debugFirestoreOverride = db;
    CitaService.debugUidOverride = _uid;

    await CitaService.crear(
      Cita(id: '', titulo: 'Para borrar', fecha: DateTime(2026, 11, 10)),
    );
    final creada = (await CitaService.streamCitas().first).single;

    await CitaService.eliminar(creada.id);

    expect(await CitaService.streamCitas().first, isEmpty);
  });

  test(
    'sin uid (sesión cerrada), streamCitas() devuelve vacío y crear()/eliminar() no escriben nada',
    () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = null;

      expect(await CitaService.streamCitas().first, isEmpty);
      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'No debería guardarse',
          fecha: DateTime(2026, 11, 10),
        ),
      );

      final snap = await db.collectionGroup('citas').get();
      expect(snap.docs, isEmpty);
    },
  );

  test(
    'Cita.toMap()/fromDoc() conservan el enlace a un trabajo (casaId/elementoId/registroId)',
    () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;

      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Instalación caldera',
          fecha: DateTime(2026, 11, 15, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r1',
          registroTitulo: 'Instalación caldera',
          casaNombre: 'Casa Norte',
        ),
      );

      final cita = (await CitaService.streamCitas().first).single;
      expect(cita.enlazaTrabajo, isTrue);
      expect(cita.casaId, 'c1');
      expect(cita.registroTitulo, 'Instalación caldera');
    },
  );

  test(
    'compartida es false por defecto y se conserva al guardarla en true (citas compartidas, noviembre 2026)',
    () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;

      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Visita',
          fecha: DateTime(2026, 11, 20, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r1',
          compartida: true,
        ),
      );

      final cita = (await CitaService.streamCitas().first).single;
      expect(cita.compartida, isTrue);
    },
  );

  test(
    'streamCitasCompartidas() solo devuelve, de un profesional concreto y un registro concreto, las que están compartidas',
    () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;

      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Compartida de r1',
          fecha: DateTime(2026, 11, 20, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r1',
          compartida: true,
        ),
      );
      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Privada de r1',
          fecha: DateTime(2026, 11, 21, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r1',
          compartida: false,
        ),
      );
      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Compartida de otro registro',
          fecha: DateTime(2026, 11, 22, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r2',
          compartida: true,
        ),
      );

      final citas = await CitaService.streamCitasCompartidas(
        profesionalUid: _uid,
        registroId: 'r1',
      ).first;
      expect(citas, hasLength(1));
      expect(citas.single.titulo, 'Compartida de r1');
    },
  );

  // CEO, noviembre 2026: "que el propietario pueda responder de verdad" --
  // estado/fechaPropuestaPropietario/horaFinPropuestaPropietario y
  // responderContrapropuesta() (la única escritura de este archivo sobre
  // una contrapropuesta -- confirmar/rechazar/proponer otra fecha del
  // propietario son Cloud Functions, ver cita_service_test no las cubre
  // aquí porque no hay emulador en este target, igual que
  // cambio_alcance_section_test.dart).
  group('estado y contrapropuesta del propietario', () {
    test('estado/fechaPropuesta/horaFinPropuesta se conservan al guardar y leer', () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;

      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Visita',
          fecha: DateTime(2026, 11, 20, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r1',
          compartida: true,
          estado: EstadoCita.contrapropuestaPropietario,
          fechaPropuestaPropietario: DateTime(2026, 11, 21, 11),
          horaFinPropuestaPropietario: DateTime(2026, 11, 21, 12),
        ),
      );

      final cita = (await CitaService.streamCitas().first).single;
      expect(cita.estado, EstadoCita.contrapropuestaPropietario);
      expect(cita.fechaPropuestaPropietario, DateTime(2026, 11, 21, 11));
      expect(cita.horaFinPropuestaPropietario, DateTime(2026, 11, 21, 12));
    });

    test('una cita sin el campo "estado" (guardada antes de que existiera) cae a confirmada, nunca a pendienteConfirmacion', () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;
      // Escritura directa, sin pasar por CitaService.crear() -- simula un
      // documento real guardado antes de que "estado" existiera.
      await db.collection('profesionales').doc(_uid).collection('citas').add({
        'titulo': 'Cita antigua', 'fecha': Timestamp.fromDate(DateTime(2026, 11, 10)), 'compartida': true,
        'casaId': 'c1', 'elementoId': 'e1', 'registroId': 'r1', 'todoElDia': false, 'completada': false,
      });

      final cita = (await CitaService.streamCitas().first).single;
      expect(cita.estado, EstadoCita.confirmada);
    });

    test('responderContrapropuesta(aceptar: true) copia la fecha propuesta y limpia los campos de propuesta', () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;
      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Visita',
          fecha: DateTime(2026, 11, 20, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r1',
          compartida: true,
          estado: EstadoCita.contrapropuestaPropietario,
          fechaPropuestaPropietario: DateTime(2026, 11, 21, 11),
        ),
      );
      final creada = (await CitaService.streamCitas().first).single;

      await CitaService.responderContrapropuesta(citaId: creada.id, aceptar: true);

      final cita = (await CitaService.streamCitas().first).single;
      expect(cita.estado, EstadoCita.confirmada);
      expect(cita.fecha, DateTime(2026, 11, 21, 11));
      expect(cita.fechaPropuestaPropietario, isNull);
      expect(cita.horaFinPropuestaPropietario, isNull);
    });

    test('responderContrapropuesta(aceptar: false) limpia la propuesta y vuelve a pendienteConfirmacion, sin tocar la fecha original', () async {
      final db = FakeFirebaseFirestore();
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;
      await CitaService.crear(
        Cita(
          id: '',
          titulo: 'Visita',
          fecha: DateTime(2026, 11, 20, 10),
          casaId: 'c1',
          elementoId: 'e1',
          registroId: 'r1',
          compartida: true,
          estado: EstadoCita.contrapropuestaPropietario,
          fechaPropuestaPropietario: DateTime(2026, 11, 21, 11),
        ),
      );
      final creada = (await CitaService.streamCitas().first).single;

      await CitaService.responderContrapropuesta(citaId: creada.id, aceptar: false);

      final cita = (await CitaService.streamCitas().first).single;
      expect(cita.estado, EstadoCita.pendienteConfirmacion);
      expect(cita.fecha, DateTime(2026, 11, 20, 10), reason: 'la fecha original del profesional no se toca al declinar');
      expect(cita.fechaPropuestaPropietario, isNull);
    });
  });
}
