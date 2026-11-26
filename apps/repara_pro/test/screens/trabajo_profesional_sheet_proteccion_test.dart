// test/screens/trabajo_profesional_sheet_proteccion_test.dart
//
// Protección frente a salidas accidentales del editor de trabajo privado
// (noviembre 2026): mismo mecanismo que cliente_profesional_sheet_proteccion_
// test.dart -- reutiliza ConfirmarSalidaFormulario, y el toque fuera de la
// hoja usa Navigator.maybePop, el mismo camino que el botón/gesto de atrás
// del sistema.
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

/// Toca la barrera modal (fuera de la hoja) -- el borde superior de la
/// pantalla siempre es barrera, a diferencia de una esquina fija que podría
/// quedar tapada si el formulario es alto.
Future<void> _tocarFuera(WidgetTester tester) async {
  await tester.tapAt(const Offset(400, 5));
  await tester.pumpAndSettle();
}

/// Crea un cliente y entra en su ficha, para luego abrir "Nuevo trabajo"
/// desde ahí -- mismo camino que cliente_profesional_flujo_test.dart.
Future<void> _abrirNuevoTrabajoDesdeFichaDeCliente(WidgetTester tester) async {
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

  await tester.tap(find.text('Nuevo trabajo'));
  await tester.pumpAndSettle();
  // 'Nuevo trabajo' también es el botón de la ficha que seguimos viendo
  // detrás de la hoja -- 'Crear trabajo' (el botón de guardar) solo existe
  // dentro de la hoja recién abierta, así que es la señal inequívoca.
  expect(find.text('Crear trabajo'), findsOneWidget);
}

void main() {
  tearDown(_limpiarOverrides);
  // Sin esto, el primer toque en "+" (para crear el cliente de prueba)
  // mostraría el diálogo de ayuda "¿Qué es un cliente privado?" (auditoría
  // de calidad, noviembre 2026) en vez de abrir la hoja directamente.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrimerUsoService.marcarVisto('nuevo_cliente_privado');
  });

  testWidgets(
    'cerrar la hoja de trabajo sin tocar nada no muestra confirmación',
    (tester) async {
      await _crearDbVacia();
      await _abrirNuevoTrabajoDesdeFichaDeCliente(tester);

      await _tocarFuera(tester);

      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.text('Crear trabajo'), findsNothing);
    },
  );

  testWidgets(
    'cerrar la hoja de trabajo con datos sin guardar muestra confirmación',
    (tester) async {
      await _crearDbVacia();
      await _abrirNuevoTrabajoDesdeFichaDeCliente(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Cambiar grifo',
      );
      await _tocarFuera(tester);

      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      expect(find.text('Crear trabajo'), findsOneWidget);
    },
  );

  testWidgets(
    '"Seguir editando" mantiene la hoja de trabajo abierta con los datos',
    (tester) async {
      await _crearDbVacia();
      await _abrirNuevoTrabajoDesdeFichaDeCliente(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Cambiar grifo',
      );
      await _tocarFuera(tester);
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.text('Crear trabajo'), findsOneWidget);
      expect(find.text('Cambiar grifo'), findsOneWidget);
    },
  );

  testWidgets(
    '"Salir" descarta los cambios y cierra la hoja de trabajo sin crearlo',
    (tester) async {
      await _crearDbVacia();
      await _abrirNuevoTrabajoDesdeFichaDeCliente(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Cambiar grifo',
      );
      await _tocarFuera(tester);
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();

      expect(find.text('Crear trabajo'), findsNothing);
      expect(find.text('Cambiar grifo'), findsNothing);
      expect(
        find.text('Sin trabajos todavía con este cliente.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'guardar con éxito cierra la hoja de trabajo sin pedir confirmación',
    (tester) async {
      await _crearDbVacia();
      await _abrirNuevoTrabajoDesdeFichaDeCliente(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Cambiar grifo',
      );
      await tester.tap(find.text('Crear trabajo'));
      await tester.pumpAndSettle();

      expect(find.text('¿Salir sin guardar?'), findsNothing);
      expect(find.text('Crear trabajo'), findsNothing);
      expect(find.text('Cambiar grifo'), findsOneWidget);
    },
  );
}
