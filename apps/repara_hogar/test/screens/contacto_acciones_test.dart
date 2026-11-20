// apps/repara_hogar/test/screens/contacto_acciones_test.dart
//
// Mejora de invitaciones (noviembre 2026): eventosDisponiblesParaInvitar()
// -- usado tanto al invitar desde un contacto de la libreta como desde
// Cercanos -- ya excluía los eventos con profesional ya asignado, pero no
// los que ya tenían una invitación pendiente (mandada desde la propia
// ficha del evento, ver _SeccionInvitarProfesional en
// registro_detail_screen.dart). Sin esto, se podían acabar enviando dos
// invitaciones activas a la vez para el mismo evento, una desde cada
// camino.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/invitacion_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_hogar/screens/contacto_acciones.dart';
import 'package:repara_hogar/services/elemento_service.dart';

const _casaId = 'casa-1';
const _elementoId = 'elem-1';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    ElementoService.debugFirestoreOverride = db;
    RegistroService.debugFirestoreOverride = db;
    InvitacionService.debugFirestoreOverride = db;
    // streamUltimaInvitacionDe ahora filtra también por propietarioUid
    // (corrección de un permission-denied real en producción, noviembre
    // 2026) -- debe coincidir con el propietarioUid sembrado en
    // sembrarInvitacionPendiente para que el test siga probando lo mismo.
    InvitacionService.debugUidOverride = 'owner-1';
  });

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    InvitacionService.debugFirestoreOverride = null;
    InvitacionService.debugUidOverride = null;
  });

  Future<void> sembrarElemento() async {
    await db
        .collection('casas')
        .doc(_casaId)
        .collection('elementos')
        .doc(_elementoId)
        .set({'nombre': 'Caldera', 'createdAt': Timestamp.fromDate(DateTime(2026))});
  }

  Future<void> sembrarRegistro(String id, {required String estado}) async {
    await db
        .collection('casas')
        .doc(_casaId)
        .collection('elementos')
        .doc(_elementoId)
        .collection('registros')
        .doc(id)
        .set({
          'titulo': 'Trabajo $id',
          'tipo': 'reparacion',
          'esConProfesional': true,
          'estado': estado,
          'elementoNombre': 'Caldera',
          'fecha': Timestamp.fromDate(DateTime(2026)),
        });
  }

  Future<void> sembrarInvitacionPendiente(String registroId) async {
    await db.collection('invitaciones').add({
      'casaId': _casaId,
      'elementoId': _elementoId,
      'elementoNombre': 'Caldera',
      'registroId': registroId,
      'registroTitulo': 'Trabajo $registroId',
      'casaNombre': 'Mi casa',
      'propietarioUid': 'owner-1',
      'profesionalUid': 'pro-1',
      'profesionalEmail': 'pro@ejemplo.com',
      'estado': 'pendiente',
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    });
  }

  test('un registro sin profesional ni invitación pendiente SÍ está disponible', () async {
    await sembrarElemento();
    await sembrarRegistro('r1', estado: 'enCurso');

    final eventos = await eventosDisponiblesParaInvitar(_casaId);

    expect(eventos.map((e) => e.registro.id), contains('r1'));
  });

  test('un registro con una invitación ya pendiente NO está disponible (evita duplicados)', () async {
    await sembrarElemento();
    await sembrarRegistro('r1', estado: 'enCurso');
    await sembrarInvitacionPendiente('r1');

    final eventos = await eventosDisponiblesParaInvitar(_casaId);

    expect(eventos.map((e) => e.registro.id), isNot(contains('r1')));
  });

  test('un registro con una invitación ya RECHAZADA sí sigue disponible (se puede volver a invitar)', () async {
    await sembrarElemento();
    await sembrarRegistro('r1', estado: 'enCurso');
    await db.collection('invitaciones').add({
      'casaId': _casaId,
      'elementoId': _elementoId,
      'elementoNombre': 'Caldera',
      'registroId': 'r1',
      'registroTitulo': 'Trabajo r1',
      'casaNombre': 'Mi casa',
      'propietarioUid': 'owner-1',
      'profesionalUid': 'pro-1',
      'profesionalEmail': 'pro@ejemplo.com',
      'estado': 'rechazada',
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    });

    final eventos = await eventosDisponiblesParaInvitar(_casaId);

    expect(eventos.map((e) => e.registro.id), contains('r1'));
  });

  test('un registro ya cerrado (terminado) no está disponible, con o sin invitación', () async {
    await sembrarElemento();
    await sembrarRegistro('r1', estado: 'terminado');

    final eventos = await eventosDisponiblesParaInvitar(_casaId);

    expect(eventos.map((e) => e.registro.id), isNot(contains('r1')));
  });
}
