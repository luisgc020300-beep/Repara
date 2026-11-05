// test/screens/pro/cliente_profesional_flujo_test.dart
//
// Clientes/trabajos privados (Fase 1, noviembre 2026): crear un cliente
// privado lo hace aparecer en la lista combinada de ClientesProTab con la
// insignia "Privado" (distinta de un cliente derivado de un trabajo
// compartido), y desde su ficha se puede crear un trabajo privado sin
// depender de ninguna invitación de REPARA Hogar.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/pro/clientes_pro_tab.dart';
import 'package:repara/services/cambio_alcance_service.dart';
import 'package:repara/services/cliente_profesional_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/presupuesto_service.dart';
import 'package:repara/services/profesional_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/services/trabajo_profesional_service.dart';
import 'package:repara/theme/design_tokens.dart';

const _uid = 'pro-1';

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
}

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
  return db;
}

void main() {
  tearDown(_limpiarOverrides);

  testWidgets(
    'crear un cliente privado lo muestra en la lista con la insignia PRIVADO',
    (tester) async {
      await _crearDbVacia();

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const ClientesProTab()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'),
        'María López',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('María López'), findsOneWidget);
      expect(find.text('PRIVADO'), findsOneWidget);
    },
  );

  testWidgets(
    'crear un trabajo privado desde la ficha del cliente lo hace aparecer en su historial',
    (tester) async {
      await _crearDbVacia();

      await tester.pumpWidget(
        MaterialApp(theme: buildReparaLightTheme(), home: const ClientesProTab()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'),
        'María López',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('María López'));
      await tester.pumpAndSettle();

      expect(find.text('Sin trabajos todavía con este cliente.'), findsOneWidget);

      await tester.tap(find.text('Nuevo trabajo'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Cambiar grifo',
      );
      await tester.tap(find.text('Crear trabajo'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar grifo'), findsOneWidget);
      expect(find.text('Abierto'), findsOneWidget);
    },
  );
}
