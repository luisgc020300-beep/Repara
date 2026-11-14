// packages/repara_ui/test/cita_section_test.dart
//
// CEO, noviembre 2026: "que el propietario pueda responder de verdad, no
// solo aceptar la fecha que ponga el profesional, y que tenga más
// protagonismo que una línea del historial". Mismo criterio de alcance que
// cambio_alcance_section_test.dart: la lista se prueba con
// FakeFirebaseFirestore (vía CitaService.debugFirestoreOverride); confirmar/
// rechazar/proponer otra fecha del PROPIETARIO son Cloud Functions reales
// (CitaService.responderComoPropietario/proponerOtraFecha) que no hay forma
// de invocar de verdad sin el emulador de Firebase Functions en este target
// -- y su camino de ERROR tampoco es comprobable aquí, porque AppError.show()
// llama a FirebaseCrashlytics.instance, que lanza "[core/no-app]" sin mocks
// de Firebase Core (mismo límite documentado en cambio_alcance_section_test.
// dart). Por eso estos dos botones solo se prueban en su RENDERIZADO
// (aparecen/desaparecen según estado/rol/registroCerrado), nunca tocándolos.
//
// responderContrapropuesta() (la respuesta del PROFESIONAL a la
// contrapropuesta) SÍ es una escritura directa a Firestore -- eso sí se
// prueba de extremo a extremo, igual que el resto de CitaService.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara_core/cita_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/registro.dart' show RolEnTrabajo;
import 'package:repara_ui/cita_section.dart';

const _profesionalUid = 'pro1';
const _registroId = 'r1';
const _citaId = 'cita1';

Future<FakeFirebaseFirestore> _prepararCita({
  required String estado,
  DateTime? fecha,
  DateTime? fechaPropuesta,
}) async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('profesionales')
      .doc(_profesionalUid)
      .collection('citas')
      .doc(_citaId)
      .set({
        'titulo': 'Visita de revisión',
        'fecha': Timestamp.fromDate(fecha ?? DateTime(2026, 11, 20, 10)),
        'todoElDia': false,
        'compartida': true,
        'casaId': 'c1',
        'elementoId': 'e1',
        'registroId': _registroId,
        'completada': false,
        'estado': estado,
        if (fechaPropuesta != null) 'fechaPropuesta': Timestamp.fromDate(fechaPropuesta),
      });
  CitaService.debugFirestoreOverride = db;
  return db;
}

Future<Map<String, dynamic>> _datosActuales(FakeFirebaseFirestore db) async {
  final doc = await db.collection('profesionales').doc(_profesionalUid).collection('citas').doc(_citaId).get();
  return doc.data()!;
}

Widget _envolver(RolEnTrabajo rol, {bool registroCerrado = false}) => MaterialApp(
  theme: buildReparaLightTheme(),
  home: Scaffold(
    body: CitaSeccion(
      profesionalUid: _profesionalUid,
      registroId: _registroId,
      rol: rol,
      registroCerrado: registroCerrado,
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));
  tearDown(() {
    CitaService.debugFirestoreOverride = null;
    CitaService.debugUidOverride = null;
  });

  testWidgets('sin ninguna cita compartida para este trabajo, muestra el estado vacío', (tester) async {
    CitaService.debugFirestoreOverride = FakeFirebaseFirestore();
    await tester.pumpWidget(_envolver(RolEnTrabajo.propietario));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin citas programadas'), findsOneWidget);
  });

  testWidgets('pendienteConfirmacion + propietario: ve Confirmar/Rechazar/Proponer otra fecha', (tester) async {
    await _prepararCita(estado: 'pendienteConfirmacion');

    await tester.pumpWidget(_envolver(RolEnTrabajo.propietario));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Proponer otra fecha'), findsOneWidget);
    expect(find.text('PENDIENTE DE CONFIRMAR'), findsOneWidget);
  });

  testWidgets('pendienteConfirmacion + profesional: no ve ningún botón de respuesta del propietario', (tester) async {
    await _prepararCita(estado: 'pendienteConfirmacion');

    await tester.pumpWidget(_envolver(RolEnTrabajo.profesional));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
    expect(find.text('Proponer otra fecha'), findsNothing);
  });

  testWidgets('con el registro cerrado, el propietario ya no puede responder aunque siga pendiente', (tester) async {
    await _prepararCita(estado: 'pendienteConfirmacion');

    await tester.pumpWidget(_envolver(RolEnTrabajo.propietario, registroCerrado: true));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
  });

  for (final estado in ['confirmada', 'rechazada']) {
    testWidgets('una cita ya $estado no ofrece ningún botón, a nadie', (tester) async {
      await _prepararCita(estado: estado);

      await tester.pumpWidget(_envolver(RolEnTrabajo.propietario));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar'), findsNothing);
      expect(find.text('Rechazar'), findsNothing);
    });
  }

  testWidgets('contrapropuestaPropietario + propietario: solo lectura, "esperando respuesta"', (tester) async {
    await _prepararCita(estado: 'contrapropuestaPropietario', fechaPropuesta: DateTime(2026, 11, 22, 16));

    await tester.pumpWidget(_envolver(RolEnTrabajo.propietario));
    await tester.pumpAndSettle();

    expect(find.textContaining('Esperando respuesta del profesional'), findsOneWidget);
    expect(find.text('Aceptar'), findsNothing);
  });

  testWidgets('contrapropuestaPropietario + profesional: ve la fecha propuesta y los botones Aceptar/No, proponer otra', (tester) async {
    await _prepararCita(estado: 'contrapropuestaPropietario', fechaPropuesta: DateTime(2026, 11, 22, 16));

    await tester.pumpWidget(_envolver(RolEnTrabajo.profesional));
    await tester.pumpAndSettle();

    expect(find.textContaining('El propietario propone'), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('No, proponer otra'), findsOneWidget);
  });

  testWidgets('el profesional acepta la contrapropuesta: la fecha pasa a ser la propuesta y queda confirmada', (tester) async {
    final fechaPropuesta = DateTime(2026, 11, 22, 16);
    final db = await _prepararCita(estado: 'contrapropuestaPropietario', fechaPropuesta: fechaPropuesta);
    CitaService.debugUidOverride = _profesionalUid;

    await tester.pumpWidget(_envolver(RolEnTrabajo.profesional));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    final datos = await _datosActuales(db);
    expect(datos['estado'], 'confirmada');
    expect((datos['fecha'] as Timestamp).toDate(), fechaPropuesta);
    expect(datos.containsKey('fechaPropuesta'), isFalse);
    expect(find.text('Cita confirmada con la nueva fecha.'), findsOneWidget);
  });

  testWidgets('el profesional declina la contrapropuesta: vuelve a pendienteConfirmacion sin tocar la fecha original', (tester) async {
    final fechaOriginal = DateTime(2026, 11, 20, 10);
    final db = await _prepararCita(estado: 'contrapropuestaPropietario', fecha: fechaOriginal, fechaPropuesta: DateTime(2026, 11, 22, 16));
    CitaService.debugUidOverride = _profesionalUid;

    await tester.pumpWidget(_envolver(RolEnTrabajo.profesional));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No, proponer otra'));
    await tester.pumpAndSettle();

    final datos = await _datosActuales(db);
    expect(datos['estado'], 'pendienteConfirmacion');
    expect((datos['fecha'] as Timestamp).toDate(), fechaOriginal);
    expect(datos.containsKey('fechaPropuesta'), isFalse);
  });

  // NO IMPLEMENTADO (limitación real, no simulada): confirmar/rechazar/
  // proponer otra fecha desde el PROPIETARIO llaman a
  // CitaService.responderComoPropietario()/proponerOtraFecha(), que invocan
  // Cloud Functions reales vía FirebaseFunctions.instanceFor(...) -- sin
  // emulador en este target. Y su manejo de error tampoco es comprobable
  // aquí: AppError.show() llama a FirebaseCrashlytics.instance, que lanza
  // "[core/no-app]" sin mocks de Firebase Core (mismo límite documentado en
  // cambio_alcance_section_test.dart). Verificar esos dos caminos de verdad
  // (éxito o error de la Cloud Function) exige el emulador de Firebase
  // Functions o mocks de Firebase Core -- ninguna de las dos cosas entra en
  // el alcance de esta iteración.
}
