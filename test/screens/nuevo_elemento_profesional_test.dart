// test/screens/nuevo_elemento_profesional_test.dart
//
// "Coste" y "Profesional" en "Nuevo elemento" (CEO, octubre 2026): con
// "¿Lo hace un profesional?" activado, esos dos campos se seguían
// mostrando pero lo que se escribiera ahí se perdía en la práctica --
// _ResumenEconomico nunca lo muestra para un registro con profesional (ver
// registro_detail_screen.dart). Ahora se ocultan en cuanto se activa el
// interruptor, con una nota explicando dónde se gestionan de verdad.
// Usa FakeFirebaseFirestore, nada de Firebase real.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/screens/nuevo_elemento_screen.dart';
import 'package:repara/services/contacto_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Mi casa',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void main() {
  setUp(() {
    final db = FakeFirebaseFirestore();
    ElementoService.debugFirestoreOverride = db;
    HabitacionService.debugFirestoreOverride = db;
    ContactoService.debugFirestoreOverride = db;
  });

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    ContactoService.debugFirestoreOverride = null;
  });

  testWidgets(
    'con el interruptor desactivado (por defecto), se ven "Coste" y "Profesional"',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: NuevoElementoScreen(casa: _casa)),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Coste (€)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Profesional (opcional)'), findsOneWidget);
    },
  );

  testWidgets(
    'activar "¿Lo hace un profesional?" oculta Coste/Profesional y explica dónde se gestionan',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: NuevoElementoScreen(casa: _casa)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Lo hace un profesional?'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Coste (€)'), findsNothing);
      expect(find.widgetWithText(TextField, 'Profesional (opcional)'), findsNothing);
      expect(find.textContaining('invita al profesional'), findsOneWidget);
    },
  );

  testWidgets(
    'desactivar el interruptor de nuevo vuelve a mostrar Coste y Profesional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: NuevoElementoScreen(casa: _casa)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Lo hace un profesional?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Lo hace un profesional?'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Coste (€)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Profesional (opcional)'), findsOneWidget);
    },
  );
}
