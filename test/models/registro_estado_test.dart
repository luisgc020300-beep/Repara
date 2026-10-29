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

  group('Registro.proximoPagoEstimado()', () {
    Registro registroConPlan({int? frecuencia}) => Registro(
          id: '',
          elementoNombre: 'Salón',
          tipo: TipoRegistro.instalacion,
          esConProfesional: false,
          titulo: 'Aire acondicionado',
          estado: EstadoRegistro.pendientePago,
          fecha: DateTime(2026, 1, 15),
          coste: 1200,
          plazoFrecuenciaMeses: frecuencia,
          plazoImporte: 300,
        );

    test('sin plan (plazoFrecuenciaMeses null), no hay próximo pago que calcular', () {
      expect(registroConPlan().proximoPagoEstimado(null), isNull);
    });

    test('sin ningún pago todavía, se cuenta desde la fecha del registro', () {
      final r = registroConPlan(frecuencia: 3);
      expect(r.proximoPagoEstimado(null), DateTime(2026, 4, 15));
    });

    test('con un pago ya registrado, se cuenta desde la fecha de ese último pago', () {
      final r = registroConPlan(frecuencia: 1);
      expect(r.proximoPagoEstimado(DateTime(2026, 6, 10)), DateTime(2026, 7, 10));
    });
  });
}
