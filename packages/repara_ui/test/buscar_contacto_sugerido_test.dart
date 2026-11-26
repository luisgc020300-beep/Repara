// test/buscar_contacto_sugerido_test.dart
//
// Integración de Contactos en el escaneo documental (CEO, noviembre 2026):
// buscarContactoSugerido es la única lógica de "coincidencia" del lado del
// cliente -- la IA ya tolera errores de OCR/escritura al elegir el nombre
// EXACTO de un contacto (o null si duda, ver el prompt de classifyDocument
// en functions/index.js); aquí solo se compara ese nombre contra los
// contactos ya cargados, ignorando mayúsculas y espacios de más.
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_ui/nuevo_documento_flow.dart';

const _contactos = [
  (id: 'c1', nombre: 'Fontanería López', especialidad: 'Fontanero'),
  (id: 'c2', nombre: 'Eléctrica Ruiz', especialidad: null),
];

void main() {
  group('buscarContactoSugerido', () {
    test('coincidencia exacta devuelve el contacto', () {
      final resultado = buscarContactoSugerido(_contactos, 'Fontanería López');
      expect(resultado?.id, 'c1');
    });

    test('ignora mayúsculas/minúsculas', () {
      final resultado = buscarContactoSugerido(_contactos, 'fontanería lópez');
      expect(resultado?.id, 'c1');
    });

    test('ignora espacios de más al principio/final', () {
      final resultado = buscarContactoSugerido(_contactos, '  Fontanería López  ');
      expect(resultado?.id, 'c1');
    });

    test('sin ninguna coincidencia devuelve null', () {
      expect(buscarContactoSugerido(_contactos, 'Carpintería Sánchez'), isNull);
    });

    test('nombreSugerido null devuelve null sin recorrer la lista', () {
      expect(buscarContactoSugerido(_contactos, null), isNull);
    });

    test('nombreSugerido vacío o solo espacios devuelve null', () {
      expect(buscarContactoSugerido(_contactos, '   '), isNull);
    });

    test('lista de contactos vacía devuelve null aunque haya nombre sugerido', () {
      expect(buscarContactoSugerido(const [], 'Fontanería López'), isNull);
    });

    test(
      'con varios contactos que comparten exactamente el mismo nombre, propone el primero (limitación documentada)',
      () {
        const conDuplicado = [
          (id: 'a', nombre: 'Juan Pérez', especialidad: 'Fontanero'),
          (id: 'b', nombre: 'Juan Pérez', especialidad: 'Electricista'),
        ];
        final resultado = buscarContactoSugerido(conDuplicado, 'Juan Pérez');
        expect(resultado?.id, 'a');
      },
    );
  });
}
