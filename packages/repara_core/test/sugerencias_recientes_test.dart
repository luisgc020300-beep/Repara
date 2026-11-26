// test/sugerencias_recientes_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/sugerencias_recientes.dart';

void main() {
  group('valoresRecientesSinDuplicados', () {
    test('conserva el orden de llegada (ya asumido de más reciente a más antiguo)', () {
      expect(
        valoresRecientesSinDuplicados(['Vaillant', 'Bosch', 'Siemens']),
        ['Vaillant', 'Bosch', 'Siemens'],
      );
    });

    test('elimina duplicados exactos, conservando la primera aparición', () {
      expect(
        valoresRecientesSinDuplicados(['Bosch', 'Vaillant', 'Bosch']),
        ['Bosch', 'Vaillant'],
      );
    });

    test('ignora mayúsculas/minúsculas al comparar duplicados', () {
      expect(
        valoresRecientesSinDuplicados(['Bosch', 'bosch', 'BOSCH']),
        ['Bosch'],
      );
    });

    test('ignora espacios de más al comparar duplicados', () {
      expect(
        valoresRecientesSinDuplicados(['Bosch', '  Bosch  ', 'Bosch ']),
        ['Bosch'],
      );
    });

    test('conserva la capitalización de la PRIMERA aparición, no de las siguientes', () {
      final resultado = valoresRecientesSinDuplicados(['vaillant', 'Vaillant']);
      expect(resultado, ['vaillant']);
    });

    test('descarta valores nulos y cadenas vacías o solo espacios', () {
      expect(
        valoresRecientesSinDuplicados([null, '', '   ', 'Bosch']),
        ['Bosch'],
      );
    });

    test('devuelve una lista vacía cuando no hay ningún valor usable', () {
      expect(valoresRecientesSinDuplicados([null, '', '  ']), isEmpty);
    });

    test('limita el número de sugerencias devueltas', () {
      final muchos = List.generate(20, (i) => 'Marca $i');
      expect(valoresRecientesSinDuplicados(muchos, limite: 5).length, 5);
    });
  });

  group('filtrarSugerencias', () {
    const sugerencias = ['Vaillant', 'Bosch', 'Siemens'];

    test('con texto vacío devuelve todas las sugerencias', () {
      expect(filtrarSugerencias(sugerencias, ''), sugerencias);
    });

    test('filtra por coincidencia de subcadena', () {
      expect(filtrarSugerencias(sugerencias, 'aill'), ['Vaillant']);
    });

    test('ignora mayúsculas/minúsculas al filtrar', () {
      expect(filtrarSugerencias(sugerencias, 'BOSCH'), ['Bosch']);
    });

    test('ignora espacios de más alrededor del texto buscado', () {
      expect(filtrarSugerencias(sugerencias, '  bosch  '), ['Bosch']);
    });

    test('sin ninguna coincidencia devuelve una lista vacía', () {
      expect(filtrarSugerencias(sugerencias, 'xyz'), isEmpty);
    });
  });
}
