// test/screens/pro/agenda_pro_tab_test.dart
//
// Agenda (ampliación REPARA Pro, Fase 4, noviembre 2026): el estado vacío
// es real (no listas fantasma), crear una cita nueva la hace aparecer, y
// cambiar de vista (Semana/Día) sigue mostrando los datos reales del día
// seleccionado.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/screens/pro/agenda_pro_tab.dart';
import 'package:repara/services/cita_service.dart';
import 'package:repara/services/profesional_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _uid = 'pro-1';

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    CitaService.debugFirestoreOverride = null;
    CitaService.debugUidOverride = null;
    ProfesionalService.debugFirestoreOverride = null;
    ProfesionalService.debugUidOverride = null;
  });

  testWidgets('sin citas, la vista Semana muestra el estado vacío real', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(_uid).set({'registrosProRefs': []});
    CitaService.debugFirestoreOverride = db;
    CitaService.debugUidOverride = _uid;
    ProfesionalService.debugFirestoreOverride = db;
    ProfesionalService.debugUidOverride = _uid;

    await tester.pumpWidget(
      MaterialApp(theme: buildReparaLightTheme(), home: const AgendaProTab()),
    );
    await tester.pumpAndSettle();

    // Vista Semana por defecto: cada uno de los 7 días de la semana sin
    // citas muestra su propio "Sin citas", no un único estado vacío.
    expect(find.text('Sin citas'), findsNWidgets(7));
  });

  testWidgets('crear una cita nueva la hace aparecer en la lista del día', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(_uid).set({'registrosProRefs': []});
    CitaService.debugFirestoreOverride = db;
    CitaService.debugUidOverride = _uid;
    ProfesionalService.debugFirestoreOverride = db;
    ProfesionalService.debugUidOverride = _uid;

    await tester.pumpWidget(
      MaterialApp(theme: buildReparaLightTheme(), home: const AgendaProTab()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Visita de presupuesto',
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Todo el día'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cita'));
    await tester.pumpAndSettle();

    expect(find.text('Visita de presupuesto'), findsOneWidget);
    expect(find.textContaining('Todo el día'), findsOneWidget);
  });

  testWidgets(
    'la vista Día muestra las citas de ese día concreto, no las de otro',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({'registrosProRefs': []});
      final hoy = DateTime.now();
      await db.collection('profesionales').doc(_uid).collection('citas').add({
        'titulo': 'Cita de hoy',
        'fecha': Timestamp.fromDate(DateTime(hoy.year, hoy.month, hoy.day, 9)),
        'todoElDia': false,
        'completada': false,
      });
      await db.collection('profesionales').doc(_uid).collection('citas').add({
        'titulo': 'Dentro de dos semanas',
        'fecha': Timestamp.fromDate(hoy.add(const Duration(days: 14))),
        'todoElDia': false,
        'completada': false,
      });
      CitaService.debugFirestoreOverride = db;
      CitaService.debugUidOverride = _uid;
      ProfesionalService.debugFirestoreOverride = db;
      ProfesionalService.debugUidOverride = _uid;

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const AgendaProTab()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Día'));
      await tester.pumpAndSettle();

      expect(find.text('Cita de hoy'), findsOneWidget);
      expect(find.text('Dentro de dos semanas'), findsNothing);
    },
  );
}
