// test/services/stream_sharing_test.dart
//
// `compartido()` es el arreglo de la auditoría de estabilidad (noviembre
// 2026, crash "FIRESTORE INTERNAL ASSERTION FAILED (ID: ca9)" en
// registro_detail_screen.dart): memoiza un stream por clave para que dos
// peticiones iguales -- incluida la que ocurre en cada rebuild de un
// StreamBuilder -- comparen por identidad y nunca disparen una cancelación
// y una nueva suscripción reales. Estos tests viven en Dart puro (sin
// Firestore real ni fake_cloud_firestore) porque lo que hay que probar es
// el comportamiento del propio mecanismo de caché, no una consulta.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:repara/services/stream_sharing.dart';

void main() {
  test('dos llamadas con la misma clave devuelven la misma instancia', () {
    var vecesCreado = 0;
    Stream<int> crear() {
      vecesCreado++;
      return Stream<int>.periodic(const Duration(milliseconds: 1), (i) => i);
    }

    final a = crear().compartido('misma-clave');
    final b = crear().compartido('misma-clave');

    // Dos "construcciones" del stream base (como pasaría en dos rebuilds
    // de un StreamBuilder llamando dos veces al mismo streamX()), pero la
    // caché debe devolver el mismo objeto para ambas.
    expect(vecesCreado, 2);
    expect(identical(a, b), isTrue);
  });

  test('claves distintas no comparten instancia', () {
    final a = Stream<int>.value(1).compartido('clave-a');
    final b = Stream<int>.value(2).compartido('clave-b');
    expect(identical(a, b), isFalse);
  });

  test('solo se suscribe una vez al stream real aunque haya varios oyentes', () async {
    var suscripciones = 0;
    // onListen de la fuente real cuenta cuántas veces se suscribe de
    // verdad -- simula el listener de Firestore que no debe duplicarse.
    final origen = StreamController<int>(
      onListen: () => suscripciones++,
    );

    final compartido1 = origen.stream.compartido('pagos:casa:elem:reg');
    final compartido2 = origen.stream.compartido('pagos:casa:elem:reg');

    final recibidos1 = <int>[];
    final recibidos2 = <int>[];
    final sub1 = compartido1.listen(recibidos1.add);
    final sub2 = compartido2.listen(recibidos2.add);

    origen.add(1);
    origen.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(suscripciones, 1, reason: 'solo debe haber una suscripción real');
    expect(recibidos1, [1, 2]);
    expect(recibidos2, [1, 2]);

    await sub1.cancel();
    await sub2.cancel();
    await origen.close();
  });

  test('tras cancelar el último oyente, una nueva petición abre una suscripción real nueva', () async {
    var vecesCreado = 0;
    StreamController<int>? actual;
    Stream<int> crear() {
      vecesCreado++;
      actual = StreamController<int>.broadcast();
      return actual!.stream;
    }

    final s1 = crear().compartido('ciclo-vida');
    final sub1 = s1.listen((_) {});
    await sub1.cancel();
    // Tras cancelar el único oyente, la entrada de caché debe borrarse --
    // la siguiente petición con la misma clave debe crear una suscripción
    // real nueva, no reutilizar la cerrada.
    final s2 = crear().compartido('ciclo-vida');
    final recibidos = <int>[];
    final sub2 = s2.listen(recibidos.add);

    expect(vecesCreado, 2);
    actual!.add(42);
    await Future<void>.delayed(Duration.zero);
    expect(recibidos, [42]);

    await sub2.cancel();
  });

  test(
    'un oyente que se suscribe DESPUÉS de que ya haya llegado un valor lo recibe de inmediato '
    '(bug real: REPARA Pro se quedaba cargando al entrar a un trabajo porque la lista ya estaba '
    'suscrita desde antes y el detalle, al llegar tarde, nunca recibía el snapshot inicial)',
    () async {
      final origen = StreamController<int>.broadcast();
      final compartido = origen.stream.compartido('trabajo-tardio');

      // El "primer oyente" -- como trabajo_pro_agregado.dart, que mantiene
      // su suscripción abierta mientras la pestaña Trabajos está montada.
      final recibidosTemprano = <int>[];
      final subTemprano = compartido.listen(recibidosTemprano.add);

      origen.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(recibidosTemprano, [1]);

      // El "oyente tardío" -- como el StreamBuilder<Registro?> de
      // RegistroProDetailScreen, que se suscribe a la MISMA clave después
      // de que el valor 1 ya haya llegado. Debe recibirlo YA, sin esperar
      // a un snapshot nuevo que puede no llegar nunca.
      final recibidosTardio = <int>[];
      final subTardio = compartido.listen(recibidosTardio.add);
      await Future<void>.delayed(Duration.zero);

      expect(
        recibidosTardio,
        [1],
        reason: 'debe repetir el último valor conocido al suscribirse, como hace Firestore',
      );

      // Y un valor nuevo real sigue llegando a ambos con normalidad.
      origen.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(recibidosTemprano, [1, 2]);
      expect(recibidosTardio, [1, 2]);

      await subTemprano.cancel();
      await subTardio.cancel();
      await origen.close();
    },
  );

  test('un oyente tardío tras un error recibe también el último error conocido', () async {
    final origen = StreamController<int>.broadcast();
    final compartido = origen.stream.compartido('error-tardio');

    final subTemprano = compartido.listen((_) {}, onError: (_) {});
    origen.addError('fallo previo');
    await Future<void>.delayed(Duration.zero);

    final erroresTardios = <Object>[];
    final subTardio = compartido.listen((_) {}, onError: erroresTardios.add);
    await Future<void>.delayed(Duration.zero);

    expect(erroresTardios, ['fallo previo']);

    await subTemprano.cancel();
    await subTardio.cancel();
    await origen.close();
  });

  test('un error del stream real llega a todos los oyentes compartidos', () async {
    final origen = StreamController<int>();
    final compartido1 = origen.stream.compartido('con-error');
    final compartido2 = origen.stream.compartido('con-error');

    final errores1 = <Object>[];
    final errores2 = <Object>[];
    final sub1 = compartido1.listen((_) {}, onError: errores1.add);
    final sub2 = compartido2.listen((_) {}, onError: errores2.add);

    origen.addError('fallo de prueba');
    await Future<void>.delayed(Duration.zero);

    expect(errores1, ['fallo de prueba']);
    expect(errores2, ['fallo de prueba']);

    await sub1.cancel();
    await sub2.cancel();
  });
}
