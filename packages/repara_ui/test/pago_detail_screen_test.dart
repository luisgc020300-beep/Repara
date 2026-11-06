// packages/repara_ui/test/pago_detail_screen_test.dart
//
// crear()/actualizar() de PagoService pasan por una Cloud Function real
// (FirebaseFunctions.instanceFor(...)), que no se puede invocar sin el
// emulador de Firebase -- mismo criterio de honestidad que el resto de la
// suite (ver registro_simple_pagos_test.dart en la app). Aquí se comprueba
// lo que sí se puede probar sin red: validación, el tope de presupuesto
// (que lee Firestore directamente vía PagoService.totalPagado, antes de
// llegar a la Cloud Function), la UI editable/solo lectura, y la capacidad
// inyectada para el comprobante.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_ui/miniatura_documento.dart';
import 'package:repara_ui/pago_detail_screen.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  String? ultimaUrlLanzada;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    ultimaUrlLanzada = url;
    return true;
  }
}

const _casaId = 'c1';
const _elementoId = 'e1';
const _registroId = 'r1';

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));
  tearDown(() => PagoService.debugFirestoreOverride = null);

  Widget envolver(Widget child) => MaterialApp(
    theme: buildReparaLightTheme(),
    home: child,
  );

  testWidgets('importe vacío o inválido muestra un error y no intenta guardar', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        const PagoDetailScreen(
          casaId: _casaId,
          elementoId: _elementoId,
          registroId: _registroId,
          registroTitulo: 'Caldera',
          presupuesto: null,
          editable: true,
        ),
      ),
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Introduce un importe válido.'), findsOneWidget);
  });

  testWidgets(
    'un importe que supera el presupuesto restante muestra el tope disponible',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('casas')
          .doc(_casaId)
          .collection('elementos')
          .doc(_elementoId)
          .collection('registros')
          .doc(_registroId)
          .collection('pagos')
          .add({
            'fecha': Timestamp.fromDate(DateTime(2026, 10, 1)),
            'importe': 700,
          });
      PagoService.debugFirestoreOverride = db;

      await tester.pumpWidget(
        envolver(
          const PagoDetailScreen(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            editable: true,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '500');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Como mucho puedes registrar 300.00 €'),
        findsOneWidget,
      );
    },
  );

  testWidgets('no editable: sin campos de texto ni botón de guardar/eliminar', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        PagoDetailScreen(
          casaId: _casaId,
          elementoId: _elementoId,
          registroId: _registroId,
          registroTitulo: 'Caldera',
          presupuesto: null,
          editable: false,
          pago: Pago(id: 'pago000001', fecha: DateTime(2026, 10, 1), importe: 120),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Guardar'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('120 €'), findsOneWidget);
  });

  testWidgets(
    'editable con un pago existente muestra el botón de eliminar',
    (tester) async {
      await tester.pumpWidget(
        envolver(
          PagoDetailScreen(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: null,
            editable: true,
            pago: Pago(id: 'pago000001', fecha: DateTime(2026, 10, 1), importe: 120),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    },
  );

  testWidgets(
    'con un comprobante y sin verificarAcceso, abre el documento directamente',
    (tester) async {
      final fake = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fake;
      await tester.pumpWidget(
        envolver(
          PagoDetailScreen(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: null,
            editable: false,
            pago: Pago(
              id: 'pago000001',
              fecha: DateTime(2026, 10, 1),
              importe: 120,
              comprobante: 'https://example.com/recibo.pdf',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MiniaturaDocumento), findsOneWidget);
      // scrollUntilVisible para en cuanto el widget EXISTE en el árbol, no
      // necesariamente dentro del viewport visible todavía -- un segundo
      // arrastre de sobra lo deja ya tocable de verdad (mismo patrón que
      // registro_simple_pagos_test.dart en la app).
      await tester.scrollUntilVisible(
        find.byType(MiniaturaDocumento),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MiniaturaDocumento));
      await tester.pumpAndSettle();

      expect(fake.ultimaUrlLanzada, 'https://example.com/recibo.pdf');
    },
  );

  testWidgets(
    'con un comprobante y verificarAcceso que deniega, no llega a abrir nada',
    (tester) async {
      final fake = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fake;
      var verificado = false;
      await tester.pumpWidget(
        envolver(
          PagoDetailScreen(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: null,
            editable: false,
            pago: Pago(
              id: 'pago000001',
              fecha: DateTime(2026, 10, 1),
              importe: 120,
              comprobante: 'https://example.com/recibo.pdf',
            ),
            verificarAcceso: (_) async {
              verificado = true;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byType(MiniaturaDocumento),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MiniaturaDocumento));
      await tester.pumpAndSettle();

      expect(verificado, isTrue);
      expect(fake.ultimaUrlLanzada, isNull);
    },
  );
}
