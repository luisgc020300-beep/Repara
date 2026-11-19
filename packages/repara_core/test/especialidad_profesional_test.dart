// packages/repara_core/test/especialidad_profesional_test.dart
//
// Organizar las especialidades profesionales (noviembre 2026): la lista
// cerrada que ofrece el selector de Ajustes Pro -- ver
// especialidad_profesional.dart para el porqué no es un enum en el modelo.
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/especialidad_profesional.dart';

void main() {
  test('la lista no está vacía y no tiene duplicados', () {
    expect(especialidadesProfesionales, isNotEmpty);
    expect(especialidadesProfesionales.toSet().length, especialidadesProfesionales.length);
  });

  test('"Otro" está presente y es la última opción (texto libre de respaldo)', () {
    expect(especialidadesProfesionales.last, especialidadProfesionalOtra);
    expect(especialidadesProfesionales.where((e) => e == especialidadProfesionalOtra).length, 1);
  });

  test('ninguna opción está vacía ni tiene espacios sueltos alrededor', () {
    for (final e in especialidadesProfesionales) {
      expect(e.trim(), e);
      expect(e, isNotEmpty);
    }
  });
}
