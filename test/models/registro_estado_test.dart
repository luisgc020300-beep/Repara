// test/models/registro_estado_test.dart
//
// "Terminado" exige trabajo hecho Y cobrado, no solo lo primero (CEO,
// octubre 2026) -- estadoInicialRegistroSimple()/montoDebidoRegistro() son
// las dos piezas puras que arrancan y alimentan esa regla desde el lado
// cliente (ver registro.dart). El resto del mecanismo (transiciones
// automáticas al pagar/editar/borrar un pago) vive en Cloud Functions y se
// cubre en functions-tests/payments.test.js, fuera del alcance de un test
// Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/models/registro.dart';

void main() {
  group('estadoInicialRegistroSimple()', () {
    test('sin coste (null), nace terminado -- nada que cobrar', () {
      expect(estadoInicialRegistroSimple(null), EstadoRegistro.terminado);
    });

    test('con coste 0, nace terminado -- nada que cobrar', () {
      expect(estadoInicialRegistroSimple(0), EstadoRegistro.terminado);
    });

    test('con coste positivo, nace pendientePago -- todavía no hay ningún pago', () {
      expect(estadoInicialRegistroSimple(2000), EstadoRegistro.pendientePago);
    });
  });

  group('montoDebidoRegistro()', () {
    Registro registro({double? coste, double? presupuesto, bool esConProfesional = false}) =>
        Registro(
          id: '',
          elementoNombre: 'Caldera',
          tipo: TipoRegistro.instalacion,
          esConProfesional: esConProfesional,
          titulo: 'Instalación',
          estado: EstadoRegistro.terminado,
          fecha: DateTime(2026, 1, 1),
          coste: coste,
          presupuesto: presupuesto,
        );

    test('un registro con profesional usa el presupuesto', () {
      final r = registro(esConProfesional: true, presupuesto: 500);
      expect(montoDebidoRegistro(r), 500);
    });

    test('un registro simple usa el coste', () {
      final r = registro(coste: 2000);
      expect(montoDebidoRegistro(r), 2000);
    });

    test('sin coste ni presupuesto, no hay nada que cobrar', () {
      expect(montoDebidoRegistro(registro()), isNull);
    });
  });
}
