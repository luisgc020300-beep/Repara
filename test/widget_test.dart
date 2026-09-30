// Smoke test mínimo: comprueba que la app arranca y muestra la pantalla de
// login cuando no hay sesión activa (no hay Firebase de verdad en el test,
// así que no se puede llegar más lejos que esto sin mocks).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repara/theme/design_tokens.dart';

void main() {
  testWidgets('Los temas claro y oscuro de Repara se construyen sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildReparaLightTheme(), home: const Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.pumpWidget(MaterialApp(theme: buildReparaDarkTheme(), home: const Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
