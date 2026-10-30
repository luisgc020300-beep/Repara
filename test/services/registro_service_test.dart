// test/services/registro_service_test.dart
//
// Contra un Firestore falso, ver registro_service.dart para el seam
// (debugFirestoreOverride). No cubre las Cloud Functions de
// finalizar/marcarFinalizadoProfesional/rechazarFinalizacionProfesional --
// esas solo existen en functions/index.js, fuera del alcance de un test
// Dart.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repara/models/registro.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/registro_service.dart';

void main() {
  const casaId = 'casa-1';
  const elementoId = 'elemento-1';

  tearDown(() {
    RegistroService.debugFirestoreOverride = null;
    ElementoService.debugFirestoreOverride = null;
  });

  Registro registro({
    String titulo = 'Avería',
    EstadoRegistro estado = EstadoRegistro.nuevo,
  }) => Registro(
    id: '',
    elementoNombre: 'Caldera',
    tipo: TipoRegistro.averia,
    esConProfesional: false,
    titulo: titulo,
    estado: estado,
    fecha: DateTime(2026, 1, 1),
  );

  test(
    'crear() guarda casaId y createdBy además de los campos del registro',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;

      final id = await RegistroService.crear(
        casaId,
        elementoId,
        registro(),
        createdBy: 'owner-a',
      );

      final doc = await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .doc(id)
          .get();
      expect(doc.data()!['casaId'], casaId);
      expect(doc.data()!['createdBy'], 'owner-a');
      expect(doc.data()!['titulo'], 'Avería');
    },
  );

  test(
    'streamRegistros() devuelve los registros del elemento ordenados por fecha descendente',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;

      await RegistroService.crear(
        casaId,
        elementoId,
        registro(titulo: 'Antiguo'),
        createdBy: 'owner-a',
      );
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(titulo: 'Reciente').toMap(),
            'fecha': Timestamp.fromDate(DateTime(2026, 6, 1)),
          });

      final registros = await RegistroService.streamRegistros(
        casaId,
        elementoId,
      ).first;
      expect(registros, hasLength(2));
      expect(registros.first.titulo, 'Reciente');
    },
  );

  test('actualizarEstado() cambia solo el campo estado', () async {
    final db = FakeFirebaseFirestore();
    RegistroService.debugFirestoreOverride = db;
    final id = await RegistroService.crear(
      casaId,
      elementoId,
      registro(),
      createdBy: 'owner-a',
    );

    await RegistroService.actualizarEstado(
      casaId,
      elementoId,
      id,
      EstadoRegistro.enCurso,
    );

    final actualizado = await RegistroService.streamRegistro(
      casaId,
      elementoId,
      id,
    ).first;
    expect(actualizado!.estado, EstadoRegistro.enCurso);
    expect(actualizado.titulo, 'Avería'); // el resto de campos no se toca
  });

  test(
    'registrosConTrabajoPendiente() cuenta registros con profesional sin cerrar',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Caldera', 'createdAt': Timestamp.now()});
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.enCurso).toMap(),
            'esConProfesional': true,
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 1)),
          });
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.terminado).toMap(),
            'esConProfesional': true,
            'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      final pendientes = await RegistroService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(
        pendientes,
        hasLength(1),
      ); // el terminado no cuenta, el en curso sí
    },
  );

  // CEO, octubre 2026: "Trabajos pendientes" (Inicio) mostraba siempre el
  // icono genérico, aunque el registro tuviera foto -- faltaba propagar
  // r.fotos (fotoUrl heredado o fotoUrls nuevo) en el record que alimenta
  // esa pantalla.
  test(
    'registrosConTrabajoPendiente() propaga la primera foto del registro, con fotoUrl heredado o con fotoUrls',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Pérgolas', 'createdAt': Timestamp.now()});
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.enCurso).toMap(),
            'esConProfesional': true,
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 1)),
            'fotoUrl': 'https://example.com/antigua.jpg',
          });
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.pendientePago).toMap(),
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 2)),
            'fotoUrls': [
              'https://example.com/primera.jpg',
              'https://example.com/segunda.jpg',
            ],
          });

      final pendientes = await RegistroService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(pendientes, hasLength(2));
      expect(pendientes[0].fotoUrl, 'https://example.com/antigua.jpg');
      expect(pendientes[1].fotoUrl, 'https://example.com/primera.jpg');
    },
  );

  // CEO, octubre 2026: antes, un elemento con varios registros pendientes a
  // la vez (p.ej. dos instalaciones y una reforma sobre "Pérgolas") solo
  // mostraba el más antiguo -- el resto desaparecía del aviso de Inicio sin
  // ningún indicio de que había más. Ahora cuenta cada registro pendiente
  // por separado, aunque compartan elemento.
  test(
    'registrosConTrabajoPendiente() cuenta CADA registro pendiente, no solo uno por elemento',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Pérgolas', 'createdAt': Timestamp.now()});
      final registros = db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros');
      await registros.add({
        ...registro(
          titulo: 'Reforma/Mejora',
          estado: EstadoRegistro.enCurso,
        ).toMap(),
        'esConProfesional': true,
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
      });
      await registros.add({
        ...registro(
          titulo: 'Instalación placa de madera',
          estado: EstadoRegistro.pendientePago,
        ).toMap(),
        'esConProfesional': false,
        'coste': 2000,
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 30)),
      });
      await registros.add({
        ...registro(
          titulo: 'Instalación placa de metal',
          estado: EstadoRegistro.pendientePago,
        ).toMap(),
        'esConProfesional': false,
        'coste': 2000,
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 31)),
      });

      final pendientes = await RegistroService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(pendientes, hasLength(3));
      expect(pendientes.map((p) => p.registroTitulo), [
        'Reforma/Mejora', // la más antigua sale primero
        'Instalación placa de madera',
        'Instalación placa de metal',
      ]);
    },
  );

  // CEO, octubre 2026: "terminado" exige trabajo Y pago -- un registro
  // SIMPLE (sin profesional) en pendientePago también debe salir en el
  // aviso de Inicio, no solo los que tienen profesional.
  test(
    'registrosConTrabajoPendiente() también cuenta un registro simple en pago pendiente',
    () async {
      final db = FakeFirebaseFirestore();
      RegistroService.debugFirestoreOverride = db;
      ElementoService.debugFirestoreOverride = db;

      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .set({'nombre': 'Caldera', 'createdAt': Timestamp.now()});
      await db
          .collection('casas')
          .doc(casaId)
          .collection('elementos')
          .doc(elementoId)
          .collection('registros')
          .add({
            ...registro(estado: EstadoRegistro.pendientePago).toMap(),
            'esConProfesional': false,
            'coste': 2000,
            'fecha': Timestamp.fromDate(DateTime(2026, 2, 1)),
          });

      final pendientes = await RegistroService.registrosConTrabajoPendiente(
        casaId,
      );
      expect(pendientes, hasLength(1));
    },
  );

  test(
    'esTrabajoActivo() es true para pendientePago sin importar esConProfesional, y false para terminado',
    () {
      final simplePendiente = Registro(
        id: '',
        elementoNombre: 'Caldera',
        tipo: TipoRegistro.compra,
        esConProfesional: false,
        titulo: 'Compra',
        estado: EstadoRegistro.pendientePago,
        fecha: DateTime(2026, 1, 1),
      );
      final simpleTerminado = Registro(
        id: '',
        elementoNombre: 'Caldera',
        tipo: TipoRegistro.compra,
        esConProfesional: false,
        titulo: 'Compra',
        estado: EstadoRegistro.terminado,
        fecha: DateTime(2026, 1, 1),
      );
      expect(RegistroService.esTrabajoActivo(simplePendiente), isTrue);
      expect(RegistroService.esTrabajoActivo(simpleTerminado), isFalse);
    },
  );
}
