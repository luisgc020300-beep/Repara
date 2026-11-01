// test/screens/elemento_resumen_pdf_test.dart
//
// Ficha PDF de un elemento (CEO, octubre 2026): "Compartir resumen" y
// "Generar ficha PDF" en la propia pantalla del elemento, más completa que
// el PDF de un solo trabajo -- sus datos propios y su historial completo.
// Dos tipos de prueba, mismo criterio que expediente_vivienda_dossier_pdf_
// test.dart / expediente_vivienda_pdf_test.dart: construcción del PDF en
// Dart puro (sin FakeFirebaseFirestore) y flujo de UI con
// FakeFirebaseFirestore.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara/models/cambio_alcance.dart';
import 'package:repara/models/casa.dart';
import 'package:repara/models/elemento.dart';
import 'package:repara/models/pago.dart';
import 'package:repara/models/registro.dart';
import 'package:repara/screens/elemento_detail_screen.dart';
import 'package:repara/screens/elemento_resumen_pdf.dart';
import 'package:repara/services/cambio_alcance_service.dart';
import 'package:repara/services/documento_service.dart';
import 'package:repara/services/elemento_service.dart';
import 'package:repara/services/habitacion_service.dart';
import 'package:repara/services/pago_service.dart';
import 'package:repara/services/registro_service.dart';
import 'package:repara/theme/design_tokens.dart';
import 'package:repara/widgets/pdf_trabajo.dart';

const _casa = Casa(
  id: 'c1',
  nombre: 'Casa de Prueba',
  ownerUid: 'u1',
  members: ['u1'],
  memberProfiles: {},
);

void _esperarPdfValido(List<int> bytes) {
  expect(bytes, isNotEmpty);
  expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
}

void _activarOverrides(FakeFirebaseFirestore db) {
  ElementoService.debugFirestoreOverride = db;
  RegistroService.debugFirestoreOverride = db;
  DocumentoService.debugFirestoreOverride = db;
  HabitacionService.debugFirestoreOverride = db;
  PagoService.debugFirestoreOverride = db;
  CambioAlcanceService.debugFirestoreOverride = db;
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  tearDown(() {
    ElementoService.debugFirestoreOverride = null;
    RegistroService.debugFirestoreOverride = null;
    DocumentoService.debugFirestoreOverride = null;
    HabitacionService.debugFirestoreOverride = null;
    PagoService.debugFirestoreOverride = null;
    CambioAlcanceService.debugFirestoreOverride = null;
  });

  group('ElementoResumenPdf.construirBytes (Dart puro)', () {
    test('elemento sin ningún trabajo todavía genera un PDF válido', () async {
      final bytes = await ElementoResumenPdf.construirBytes(
        casa: _casa,
        elemento: const Elemento(id: 'e1', nombre: 'Pérgolas'),
        ubicacion: 'Jardín',
        trabajos: const [],
      );
      _esperarPdfValido(bytes);
    });

    test(
      'elemento con datos completos y varios trabajos (con pagos, sin pagos, con cambio de alcance) genera un PDF válido',
      () async {
        final bytes = await ElementoResumenPdf.construirBytes(
          casa: _casa,
          elemento: Elemento(
            id: 'e1',
            nombre: 'Pérgolas',
            marca: 'Pérgolas del Sur',
            fechaInstalacion: DateTime(2020, 10, 30),
            coste: 1000,
            profesionalNombre: 'Metalistero',
            garantiaHasta: DateTime.now().add(const Duration(days: 400)),
          ),
          ubicacion: 'Jardín',
          trabajos: [
            TrabajoConDetalle(
              registro: Registro(
                id: 'r1',
                elementoNombre: 'Pérgolas',
                tipo: TipoRegistro.instalacion,
                esConProfesional: false,
                titulo: 'Placa de madera',
                estado: EstadoRegistro.pendientePago,
                fecha: DateTime(2026, 10, 30),
                coste: 600,
              ),
              pagos: [
                Pago(id: 'p1', fecha: DateTime(2026, 10, 30), importe: 200),
              ],
            ),
            TrabajoConDetalle(
              registro: Registro(
                id: 'r2',
                elementoNombre: 'Pérgolas',
                tipo: TipoRegistro.reforma,
                esConProfesional: true,
                titulo: 'Refuerzo',
                estado: EstadoRegistro.terminado,
                fecha: DateTime(2026, 10, 18),
                presupuesto: 700,
              ),
              cambios: const [
                CambioAlcance(
                  id: 'ca1',
                  titulo: 'Travesaño adicional',
                  estado: EstadoCambioAlcance.aprobado,
                  importeAdicional: 45,
                ),
              ],
            ),
          ],
        );
        _esperarPdfValido(bytes);
      },
    );
  });

  group('ElementoDetailScreen -- UI', () {
    testWidgets(
      'ofrece "Compartir resumen" y "Generar ficha PDF"',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
          'nombre': 'Pérgolas',
        });
        _activarOverrides(db);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildReparaLightTheme(),
            home: const ElementoDetailScreen(casa: _casa, elementoId: 'e1'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Compartir resumen'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Compartir resumen'), findsOneWidget);
        expect(find.text('Generar ficha PDF'), findsOneWidget);
      },
    );

    testWidgets(
      'tocar "Generar ficha PDF" muestra antes una hoja explicativa con aviso de privacidad',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await db.collection('casas').doc(_casa.id).collection('elementos').doc('e1').set({
          'nombre': 'Pérgolas',
        });
        _activarOverrides(db);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildReparaLightTheme(),
            home: const ElementoDetailScreen(casa: _casa, elementoId: 'e1'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Generar ficha PDF'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Generar ficha PDF'));
        await tester.pumpAndSettle();

        expect(find.text('Generar ficha PDF del elemento'), findsOneWidget);
        expect(
          find.textContaining('revísalo antes de compartirlo con otra persona'),
          findsOneWidget,
        );
        expect(find.text('Generar PDF'), findsOneWidget);
      },
    );
  });
}
