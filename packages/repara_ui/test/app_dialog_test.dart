// packages/repara_ui/test/app_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_ui/app_dialog.dart';

void main() {
  Widget envolver(Widget Function(BuildContext) builder) =>
      MaterialApp(home: Scaffold(body: Builder(builder: builder)));

  // promptText() dispone su TextEditingController justo al resolverse
  // showDialog(), mientras el TextField todavía está en el árbol animando
  // el cierre -- un tester.pump() ahí reconstruye ese TextField (p.ej. el
  // borde animado del InputDecorator) y choca con el controller ya
  // dispuesto (hallazgo incidental de esta extracción, no introducido por
  // ella: app_dialog.dart no cambia de comportamiento). Para leer el
  // resultado sin pasar por esa reconstrucción, se vacía la cola de
  // microtasks (el result de Navigator.pop() se resuelve sin esperar frame)
  // sin llegar a pedir un frame nuevo con tester.pump().
  Future<void> vaciarMicrotasks() async {
    // Future.delayed programaría un timer -- bajo el reloj simulado de
    // testWidgets eso nunca se dispara sin un tester.pump() que lo avance
    // (justo lo que se quiere evitar aquí). Future.value().then() es un
    // microtask puro: se procesa solo, sin frame ni reloj.
    for (var i = 0; i < 10; i++) {
      await Future<void>.value();
    }
  }

  testWidgets('confirm() devuelve true al tocar la acción principal', (
    tester,
  ) async {
    bool? resultado;
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () async {
            resultado = await AppDialog.confirm(
              context,
              title: '¿Seguro?',
              confirmLabel: 'Sí',
            );
          },
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();

    expect(resultado, isTrue);
  });

  testWidgets('confirm() devuelve false al cancelar', (tester) async {
    bool? resultado;
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () async {
            resultado = await AppDialog.confirm(
              context,
              title: '¿Seguro?',
              confirmLabel: 'Sí',
            );
          },
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(resultado, isFalse);
  });

  testWidgets('promptText() devuelve el texto recortado (trim)', (
    tester,
  ) async {
    String? resultado;
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () async {
            resultado = await AppDialog.promptText(
              context,
              title: 'Nombre',
              initialValue: '  Caldera  ',
            );
          },
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await vaciarMicrotasks();

    expect(resultado, 'Caldera');
  });

  testWidgets('promptText() devuelve null al cancelar', (tester) async {
    String? resultado = 'sin tocar';
    await tester.pumpWidget(
      envolver(
        (context) => ElevatedButton(
          onPressed: () async {
            resultado = await AppDialog.promptText(context, title: 'Nombre');
          },
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await vaciarMicrotasks();

    expect(resultado, isNull);
  });
}
