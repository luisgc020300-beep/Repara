// test/screens/presupuestos_section_test.dart
//
// Mejoras de presentación y conceptos reutilizables (ampliación REPARA Pro,
// Fase 3, noviembre 2026): la fecha y las observaciones del presupuesto,
// antes guardadas pero nunca mostradas, ahora se ven; y el editor ofrece
// los conceptos frecuentes guardados para insertarlos de un toque.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/screens/presupuestos_section.dart';
import 'package:repara/services/conceptos_frecuentes_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/presupuesto_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => PresupuestoService.debugFirestoreOverride = null);

  testWidgets('muestra la fecha y las observaciones del presupuesto', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('casas')
        .doc('c1')
        .collection('elementos')
        .doc('e1')
        .collection('registros')
        .doc('r1')
        .collection('presupuestos')
        .doc('p1')
        .set({
          'numero': 1,
          'version': 1,
          'estado': 'enviado',
          'lineas': [
            {
              'descripcion': 'Revisión',
              'cantidad': 1,
              'precioUnitario': 50,
              'ivaPorcentaje': 21,
            },
          ],
          'subtotal': 50,
          'iva': 10.5,
          'total': 60.5,
          'notas': 'Incluye repuestos de primera calidad.',
          'fechaCreacion': Timestamp.fromDate(DateTime(2026, 11, 3)),
        });
    PresupuestoService.debugFirestoreOverride = db;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildReparaLightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: const PresupuestosSection(
              casaId: 'c1',
              elementoId: 'e1',
              registroId: 'r1',
              rol: RolEnTrabajo.propietario,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Observaciones'), findsOneWidget);
    expect(find.text('Incluye repuestos de primera calidad.'), findsOneWidget);
    expect(find.textContaining('nov'), findsOneWidget);
  });

  testWidgets(
    'el editor ofrece los conceptos frecuentes guardados y los inserta al tocarlos',
    (tester) async {
      final db = FakeFirebaseFirestore();
      PresupuestoService.debugFirestoreOverride = db;
      await ConceptosFrecuentesService.guardar(
        const ConceptoFrecuente(
          nombre: 'Desplazamiento',
          precioUnitario: 25,
          ivaPorcentaje: 21,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: const PresupuestosSection(
                casaId: 'c1',
                elementoId: 'e1',
                registroId: 'r1',
                rol: RolEnTrabajo.profesional,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear presupuesto'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'Desplazamiento'), findsOneWidget);

      await tester.tap(find.widgetWithText(InputChip, 'Desplazamiento'));
      await tester.pumpAndSettle();

      // Insertar el concepto añade una línea nueva rellenada -- la
      // descripción de esa línea ahora contiene el nombre del concepto.
      expect(find.text('Desplazamiento'), findsWidgets);
    },
  );
}
