// packages/repara_ui/test/keyboard_dismiss_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/keyboard_dismiss_bar.dart';

void main() {
  // KeyboardDismissBar envuelve la app POR FUERA del Scaffold (ver
  // main.dart, MaterialApp.builder) -- así ve el viewInsets.bottom real,
  // antes de que el propio Scaffold lo consuma al redimensionar su body
  // (resizeToAvoidBottomInset). Anidarlo dentro de un Scaffold, como hacía
  // la primera versión de este test, hace que siempre vea 0.
  Widget envolver(Widget child, {double bottomInset = 0}) => MediaQuery(
    data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: bottomInset)),
    child: MaterialApp(
      theme: buildReparaLightTheme(),
      builder: (context, app) => KeyboardDismissBar(child: app!),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('sin teclado abierto, no muestra la barra', (tester) async {
    await tester.pumpWidget(envolver(const Text('contenido')));
    expect(find.text('Ocultar teclado'), findsNothing);
  });

  testWidgets('con teclado abierto, muestra la barra para ocultarlo', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(const Text('contenido'), bottomInset: 300),
    );
    expect(find.text('contenido'), findsOneWidget);
    expect(find.text('Ocultar teclado'), findsOneWidget);
  });

  testWidgets('tocar "Ocultar teclado" quita el foco actual', (tester) async {
    final focusNode = FocusNode();
    await tester.pumpWidget(
      envolver(
        TextField(focusNode: focusNode, autofocus: true),
        bottomInset: 300,
      ),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Ocultar teclado'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });
}
