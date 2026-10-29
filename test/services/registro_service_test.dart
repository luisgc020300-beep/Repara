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

  Registro registro({String titulo = 'Avería', EstadoRegistro estado = EstadoRegistro.nuevo}) => Registro(
        id: '',
        elementoNombre: 'Caldera',
        tipo: TipoRegistro.averia,
        esConProfesional: false,
        titulo: titulo,
        estado: estado,
        fecha: DateTime(2026, 1, 1),
      );

  test('crear() guarda casaId y createdBy además de los campos del registro', () async {
    final db = FakeFirebaseFirestore();
    RegistroService.debugFirestoreOverride = db;

    final id = await RegistroService.crear(casaId, elementoId, registro(), createdBy: 'owner-a');

    final doc = await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).collection('registros').doc(id).get();
    expect(doc.data()!['casaId'], casaId);
    expect(doc.data()!['createdBy'], 'owner-a');
    expect(doc.data()!['titulo'], 'Avería');
  });

  test('streamRegistros() devuelve los registros del elemento ordenados por fecha descendente', () async {
    final db = FakeFirebaseFirestore();
    RegistroService.debugFirestoreOverride = db;

    await RegistroService.crear(casaId, elementoId, registro(titulo: 'Antiguo'), createdBy: 'owner-a');
    await db
        .collection('casas')
        .doc(casaId)
        .collection('elementos')
        .doc(elementoId)
        .collection('registros')
        .add({...registro(titulo: 'Reciente').toMap(), 'fecha': Timestamp.fromDate(DateTime(2026, 6, 1))});

    final registros = await RegistroService.streamRegistros(casaId, elementoId).first;
    expect(registros, hasLength(2));
    expect(registros.first.titulo, 'Reciente');
  });

  test('actualizarEstado() cambia solo el campo estado', () async {
    final db = FakeFirebaseFirestore();
    RegistroService.debugFirestoreOverride = db;
    final id = await RegistroService.crear(casaId, elementoId, registro(), createdBy: 'owner-a');

    await RegistroService.actualizarEstado(casaId, elementoId, id, EstadoRegistro.enCurso);

    final actualizado = await RegistroService.streamRegistro(casaId, elementoId, id).first;
    expect(actualizado!.estado, EstadoRegistro.enCurso);
    expect(actualizado.titulo, 'Avería'); // el resto de campos no se toca
  });

  test('elementosConTrabajoPendiente() cuenta registros con profesional sin cerrar', () async {
    final db = FakeFirebaseFirestore();
    RegistroService.debugFirestoreOverride = db;
    ElementoService.debugFirestoreOverride = db;

    await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).set({'nombre': 'Caldera', 'createdAt': Timestamp.now()});
    await db
        .collection('casas')
        .doc(casaId)
        .collection('elementos')
        .doc(elementoId)
        .collection('registros')
        .add({...registro(estado: EstadoRegistro.enCurso).toMap(), 'esConProfesional': true, 'fecha': Timestamp.fromDate(DateTime(2026, 2, 1))});
    await db
        .collection('casas')
        .doc(casaId)
        .collection('elementos')
        .doc(elementoId)
        .collection('registros')
        .add({...registro(estado: EstadoRegistro.terminado).toMap(), 'esConProfesional': true, 'fecha': Timestamp.fromDate(DateTime(2026, 1, 1))});

    final pendientes = await RegistroService.elementosConTrabajoPendiente(casaId);
    expect(pendientes, hasLength(1)); // el elemento solo cuenta una vez, aunque tenga más de un registro
  });

  // CEO, octubre 2026: "terminado" exige trabajo Y pago -- un registro
  // SIMPLE (sin profesional) en pendientePago también debe salir en el
  // aviso de Inicio, no solo los que tienen profesional.
  test('elementosConTrabajoPendiente() también cuenta un registro simple en pago pendiente', () async {
    final db = FakeFirebaseFirestore();
    RegistroService.debugFirestoreOverride = db;
    ElementoService.debugFirestoreOverride = db;

    await db.collection('casas').doc(casaId).collection('elementos').doc(elementoId).set({'nombre': 'Caldera', 'createdAt': Timestamp.now()});
    await db
        .collection('casas')
        .doc(casaId)
        .collection('elementos')
        .doc(elementoId)
        .collection('registros')
        .add({...registro(estado: EstadoRegistro.pendientePago).toMap(), 'esConProfesional': false, 'coste': 2000, 'fecha': Timestamp.fromDate(DateTime(2026, 2, 1))});

    final pendientes = await RegistroService.elementosConTrabajoPendiente(casaId);
    expect(pendientes, hasLength(1));
  });

  test('esTrabajoActivo() es true para pendientePago sin importar esConProfesional, y false para terminado', () {
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
  });
}
