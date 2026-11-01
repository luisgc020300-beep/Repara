// test/screens/nuevo_registro_ya_realizado_test.dart
//
// "¿Ya se ha realizado el trabajo?" en "Añadir evento" (CEO, noviembre
// 2026): antes un registro simple siempre nacía dando por hecho que el
// trabajo ya había pasado -- ahora se puede marcar que todavía no se ha
// hecho. Mismo criterio que nuevo_registro_profesional_test.dart: solo
// comprueba la visibilidad/valor por defecto del interruptor, nunca llega a
// tocar "Guardar" -- eso llama a FirebaseAuth.instance, que no se puede
// invocar en este entorno de test sin Firebase Core inicializado.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/screens/nuevo_registro_screen.dart';
import 'package:repara/services/contacto_service.dart';
import 'package:repara/theme/design_tokens.dart';

Future<void> _abrirPantalla(WidgetTester tester) async {
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
  setUp(() => ContactoService.debugFirestoreOverride = FakeFirebaseFirestore());
  tearDown(() => ContactoService.debugFirestoreOverride = null);

  testWidgets(
    'por defecto, "¿Ya se ha realizado el trabajo?" está activado (comportamiento de siempre)',
    (tester) async {
      await _abrirPantalla(tester);
      await tester.scrollUntilVisible(
        find.text('¿Ya se ha realizado el trabajo?'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final interruptor = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '¿Ya se ha realizado el trabajo?'),
      );
      expect(interruptor.value, isTrue);
    },
  );

  testWidgets(
    'activar "¿Lo hace un profesional?" oculta "¿Ya se ha realizado el trabajo?" -- ese registro nace "nuevo" por su propio flujo',
    (tester) async {
      await _abrirPantalla(tester);

      await tester.tap(find.text('¿Lo hace un profesional?'));
      await tester.pumpAndSettle();

      expect(find.text('¿Ya se ha realizado el trabajo?'), findsNothing);
    },
  );
}
