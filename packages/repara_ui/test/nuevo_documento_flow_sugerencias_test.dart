// test/nuevo_documento_flow_sugerencias_test.dart
//
// Fase 1 de reutilización de datos (CEO, noviembre 2026): el campo
// "Profesional / empresa emisora" de la pantalla de revisión de un
// documento generaliza el mismo RawAutocomplete ya usado en Hogar para
// "Profesional" -- sugiere proveedores ya usados en documentos anteriores
// de la casa, sin duplicados, sin forzar ninguna selección.
//
// cargarProveedoresSugeridos es opcional (igual que cargarElementosDisponibles)
// -- aquí se prueba con una función de prueba directa, sin Firestore de por
// medio: lo que hay que comprobar es que esta pantalla compartida (Hogar +
// Pro) usa el valor que le dan, nunca de dónde lo saca Hogar en producción
// (eso ya está cubierto por sugerencias_recientes_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/nuevo_documento_flow.dart';

Future<void> _abrir(
  WidgetTester tester, {
  Future<List<String>> Function(String casaId)? cargarProveedoresSugeridos,
  CargarContactosDisponibles? cargarContactosDisponibles,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildReparaLightTheme(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => iniciarNuevoDocumentoManual(
            context,
            casaId: 'c1',
            cargarProveedoresSugeridos: cargarProveedoresSugeridos,
            cargarContactosDisponibles: cargarContactosDisponibles,
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _tocarProveedor(WidgetTester tester) async {
  final campo = find.widgetWithText(TextField, 'Profesional / empresa emisora');
  await tester.scrollUntilVisible(campo, 300, scrollable: find.byType(Scrollable).first);
  await tester.tap(campo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'sin cargarProveedoresSugeridos (p.ej. Pro, o un llamador que no lo pasa), no ofrece ninguna sugerencia y no rompe la pantalla',
    (tester) async {
      await _abrir(tester);
      await _tocarProveedor(tester);

      expect(find.byType(ListTile), findsNothing);
    },
  );

  testWidgets('con sugerencias disponibles, las ofrece al tocar el campo vacío', (
    tester,
  ) async {
    await _abrir(
      tester,
      cargarProveedoresSugeridos: (_) async => [
        'Fontanería López',
        'Eléctrica Ruiz',
      ],
    );
    await _tocarProveedor(tester);

    expect(find.text('Fontanería López'), findsOneWidget);
    expect(find.text('Eléctrica Ruiz'), findsOneWidget);
  });

  testWidgets('los proveedores repetidos no se duplican en las sugerencias', (
    tester,
  ) async {
    await _abrir(
      tester,
      cargarProveedoresSugeridos: (_) async => [
        'Fontanería López',
        'Fontanería López',
      ],
    );
    await _tocarProveedor(tester);

    expect(find.text('Fontanería López'), findsOneWidget);
  });

  testWidgets(
    'escribir filtra las sugerencias ignorando mayúsculas, sin modificar el texto tecleado',
    (tester) async {
      await _abrir(
        tester,
        cargarProveedoresSugeridos: (_) async => [
          'Fontanería López',
          'Eléctrica Ruiz',
        ],
      );
      final campo = find.widgetWithText(TextField, 'Profesional / empresa emisora');
      await tester.scrollUntilVisible(campo, 300, scrollable: find.byType(Scrollable).first);
      await tester.enterText(campo, 'fontaner');
      await tester.pumpAndSettle();

      expect(find.text('Fontanería López'), findsOneWidget);
      expect(find.text('Eléctrica Ruiz'), findsNothing);
      expect(find.widgetWithText(TextField, 'fontaner'), findsOneWidget);
    },
  );

  testWidgets('tocar una sugerencia rellena el campo con ese proveedor', (
    tester,
  ) async {
    await _abrir(
      tester,
      cargarProveedoresSugeridos: (_) async => ['Fontanería López'],
    );
    await _tocarProveedor(tester);
    await tester.tap(find.text('Fontanería López').last);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Fontanería López'),
      findsOneWidget,
    );
  });

  testWidgets(
    'se puede escribir un proveedor nuevo, que no está entre las sugerencias, sin seleccionar nada',
    (tester) async {
      await _abrir(
        tester,
        cargarProveedoresSugeridos: (_) async => ['Fontanería López'],
      );
      final campo = find.widgetWithText(TextField, 'Profesional / empresa emisora');
      await tester.scrollUntilVisible(campo, 300, scrollable: find.byType(Scrollable).first);
      await tester.enterText(campo, 'Un proveedor nuevo');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Un proveedor nuevo'), findsOneWidget);
    },
  );

  testWidgets(
    'si cargarProveedoresSugeridos lanza una excepción, se sigue sin sugerencias en vez de romper la pantalla',
    (tester) async {
      await _abrir(
        tester,
        cargarProveedoresSugeridos: (_) async => throw Exception('sin permiso'),
      );
      await _tocarProveedor(tester);

      expect(find.byType(ListTile), findsNothing);
      expect(
        find.widgetWithText(TextField, 'Profesional / empresa emisora'),
        findsOneWidget,
      );
    },
  );

  // Integración de Contactos en el escaneo documental (CEO, noviembre
  // 2026): los contactos ya guardados se ofrecen también como sugerencia
  // del proveedor -- "elegir otro" distinto del que la IA haya propuesto
  // (o sin IA de por medio, como aquí) es tan simple como tocarlos en este
  // mismo desplegable, sin ninguna pantalla nueva.
  group('contactos como sugerencia del proveedor ("elegir otro")', () {
    testWidgets(
      'sin cargarContactosDisponibles, no añade ningún contacto a las sugerencias',
      (tester) async {
        await _abrir(tester);
        await _tocarProveedor(tester);

        expect(find.byType(ListTile), findsNothing);
      },
    );

    testWidgets(
      'con contactos disponibles, aparecen como sugerencia del proveedor',
      (tester) async {
        await _abrir(
          tester,
          cargarContactosDisponibles: (_) async => [
            (id: 'c1', nombre: 'Fontanería López', especialidad: 'Fontanero'),
            (id: 'c2', nombre: 'Eléctrica Ruiz', especialidad: null),
          ],
        );
        await _tocarProveedor(tester);

        expect(find.text('Fontanería López'), findsOneWidget);
        expect(find.text('Eléctrica Ruiz'), findsOneWidget);
      },
    );

    testWidgets('tocar un contacto sugerido rellena el proveedor con su nombre', (
      tester,
    ) async {
      await _abrir(
        tester,
        cargarContactosDisponibles: (_) async => [
          (id: 'c1', nombre: 'Fontanería López', especialidad: 'Fontanero'),
        ],
      );
      await _tocarProveedor(tester);
      await tester.tap(find.text('Fontanería López').last);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'Fontanería López'),
        findsOneWidget,
      );
    });

    testWidgets(
      'si cargarContactosDisponibles lanza una excepción, se sigue sin sugerencias de contacto en vez de romper la pantalla',
      (tester) async {
        await _abrir(
          tester,
          cargarContactosDisponibles: (_) async => throw Exception('sin permiso'),
        );
        await _tocarProveedor(tester);

        expect(find.byType(ListTile), findsNothing);
        expect(
          find.widgetWithText(TextField, 'Profesional / empresa emisora'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'los proveedores de documentos anteriores y los contactos se combinan sin duplicarse',
      (tester) async {
        await _abrir(
          tester,
          cargarProveedoresSugeridos: (_) async => [
            'Fontanería López',
            'Carpintería Sánchez',
          ],
          cargarContactosDisponibles: (_) async => [
            (id: 'c1', nombre: 'Fontanería López', especialidad: 'Fontanero'),
          ],
        );
        await _tocarProveedor(tester);

        expect(find.text('Fontanería López'), findsOneWidget);
        expect(find.text('Carpintería Sánchez'), findsOneWidget);
      },
    );
  });
}
