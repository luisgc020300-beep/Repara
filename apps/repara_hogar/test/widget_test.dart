// Smoke test minimo: comprueba que los temas de REPARA Hogar se
// construyen sin errores (no hay Firebase de verdad en el test, asi que
// ReparaHogarApp no se puede montar aqui sin mocks; mismo criterio que
// test/widget_test.dart del monolito y de apps/repara_pro).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repara_core/design_tokens.dart';

void main() {
  testWidgets('Los temas claro y oscuro de REPARA Hogar se construyen sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildReparaLightTheme(), home: const Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.pumpWidget(MaterialApp(theme: buildReparaDarkTheme(), home: const Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
