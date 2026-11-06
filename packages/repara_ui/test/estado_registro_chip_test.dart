// packages/repara_ui/test/estado_registro_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/registro.dart';
import 'package:repara_ui/estado_registro_chip.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(
    theme: buildReparaLightTheme(),
    home: Scaffold(body: child),
  );

  test('nombreEstadoRegistro() traduce cada estado', () {
    expect(nombreEstadoRegistro(EstadoRegistro.nuevo), 'Nuevo');
    expect(nombreEstadoRegistro(EstadoRegistro.presupuestado), 'Presupuestado');
    expect(nombreEstadoRegistro(EstadoRegistro.enCurso), 'En curso');
    expect(
      nombreEstadoRegistro(EstadoRegistro.pendienteConfirmacion),
      'Pendiente de confirmación',
    );
    expect(nombreEstadoRegistro(EstadoRegistro.pendientePago), 'Pago pendiente');
    expect(nombreEstadoRegistro(EstadoRegistro.terminado), 'Terminado');
    expect(nombreEstadoRegistro(EstadoRegistro.archivado), 'Archivado');
  });

  test('iconoTipoRegistro() da un icono distinto por tipo', () {
    final iconos = TipoRegistro.values.map(iconoTipoRegistro).toSet();
    expect(iconos.length, TipoRegistro.values.length);
  });

  testWidgets('EstadoRegistroChip muestra el nombre del estado en mayúsculas', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(const EstadoRegistroChip(estado: EstadoRegistro.pendientePago)),
    );
    expect(find.text('PAGO PENDIENTE'), findsOneWidget);
  });

  testWidgets('AvisoRegistro muestra el mensaje y, si se pasan, las acciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        const AvisoRegistro(
          mensaje: 'Pendiente de confirmar',
          acciones: Text('Confirmar'),
        ),
      ),
    );
    expect(find.text('Pendiente de confirmar'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
  });

  testWidgets('AvisoRegistro sin acciones no las pinta', (tester) async {
    await tester.pumpWidget(
      envolver(const AvisoRegistro(mensaje: 'Solo informativo')),
    );
    expect(find.text('Solo informativo'), findsOneWidget);
  });
}
