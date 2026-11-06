// test/screens/nuevo_registro_profesional_test.dart
//
// "¿Lo hace un profesional?" en "Añadir evento" (CEO, octubre 2026): antes
// esta hoja solo creaba registros simples -- un elemento que ya existe no
// tenía ninguna vía para recibir un evento nuevo con profesional, aunque ya
// tuviera otros con profesional de antes (ver nuevo_registro_sheet.dart).
// Mismo criterio que nuevo_elemento_profesional_test.dart: solo comprueba
// la visibilidad de los campos al activar/desactivar el interruptor, nunca
// llega a tocar "Guardar" -- eso llama a FirebaseAuth.instance, que no se
// puede invocar en este entorno de test sin Firebase Core inicializado
// (ver nuevo_registro_analytics_test.dart, mismo límite real).
// Usa FakeFirebaseFirestore, nada de Firebase real.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/nuevo_registro_screen.dart';
import 'package:repara/services/contacto_service.dart';
import 'package:repara_core/registro_service.dart';
import 'package:repara_core/design_tokens.dart';

Future<void> _abrirHoja(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildReparaLightTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => abrirNuevoRegistroScreen(
                context,
                casaId: 'c1',
                elementoId: 'e1',
                elementoNombre: 'Pérgolas',
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final db = FakeFirebaseFirestore();
    RegistroService.debugFirestoreOverride = db;
    ContactoService.debugFirestoreOverride = db;
  });
  tearDown(() {
    RegistroService.debugFirestoreOverride = null;
    ContactoService.debugFirestoreOverride = null;
  });

  // Pantalla completa, no hoja compacta (rediseño visual, noviembre 2026) --
  // "Información económica" (el título de esa sección en ambas ramas, con o
  // sin profesional) queda fuera del viewport inicial, hay que bajar hasta
  // ella antes de comprobar lo que hay dentro.
  Future<void> bajarAInformacionEconomica(WidgetTester tester) =>
      tester.scrollUntilVisible(
        find.text('Información económica'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets(
    'con el interruptor desactivado (por defecto), se ven "Coste" y "Profesional"',
    (tester) async {
      await _abrirHoja(tester);
      await bajarAInformacionEconomica(tester);

      expect(find.widgetWithText(TextField, 'Coste (€)'), findsOneWidget);
      expect(find.text('Profesionales (opcional)'), findsOneWidget);
      expect(find.text('¿Se paga a plazos?'), findsOneWidget);
    },
  );

  testWidgets(
    'activar "¿Lo hace un profesional?" oculta Coste/Profesional/Plazos y explica dónde se gestionan',
    (tester) async {
      await _abrirHoja(tester);

      await tester.tap(find.text('¿Lo hace un profesional?'));
      await tester.pumpAndSettle();
      await bajarAInformacionEconomica(tester);

      expect(find.widgetWithText(TextField, 'Coste (€)'), findsNothing);
      expect(find.text('Profesionales (opcional)'), findsNothing);
      expect(find.text('¿Se paga a plazos?'), findsNothing);
      expect(find.textContaining('invita al profesional'), findsOneWidget);
    },
  );

  testWidgets(
    'desactivar el interruptor de nuevo vuelve a mostrar Coste, Profesional y Plazos',
    (tester) async {
      await _abrirHoja(tester);

      await tester.tap(find.text('¿Lo hace un profesional?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Lo hace un profesional?'));
      await tester.pumpAndSettle();
      await bajarAInformacionEconomica(tester);

      expect(find.widgetWithText(TextField, 'Coste (€)'), findsOneWidget);
      expect(find.text('Profesionales (opcional)'), findsOneWidget);
      expect(find.text('¿Se paga a plazos?'), findsOneWidget);
    },
  );
}
