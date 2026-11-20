// packages/repara_ui/test/ayuda_primer_uso_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/ayuda_primer_uso.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // El diálogo usa context.colors (brandTint/brand/inkMuted) -- hace falta
  // el tema real de la app, no el MaterialApp por defecto (que no registra
  // esa extensión de tema), o `context.colors` lanza un null check.
  Widget envolver(Widget Function(BuildContext) builder) => MaterialApp(
    theme: buildReparaLightTheme(),
    home: Scaffold(body: Builder(builder: builder)),
  );

  Future<void> abrir(WidgetTester tester, {String clave = 'nuevo_elemento'}) async {
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () => mostrarAyudaPrimerUso(
            context,
            clave: clave,
            icon: Icons.inventory_2_outlined,
            titulo: 'Título de prueba',
            mensaje: 'Mensaje de prueba',
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('la primera vez muestra el diálogo con título y mensaje', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('Título de prueba'), findsOneWidget);
    expect(find.text('Mensaje de prueba'), findsOneWidget);
  });

  testWidgets('tocar "Entendido" cierra el diálogo', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(find.text('Título de prueba'), findsNothing);
  });

  testWidgets('la segunda vez con la misma clave no vuelve a mostrarlo', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Título de prueba'), findsNothing);
  });

  testWidgets('una clave distinta sí muestra su propio diálogo', (
    tester,
  ) async {
    await abrir(tester, clave: 'nuevo_contacto');
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    await abrir(tester, clave: 'nuevo_elemento');

    expect(find.text('Título de prueba'), findsOneWidget);
  });
}
