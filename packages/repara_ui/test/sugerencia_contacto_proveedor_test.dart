// test/sugerencia_contacto_proveedor_test.dart
//
// Integración de Contactos en el escaneo documental (CEO, noviembre 2026):
// el banner de sugerencia nunca decide nada por sí solo -- solo pinta la
// propuesta y delega en onConfirmar/onDescartar, que decide quien lo
// integra (_RevisionDocumentoScreenState), nunca este widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/nuevo_documento_flow.dart';

const _contactoConEspecialidad = (
  id: 'c1',
  nombre: 'Fontanería López',
  especialidad: 'Fontanero',
);
const _contactoSinEspecialidad = (
  id: 'c2',
  nombre: 'Eléctrica Ruiz',
  especialidad: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required ({String id, String nombre, String? especialidad}) contacto,
  required VoidCallback onConfirmar,
  required VoidCallback onDescartar,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildReparaLightTheme(),
      home: Scaffold(
        body: SugerenciaContactoProveedor(
          contacto: contacto,
          onConfirmar: onConfirmar,
          onDescartar: onDescartar,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el nombre y la especialidad del contacto propuesto', (
    tester,
  ) async {
    await _pump(
      tester,
      contacto: _contactoConEspecialidad,
      onConfirmar: () {},
      onDescartar: () {},
    );

    expect(
      find.textContaining('Fontanería López'),
      findsOneWidget,
    );
    expect(find.textContaining('Fontanero'), findsOneWidget);
  });

  testWidgets('sin especialidad, muestra solo el nombre sin paréntesis vacíos', (
    tester,
  ) async {
    await _pump(
      tester,
      contacto: _contactoSinEspecialidad,
      onConfirmar: () {},
      onDescartar: () {},
    );

    expect(find.text('¿Es tu contacto "Eléctrica Ruiz"?'), findsOneWidget);
  });

  testWidgets(
    'no llama a ningún callback solo por mostrarse -- nunca asocia nada sin confirmación',
    (tester) async {
      var confirmado = false;
      var descartado = false;
      await _pump(
        tester,
        contacto: _contactoConEspecialidad,
        onConfirmar: () => confirmado = true,
        onDescartar: () => descartado = true,
      );

      expect(confirmado, isFalse);
      expect(descartado, isFalse);
    },
  );

  testWidgets('tocar "Sí, es este contacto" llama a onConfirmar', (
    tester,
  ) async {
    var confirmado = false;
    await _pump(
      tester,
      contacto: _contactoConEspecialidad,
      onConfirmar: () => confirmado = true,
      onDescartar: () {},
    );

    await tester.tap(find.text('Sí, es este contacto'));
    await tester.pump();

    expect(confirmado, isTrue);
  });

  testWidgets('tocar "No es él" llama a onDescartar, no a onConfirmar', (
    tester,
  ) async {
    var confirmado = false;
    var descartado = false;
    await _pump(
      tester,
      contacto: _contactoConEspecialidad,
      onConfirmar: () => confirmado = true,
      onDescartar: () => descartado = true,
    );

    await tester.tap(find.text('No es él'));
    await tester.pump();

    expect(descartado, isTrue);
    expect(confirmado, isFalse);
  });
}
