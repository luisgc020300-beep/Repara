// test/services/conceptos_frecuentes_service_test.dart
//
// Biblioteca de conceptos frecuentes de presupuesto (ampliación REPARA Pro,
// Fase 3, noviembre 2026): guardar con el mismo nombre actualiza en vez de
// duplicar, eliminar quita solo ese concepto, y un valor local corrupto
// nunca debe hacer fallar la lectura.
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/conceptos_frecuentes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('listar() devuelve vacío cuando nunca se ha guardado nada', () async {
    expect(await ConceptosFrecuentesService.listar(), isEmpty);
  });

  test('guardar() y listar() -- se recupera tal cual se guardó', () async {
    await ConceptosFrecuentesService.guardar(
      const ConceptoFrecuente(
        nombre: 'Desplazamiento',
        precioUnitario: 25,
        ivaPorcentaje: 21,
      ),
    );
    final lista = await ConceptosFrecuentesService.listar();
    expect(lista, hasLength(1));
    expect(lista.single.nombre, 'Desplazamiento');
    expect(lista.single.precioUnitario, 25);
    expect(lista.single.ivaPorcentaje, 21);
  });

  test(
    'guardar() con un nombre ya existente actualiza el precio en vez de duplicar',
    () async {
      await ConceptosFrecuentesService.guardar(
        const ConceptoFrecuente(
          nombre: 'Mano de obra',
          precioUnitario: 30,
          ivaPorcentaje: 21,
        ),
      );
      await ConceptosFrecuentesService.guardar(
        const ConceptoFrecuente(
          nombre: 'mano de obra',
          precioUnitario: 35,
          ivaPorcentaje: 21,
        ),
      );
      final lista = await ConceptosFrecuentesService.listar();
      expect(lista, hasLength(1));
      expect(lista.single.precioUnitario, 35);
    },
  );

  test('eliminar() solo quita el concepto indicado', () async {
    await ConceptosFrecuentesService.guardar(
      const ConceptoFrecuente(
        nombre: 'Desplazamiento',
        precioUnitario: 25,
        ivaPorcentaje: 21,
      ),
    );
    await ConceptosFrecuentesService.guardar(
      const ConceptoFrecuente(
        nombre: 'Instalación',
        precioUnitario: 80,
        ivaPorcentaje: 21,
      ),
    );
    await ConceptosFrecuentesService.eliminar('Desplazamiento');
    final lista = await ConceptosFrecuentesService.listar();
    expect(lista, hasLength(1));
    expect(lista.single.nombre, 'Instalación');
  });

  test(
    'un valor local corrupto se trata como "sin conceptos guardados", nunca lanza',
    () async {
      SharedPreferences.setMockInitialValues({
        'repara_conceptos_frecuentes_presupuesto': 'no es json de verdad',
      });
      expect(await ConceptosFrecuentesService.listar(), isEmpty);
    },
  );
}
