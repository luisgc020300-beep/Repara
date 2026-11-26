// test/screens/cliente_profesional_sheet_proteccion_test.dart
//
// Protección frente a salidas accidentales del editor de cliente privado
// (noviembre 2026): reutiliza ConfirmarSalidaFormulario, igual que los
// formularios de Hogar. Cubre los dos caminos de "cierre" que existen sobre
// un showModalBottomSheet -- el toque fuera de la hoja (barrera modal, usa
// Navigator.maybePop, igual que el botón/gesto de atrás del sistema) y el
// guardado con éxito (no debe mostrar ningún aviso).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_pro/screens/clientes_pro_tab.dart';
import 'package:repara_pro/services/cliente_profesional_service.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_pro/services/trabajo_profesional_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/cambio_alcance_service.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:repara_core/primer_uso_service.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Toca la barrera modal (fuera de la hoja) -- usa Navigator.maybePop, el
/// mismo camino que el botón/gesto de atrás del sistema, así que sirve para
/// comprobar ambos con un único gesto en el test. El borde superior de la
/// pantalla siempre es barrera (la hoja crece desde abajo), a diferencia de
/// una esquina fija que podría quedar tapada si el formulario es alto.
Future<void> _tocarFuera(WidgetTester tester) async {
  await tester.tapAt(const Offset(400, 5));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(_limpiarOverrides);
  // Sin esto, el primer toque en "+" mostraría el diálogo de ayuda "¿Qué es
  // un cliente privado?" (auditoría de calidad, noviembre 2026) en vez de
  // abrir la hoja directamente -- este archivo no es el que prueba ese
  // diálogo.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrimerUsoService.marcarVisto('nuevo_cliente_privado');
  });

  testWidgets(
    'cerrar la hoja de cliente sin tocar nada no muestra confirmación',
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
      expect(find.text('Nuevo cliente'), findsOneWidget);

      await _tocarFuera(tester);

      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.text('Nuevo cliente'), findsNothing);
    },
  );

  testWidgets(
    'cerrar la hoja de cliente con datos sin guardar muestra confirmación',
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
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ana');

      await _tocarFuera(tester);

      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      // La hoja sigue abierta debajo del diálogo, con el texto conservado.
      expect(find.text('Nuevo cliente'), findsOneWidget);
    },
  );

  testWidgets(
    '"Seguir editando" mantiene la hoja de cliente abierta con los datos',
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
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ana');
      await _tocarFuera(tester);
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.text('Nuevo cliente'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
    },
  );

  testWidgets(
    '"Salir" descarta los cambios y cierra la hoja de cliente sin crearlo',
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
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ana');
      await _tocarFuera(tester);
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo cliente'), findsNothing);
      expect(find.text('Ana'), findsNothing);
    },
  );

  testWidgets(
    'guardar con éxito cierra la hoja de cliente sin pedir confirmación',
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
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ana');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.text('Nuevo cliente'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
    },
  );
}
