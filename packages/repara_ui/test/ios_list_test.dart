// packages/repara_ui/test/ios_list_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/ios_list.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(
    theme: buildReparaLightTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('IosSection con rows vacías no pinta nada', (tester) async {
    await tester.pumpWidget(envolver(const IosSection(rows: [])));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('IosSection pinta header, filas y footer', (tester) async {
    await tester.pumpWidget(
      envolver(
        IosSection(
          header: 'sección',
          footer: 'nota al pie',
          rows: [
            IosRow(icon: Icons.home, iconColor: Colors.blue, title: 'Fila 1'),
          ],
        ),
      ),
    );
    expect(find.text('SECCIÓN'), findsOneWidget);
    expect(find.text('Fila 1'), findsOneWidget);
    expect(find.text('nota al pie'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('IosRow muestra subtítulo y chevron cuando onTap navega', (
    tester,
  ) async {
    var tocado = false;
    await tester.pumpWidget(
      envolver(
        IosRow(
          icon: Icons.build,
          iconColor: Colors.blue,
          title: 'Título',
          subtitle: 'Subtítulo',
          onTap: () => tocado = true,
        ),
      ),
    );
    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Subtítulo'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.text('Título'));
    expect(tocado, isTrue);
  });

  testWidgets('IosRow sin chevron cuando showChevron es false', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        IosRow(
          icon: Icons.delete,
          iconColor: Colors.red,
          title: 'Eliminar',
          showChevron: false,
          onTap: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('IosValueRow alinea la etiqueta y el valor', (tester) async {
    await tester.pumpWidget(
      envolver(const IosValueRow(label: 'Coste', value: '120 €')),
    );
    expect(find.text('Coste'), findsOneWidget);
    expect(find.text('120 €'), findsOneWidget);
  });
}
