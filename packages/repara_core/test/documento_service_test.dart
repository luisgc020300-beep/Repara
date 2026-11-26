// test/documento_service_test.dart
//
// Integración de Contactos en el escaneo documental (CEO, noviembre 2026):
// SugerenciaIA.fromMap debe leer el nuevo campo proveedorSugerido igual que
// ya lee elementoSugerido -- misma forma, mismo criterio (null si falta o
// si la IA no encontró ninguna coincidencia razonable).
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/documento_service.dart';

void main() {
  group('SugerenciaIA.fromMap', () {
    test('lee proveedorSugerido cuando la IA propone un contacto', () {
      final sugerencia = SugerenciaIA.fromMap({
        'tipo': 'factura',
        'proveedor': 'Fontaneria Lopez S.L.',
        'proveedorSugerido': 'Fontanería López',
      });

      expect(sugerencia.proveedor, 'Fontaneria Lopez S.L.');
      expect(sugerencia.proveedorSugerido, 'Fontanería López');
    });

    test('proveedorSugerido queda en null si la IA no lo incluye', () {
      final sugerencia = SugerenciaIA.fromMap({
        'tipo': 'factura',
        'proveedor': 'Alguien sin contacto guardado',
      });

      expect(sugerencia.proveedorSugerido, isNull);
      expect(sugerencia.proveedor, 'Alguien sin contacto guardado');
    });

    test('proveedorSugerido explícitamente null se lee como null', () {
      final sugerencia = SugerenciaIA.fromMap({
        'tipo': 'factura',
        'proveedor': 'Alguien sin contacto guardado',
        'proveedorSugerido': null,
      });

      expect(sugerencia.proveedorSugerido, isNull);
    });

    test('proveedor y proveedorSugerido son independientes -- el texto libre nunca se pierde', () {
      final sugerencia = SugerenciaIA.fromMap({
        'tipo': 'factura',
        'proveedor': 'Texto exacto leído del documento',
        'proveedorSugerido': null,
      });

      expect(sugerencia.proveedor, 'Texto exacto leído del documento');
      expect(sugerencia.proveedorSugerido, isNull);
    });
  });
}
