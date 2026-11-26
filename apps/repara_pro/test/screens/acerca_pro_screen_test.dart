// test/screens/acerca_pro_screen_test.dart
//
// Paridad de "Acerca de REPARA" con Hogar (auditoría de calidad, noviembre
// 2026): la sección "Ayuda" debía tener una fila "Guía de uso" que llevara
// a la guía nativa, igual que ya tenía Hogar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_pro/screens/acerca_pro_screen.dart';
import 'package:repara_pro/screens/guia_uso_pro_screen.dart';

void main() {
  testWidgets('Acerca de REPARA ofrece la Guía de uso y lleva a ella', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildReparaLightTheme(),
        home: const AcercaProScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guía de uso'), findsOneWidget);

    await tester.tap(find.text('Guía de uso'));
    await tester.pumpAndSettle();

    expect(find.byType(GuiaUsoProScreen), findsOneWidget);
    expect(find.text('Todo lo que hace REPARA Pro'), findsOneWidget);
  });

  testWidgets(
    'la Guía de uso de Pro responde a su contenido real, no al de Hogar',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReparaLightTheme(),
          home: const GuiaUsoProScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final listas = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text('Clientes compartidos y clientes privados'),
        300,
        scrollable: listas.first,
      );
      expect(
        find.text('Clientes compartidos y clientes privados'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Presupuestos, cambios de alcance y pagos'),
        300,
        scrollable: listas.first,
      );
      expect(
        find.text('Presupuestos, cambios de alcance y pagos'),
        findsOneWidget,
      );
      // Nada de "elementos"/"garantías" (dominio exclusivo de Hogar).
      expect(find.textContaining('garantía'), findsNothing);
    },
  );
}
