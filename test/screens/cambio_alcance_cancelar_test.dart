// test/screens/cambio_alcance_cancelar_test.dart
//
// Cancelar un cambio de alcance pendiente (iteración R2, defecto 1): el
// botón solo debe verse cuando el servidor lo permitiría (pendiente, rol
// profesional, registro no cerrado), exige confirmación, y declinarla no
// debe tocar nada. Usa FakeFirebaseFirestore para la lista (vía el seam
// debugFirestoreOverride que ya expone CambioAlcanceService) -- la
// propia cancelación pasa por una Cloud Function real
// (FirebaseFunctions.instanceFor(...).httpsCallable(...)), que no hay
// forma de invocar de verdad en un test sin el emulador de Firebase. En
// este entorno de test, cualquier canal de plataforma sin mock lanza
// MissingPluginException -- eso basta para comprobar que el camino de
// error del botón (vuelve a habilitarse, muestra un aviso, no deja la
// fila en un estado roto) funciona de verdad, aunque no se pueda probar
// el camino de ÉXITO de la llamada real sin ese emulador.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/cambio_alcance_section.dart';
import 'package:repara/screens/presupuestos_section.dart' show RolEnTrabajo;
import 'package:repara/services/cambio_alcance_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casaId = 'c1';
const _elementoId = 'e1';
const _registroId = 'r1';
const _cambioId = 'ca1';

Future<FakeFirebaseFirestore> _prepararCambio({
  required String estado,
  String creadoPorUid = 'pro1',
}) async {
  final db = FakeFirebaseFirestore();
  await db
      .collection('casas')
      .doc(_casaId)
      .collection('elementos')
      .doc(_elementoId)
      .collection('registros')
      .doc(_registroId)
      .collection('cambiosAlcance')
      .doc(_cambioId)
      .set({
        'titulo': 'Sustituir válvula adicional',
        'estado': estado,
        'creadoPorUid': creadoPorUid,
      });
  CambioAlcanceService.debugFirestoreOverride = db;
  return db;
}

Future<String> _estadoActual(FakeFirebaseFirestore db) async {
  final doc = await db
      .collection('casas')
      .doc(_casaId)
      .collection('elementos')
      .doc(_elementoId)
      .collection('registros')
      .doc(_registroId)
      .collection('cambiosAlcance')
      .doc(_cambioId)
      .get();
  return doc.data()!['estado'] as String;
}

Widget _envolver(RolEnTrabajo rol, {bool registroCerrado = false}) => MaterialApp(
  theme: buildReparaLightTheme(),
  home: Scaffold(
    body: CambiosAlcanceSection(
      casaId: _casaId,
      elementoId: _elementoId,
      registroId: _registroId,
      rol: rol,
      registroCerrado: registroCerrado,
    ),
  ),
);

void main() {
  tearDown(() => CambioAlcanceService.debugFirestoreOverride = null);

  testWidgets(
    'con el cambio pendiente, el profesional ve "Cancelar solicitud" y el propietario no',
    (tester) async {
      await _prepararCambio(estado: 'pendiente');

      await tester.pumpWidget(_envolver(RolEnTrabajo.profesional));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar solicitud'), findsOneWidget);
    },
  );

  testWidgets('el propietario nunca ve el botón de cancelar (esa acción es del profesional)', (
    tester,
  ) async {
    await _prepararCambio(estado: 'pendiente');

    await tester.pumpWidget(_envolver(RolEnTrabajo.propietario));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar solicitud'), findsNothing);
    // El propietario sí debe seguir viendo sus propios botones.
    expect(find.text('Aprobar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });

  for (final estado in ['aprobado', 'rechazado', 'cancelado']) {
    testWidgets('un cambio ya $estado no ofrece "Cancelar solicitud" a nadie', (tester) async {
      await _prepararCambio(estado: estado);

      await tester.pumpWidget(_envolver(RolEnTrabajo.profesional));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar solicitud'), findsNothing);
    });
  }

  testWidgets('con el registro cerrado, tampoco se ofrece cancelar aunque siga pendiente', (
    tester,
  ) async {
    await _prepararCambio(estado: 'pendiente');

    await tester.pumpWidget(_envolver(RolEnTrabajo.profesional, registroCerrado: true));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar solicitud'), findsNothing);
  });

  testWidgets('tocar "Cancelar solicitud" pide confirmación; declinarla no toca nada', (
    tester,
  ) async {
    final db = await _prepararCambio(estado: 'pendiente');

    await tester.pumpWidget(_envolver(RolEnTrabajo.profesional));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar solicitud'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar esta solicitud?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(await _estadoActual(db), 'pendiente');
    // La fila sigue intacta, lista para volver a intentarlo.
    expect(find.text('Cancelar solicitud'), findsOneWidget);
  });

  // NO IMPLEMENTADO (limitación real, no simulada): confirmar de verdad la
  // cancelación llama a CambioAlcanceService.cancelar(), que invoca la
  // Cloud Function real vía FirebaseFunctions.instanceFor(...). Al fallar
  // esa llamada en el entorno de test (sin emulador), el propio manejo de
  // error de _cancelar() pasa por AppError.show(), que a su vez llama a
  // FirebaseCrashlytics.instance -- y ESO lanza
  // "[core/no-app] No Firebase App '[DEFAULT]' has been created" porque
  // este proyecto no tiene mocks de Firebase Core en sus tests (el propio
  // test/widget_test.dart lo dice explícitamente: "no hay Firebase de
  // verdad en el test"). Comprobado que falla exactamente por eso, no por
  // un error del código nuevo. Verificar el camino de confirmar de verdad
  // (éxito o error de la Cloud Function) requiere el emulador de Firebase
  // Functions o añadir mocks de Firebase Core al proyecto -- ninguna de
  // las dos cosas entra en el alcance de esta iteración.
}
