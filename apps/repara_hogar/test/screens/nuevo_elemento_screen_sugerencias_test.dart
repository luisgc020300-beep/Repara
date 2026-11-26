// test/screens/nuevo_elemento_screen_sugerencias_test.dart
//
// Fase 1 de reutilización de datos (CEO, noviembre 2026): los campos Marca
// y Modelo de "Nuevo elemento" generalizan el mismo RawAutocomplete ya
// usado para "Profesional" -- sugieren marcas/modelos ya usados en esta
// casa, sin duplicados, sin forzar ninguna selección, y priorizando lo más
// reciente.
//
// Los elementos se siembran escribiendo directamente en FakeFirebaseFirestore
// con un Timestamp explícito, no con ElementoService.crear() -- usar
// FieldValue.serverTimestamp() seguido de un Future.delayed real antes de
// montar el widget deja al stream de fake_cloud_firestore en un estado que
// nunca termina de asentarse (pumpAndSettle no vuelve), un problema de la
// combinación de librerías de test, no del código de la app. Un Timestamp
// ya resuelto evita el problema sin perder lo que el test necesita
// comprobar: el orden real por fecha de creación.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_hogar/models/casa.dart';
import 'package:repara_hogar/screens/nuevo_elemento_screen.dart';
import 'package:repara_hogar/services/contacto_service.dart';
import 'package:repara_hogar/services/elemento_service.dart';
import 'package:repara_hogar/services/habitacion_service.dart';
import 'package:repara_core/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void _limpiarOverrides() {
  ElementoService.debugFirestoreOverride = null;
  HabitacionService.debugFirestoreOverride = null;
  ContactoService.debugFirestoreOverride = null;
}

/// [elementos] en el orden en que deben haberse "creado" -- el primero es
/// el más antiguo, cada uno siguiente recibe un Timestamp posterior.
Future<FakeFirebaseFirestore> _conElementos(
  List<({String nombre, String? marca, String? modelo})> elementos,
) async {
  final db = FakeFirebaseFirestore();
  ElementoService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  ContactoService.debugFirestoreOverride = db;
  var i = 0;
  for (final e in elementos) {
    await db.collection('casas').doc('c1').collection('elementos').add({
      'nombre': e.nombre,
      if (e.marca != null) 'marca': e.marca,
      if (e.modelo != null) 'modelo': e.modelo,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1 + i)),
    });
    i++;
  }
  return db;
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildReparaLightTheme(), home: NuevoElementoScreen(casa: _casa)),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(_limpiarOverrides);

  testWidgets('sin elementos previos, el campo Marca no ofrece ninguna sugerencia', (
    tester,
  ) async {
    await _conElementos(const []);
    await _pump(tester);

    await tester.tap(find.widgetWithText(TextField, 'Marca'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('al tocar Marca sin escribir nada, sugiere las marcas ya usadas en la casa', (
    tester,
  ) async {
    await _conElementos(const [
      (nombre: 'Caldera', marca: 'Vaillant', modelo: null),
      (nombre: 'Lavadora', marca: 'Bosch', modelo: null),
    ]);
    await _pump(tester);

    await tester.tap(find.widgetWithText(TextField, 'Marca'));
    await tester.pumpAndSettle();

    expect(find.text('Vaillant'), findsOneWidget);
    expect(find.text('Bosch'), findsOneWidget);
  });

  testWidgets('las marcas repetidas no se duplican en las sugerencias', (
    tester,
  ) async {
    await _conElementos(const [
      (nombre: 'Caldera', marca: 'Vaillant', modelo: null),
      (nombre: 'Termo', marca: 'Vaillant', modelo: null),
    ]);
    await _pump(tester);

    await tester.tap(find.widgetWithText(TextField, 'Marca'));
    await tester.pumpAndSettle();

    expect(find.text('Vaillant'), findsOneWidget);
  });

  testWidgets(
    'la marca del elemento creado más recientemente aparece primero en las sugerencias',
    (tester) async {
      await _conElementos(const [
        (nombre: 'Caldera', marca: 'Vaillant', modelo: null),
        (nombre: 'Lavadora', marca: 'Bosch', modelo: null),
      ]);
      await _pump(tester);

      await tester.tap(find.widgetWithText(TextField, 'Marca'));
      await tester.pumpAndSettle();

      final posicionBosch = tester.getTopLeft(find.text('Bosch')).dy;
      final posicionVaillant = tester.getTopLeft(find.text('Vaillant')).dy;
      expect(
        posicionBosch,
        lessThan(posicionVaillant),
        reason: 'Bosch (el elemento creado después) debe ir primero',
      );
    },
  );

  testWidgets(
    'escribir en Marca filtra las sugerencias ignorando mayúsculas y sin modificar el texto tecleado',
    (tester) async {
      await _conElementos(const [
        (nombre: 'Caldera', marca: 'Vaillant', modelo: null),
        (nombre: 'Lavadora', marca: 'Bosch', modelo: null),
      ]);
      await _pump(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Marca'), 'vaill');
      await tester.pumpAndSettle();

      expect(find.text('Vaillant'), findsOneWidget);
      expect(find.text('Bosch'), findsNothing);
      expect(
        find.widgetWithText(TextField, 'vaill'),
        findsOneWidget,
        reason: 'el texto tecleado por el usuario no debe cambiar solo',
      );
    },
  );

  testWidgets('tocar una sugerencia de Marca rellena el campo con ese valor', (
    tester,
  ) async {
    await _conElementos(const [
      (nombre: 'Caldera', marca: 'Vaillant', modelo: null),
    ]);
    await _pump(tester);

    await tester.tap(find.widgetWithText(TextField, 'Marca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaillant').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Vaillant'), findsOneWidget);
  });

  testWidgets(
    'se puede escribir una marca nueva, que no está entre las sugerencias, sin seleccionar nada',
    (tester) async {
      await _conElementos(const [
        (nombre: 'Caldera', marca: 'Vaillant', modelo: null),
      ]);
      await _pump(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Marca'),
        'Una marca nueva',
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Una marca nueva'), findsOneWidget);
    },
  );

  testWidgets('el campo Modelo sugiere modelos ya usados, independiente de Marca', (
    tester,
  ) async {
    await _conElementos(const [
      (nombre: 'Caldera', marca: 'Vaillant', modelo: 'ecoTEC'),
    ]);
    await _pump(tester);

    await tester.tap(find.widgetWithText(TextField, 'Modelo'));
    await tester.pumpAndSettle();

    expect(find.text('ecoTEC'), findsOneWidget);
  });
}
