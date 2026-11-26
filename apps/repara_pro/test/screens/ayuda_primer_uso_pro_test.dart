// test/screens/ayuda_primer_uso_pro_test.dart
//
// Ayuda contextual "solo la primera vez" en los tres botones "+"
// principales de REPARA Pro (auditoría de calidad, noviembre 2026: "en
// Hogar, al pulsar un botón importante por primera vez aparece una breve
// descripción de lo que hace -- en Pro no pasa nada de esto"). Mismo
// mecanismo que ya usaba Hogar (PrimerUsoService + mostrarAyudaPrimerUso,
// compartidos en repara_core/repara_ui -- nada nuevo que probar ahí, solo
// que Pro los usa correctamente).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:repara_pro/screens/agenda_pro_tab.dart';
import 'package:repara_pro/screens/clientes_pro_tab.dart';
import 'package:repara_pro/screens/trabajos_pro_tab.dart';
import 'package:repara_core/cita_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:repara_pro/services/cliente_profesional_service.dart';
import 'package:repara_pro/services/trabajo_profesional_service.dart';

const _uid = 'pro-1';

Future<FakeFirebaseFirestore> _crearDbVacia() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc(_uid).set({'registrosProRefs': []});
  ProfesionalService.debugFirestoreOverride = db;
  ProfesionalService.debugUidOverride = _uid;
  RegistroService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  PresupuestoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
  ClienteProfesionalService.debugFirestoreOverride = db;
  ClienteProfesionalService.debugUidOverride = _uid;
  TrabajoProfesionalService.debugFirestoreOverride = db;
  TrabajoProfesionalService.debugUidOverride = _uid;
  CitaService.debugFirestoreOverride = db;
  CitaService.debugUidOverride = _uid;
  return db;
}

void _limpiarOverrides() {
  ProfesionalService.debugFirestoreOverride = null;
  ProfesionalService.debugUidOverride = null;
  RegistroService.debugFirestoreOverride = null;
  PagoService.debugFirestoreOverride = null;
  PresupuestoService.debugFirestoreOverride = null;
  CambioAlcanceService.debugFirestoreOverride = null;
  ClienteProfesionalService.debugFirestoreOverride = null;
  ClienteProfesionalService.debugUidOverride = null;
  TrabajoProfesionalService.debugFirestoreOverride = null;
  TrabajoProfesionalService.debugUidOverride = null;
  CitaService.debugFirestoreOverride = null;
  CitaService.debugUidOverride = null;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));
  // Estado "nunca visto" en cada test, igual que primer_uso_service_test.dart.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(_limpiarOverrides);

  testWidgets(
    'el "+" de Clientes explica qué es un cliente privado solo la primera vez',
    (tester) async {
      await _crearDbVacia();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const ClientesProTab(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué es un cliente privado?'), findsOneWidget);
      // La hoja de creación todavía no se ha abierto -- espera a "Entendido".
      expect(find.widgetWithText(TextField, 'Nombre'), findsNothing);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Nombre'), findsOneWidget);

      // Cerrar la hoja y volver a pulsar "+": la segunda vez no hay aviso.
      await tester.tapAt(const Offset(400, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué es un cliente privado?'), findsNothing);
      expect(find.widgetWithText(TextField, 'Nombre'), findsOneWidget);
    },
  );

  testWidgets(
    'el "+" de Trabajos explica qué es un trabajo privado solo la primera vez',
    (tester) async {
      await _crearDbVacia();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const TrabajosProTab(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué es un trabajo privado?'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Título'), findsNothing);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Título'), findsOneWidget);

      await tester.tapAt(const Offset(400, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué es un trabajo privado?'), findsNothing);
      expect(find.widgetWithText(TextField, 'Título'), findsOneWidget);
    },
  );

  testWidgets('el "+" de Agenda explica para qué sirve solo la primera vez', (
    tester,
  ) async {
    await _crearDbVacia();
    await tester.pumpWidget(
      MaterialApp(theme: buildReparaLightTheme(), home: const AgendaProTab()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('¿Para qué sirve la Agenda?'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Título'), findsNothing);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Título'), findsOneWidget);

    await tester.tapAt(const Offset(400, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('¿Para qué sirve la Agenda?'), findsNothing);
    expect(find.widgetWithText(TextField, 'Título'), findsOneWidget);
  });
}
