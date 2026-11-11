// test/claims_sync_test.dart
//
// registrarSincronizacionDeClaims() -- el mecanismo compartido que usan
// tanto REPARA Hogar (CasaService.sincronizarClaims) como REPARA Pro
// (ProfesionalService.sincronizarClaims) al arrancar, para el backfill de
// custom claims (noviembre 2026, problema #6 de la auditoría de
// comunicación cruzada). Genérico sobre un stream falso de enteros -- no
// hace falta construir un User real de Firebase Auth para probar la única
// regla que importa: "sincroniza con cada valor no nulo, nunca con null".
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/claims_sync.dart';

void main() {
  test(
    'llama a sincronizar una vez por cada valor no nulo que emite el stream',
    () async {
      final controller = StreamController<int?>();
      var llamadas = 0;
      final sub = registrarSincronizacionDeClaims<int>(controller.stream, () async {
        llamadas++;
      });

      controller.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(llamadas, 1, reason: 'un inicio de sesión debe disparar exactamente una sincronización');

      controller.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(llamadas, 2, reason: 'otro inicio de sesión (otro valor no nulo) debe disparar otra sincronización');

      await sub.cancel();
      await controller.close();
    },
  );

  test('nunca llama a sincronizar cuando el stream emite null (sin sesión)', () async {
    final controller = StreamController<int?>();
    var llamadas = 0;
    final sub = registrarSincronizacionDeClaims<int>(controller.stream, () async {
      llamadas++;
    });

    controller.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(llamadas, 0, reason: 'un cierre de sesión (null) no debe disparar ninguna sincronización');

    await sub.cancel();
    await controller.close();
  });

  test(
    'tras cancelar la suscripción, nuevos valores no nulos ya no disparan ninguna llamada',
    () async {
      final controller = StreamController<int?>();
      var llamadas = 0;
      final sub = registrarSincronizacionDeClaims<int>(controller.stream, () async {
        llamadas++;
      });

      controller.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(llamadas, 1);

      await sub.cancel();
      controller.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(llamadas, 1, reason: 'cancelada la suscripción, no debe haber más llamadas');

      await controller.close();
    },
  );
}
