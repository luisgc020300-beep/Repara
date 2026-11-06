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
import 'package:repara_core/registro_service.dart';
import 'package:repara_core/registro.dart';

void main() {
  const casaId = 'casa-1';
  const elementoId = 'elemento-1';

  tearDown(() {
    RegistroService.debugFirestoreOverride = null;
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

  // CEO, noviembre 2026: un registro simple "todavía no realizado" (enCurso)
  // debe contar igual que pendientePago -- si no, Inicio no lo avisaría y
  // se podría archivar el elemento con un trabajo pendiente de hacer colgando.
  test(
    'esTrabajoActivo() también es true para un registro simple en enCurso (todavía no realizado)',
    () {
      final simpleEnCurso = Registro(
        id: '',
        elementoNombre: 'Caldera',
        tipo: TipoRegistro.compra,
        esConProfesional: false,
        titulo: 'Compra',
        estado: EstadoRegistro.enCurso,
        fecha: DateTime(2026, 1, 1),
      );
      expect(RegistroService.esTrabajoActivo(simpleEnCurso), isTrue);
    },
  );
}
