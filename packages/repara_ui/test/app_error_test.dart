// packages/repara_ui/test/app_error_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(
    theme: buildReparaLightTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('AppError.show() muestra el mensaje en un SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppError.show(context, 'Algo falló'),
            child: const Text('disparar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('disparar'));
    await tester.pump();

    expect(find.text('Algo falló'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('AppError.showSuccess() muestra el icono de éxito', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppError.showSuccess(context, 'Guardado'),
            child: const Text('disparar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('disparar'));
    await tester.pump();

    expect(find.text('Guardado'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('EmptyHint muestra el mensaje y el icono por defecto', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(const EmptyHint(message: 'Nada por aquí todavía')),
    );
    expect(find.text('Nada por aquí todavía'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('EmptyHint acepta un icono distinto al por defecto', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        const EmptyHint(message: 'Sin fotos', icon: Icons.photo_outlined),
      ),
    );
    expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsNothing);
  });
}
