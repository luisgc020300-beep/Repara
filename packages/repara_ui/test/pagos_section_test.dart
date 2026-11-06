// packages/repara_ui/test/pagos_section_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/pago_service.dart';
import 'package:repara_core/registro.dart' show RolEnTrabajo;
import 'package:repara_ui/pago_detail_screen.dart';
import 'package:repara_ui/pagos_section.dart';
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

Future<FakeFirebaseFirestore> _prepararConPago({String? comprobante}) async {
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
        'fecha': Timestamp.fromDate(DateTime(2026, 10, 29)),
        'importe': 500,
        'concepto': 'Primer pago',
        'createdBy': 'u1',
        'comprobante': ?comprobante,
      });
  PagoService.debugFirestoreOverride = db;
  return db;
}

void main() {
  late _FakeUrlLauncherPlatform fakeLauncher;

  setUpAll(() => initializeDateFormatting('es_ES'));
  setUp(() => fakeLauncher = _FakeUrlLauncherPlatform());
  tearDown(() => PagoService.debugFirestoreOverride = null);

  Widget envolver(Widget child) => MaterialApp(
    theme: buildReparaLightTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('sin pagos, muestra el estado vacío', (tester) async {
    PagoService.debugFirestoreOverride = FakeFirebaseFirestore();
    await tester.pumpWidget(
      envolver(
        const PagosSection(
          casaId: _casaId,
          elementoId: _elementoId,
          registroId: _registroId,
          registroTitulo: 'Caldera',
          presupuesto: null,
          rol: RolEnTrabajo.propietario,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin pagos registrados todavía.'), findsOneWidget);
  });

  testWidgets(
    'editable + onAnadirPago: "Añadir pago" aparece y pasa los datos correctos',
    (tester) async {
      await _prepararConPago();
      String? casaRecibida;
      String? conceptoRecibido;
      await tester.pumpWidget(
        envolver(
          PagosSection(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            rol: RolEnTrabajo.propietario,
            onAnadirPago: (
              context, {
              required casaId,
              required elementoId,
              required registroId,
              required registroTitulo,
              required presupuesto,
              required conceptoSugerido,
              verificarAcceso,
            }) {
              casaRecibida = casaId;
              conceptoRecibido = conceptoSugerido;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Añadir pago'), findsOneWidget);
      await tester.tap(find.text('Añadir pago'));
      expect(casaRecibida, _casaId);
      expect(conceptoRecibido, 'Pago 2');
    },
  );

  testWidgets(
    'rol profesional (no editable): "Añadir pago" no aparece aunque haya capacidad',
    (tester) async {
      await _prepararConPago();
      await tester.pumpWidget(
        envolver(
          PagosSection(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            rol: RolEnTrabajo.profesional,
            onAnadirPago: (
              context, {
              required casaId,
              required elementoId,
              required registroId,
              required registroTitulo,
              required presupuesto,
              required conceptoSugerido,
              verificarAcceso,
            }) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Añadir pago'), findsNothing);
    },
  );

  testWidgets(
    'editable sin onAnadirPago: "Añadir pago" tampoco aparece',
    (tester) async {
      await _prepararConPago();
      await tester.pumpWidget(
        envolver(
          const PagosSection(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            rol: RolEnTrabajo.propietario,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Añadir pago'), findsNothing);
    },
  );

  testWidgets(
    'tocar un pago sin comprobante solo ofrece editar/ver datos',
    (tester) async {
      await _prepararConPago();
      await tester.pumpWidget(
        envolver(
          const PagosSection(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            rol: RolEnTrabajo.propietario,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primer pago'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir documento'), findsNothing);
      expect(find.text('Editar datos'), findsOneWidget);
    },
  );

  testWidgets(
    'con comprobante y verificarAcceso que deniega, "Abrir documento" no llega a abrir nada',
    (tester) async {
      UrlLauncherPlatform.instance = fakeLauncher;
      await _prepararConPago(comprobante: 'https://example.com/recibo.pdf');
      await tester.pumpWidget(
        envolver(
          PagosSection(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            rol: RolEnTrabajo.propietario,
            verificarAcceso: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primer pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir documento'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.ultimaUrlLanzada, isNull);
    },
  );

  testWidgets(
    'con comprobante y sin verificarAcceso, "Abrir documento" abre directamente',
    (tester) async {
      UrlLauncherPlatform.instance = fakeLauncher;
      await _prepararConPago(comprobante: 'https://example.com/recibo.pdf');
      await tester.pumpWidget(
        envolver(
          const PagosSection(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            rol: RolEnTrabajo.propietario,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primer pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir documento'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.ultimaUrlLanzada, 'https://example.com/recibo.pdf');
    },
  );

  testWidgets(
    'rol profesional (no editable): "Editar datos" aparece como "Ver datos" y abre PagoDetailScreen de solo lectura',
    (tester) async {
      await _prepararConPago();
      await tester.pumpWidget(
        envolver(
          const PagosSection(
            casaId: _casaId,
            elementoId: _elementoId,
            registroId: _registroId,
            registroTitulo: 'Caldera',
            presupuesto: 1000,
            rol: RolEnTrabajo.profesional,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primer pago'));
      await tester.pumpAndSettle();
      expect(find.text('Ver datos'), findsOneWidget);

      await tester.tap(find.text('Ver datos'));
      await tester.pumpAndSettle();

      final pantalla = tester.widget<PagoDetailScreen>(
        find.byType(PagoDetailScreen),
      );
      expect(pantalla.editable, isFalse);
    },
  );
}
