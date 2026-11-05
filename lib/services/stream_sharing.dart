// lib/services/stream_sharing.dart
//
// Auditoría de estabilidad (noviembre 2026): registro_detail_screen.dart
// (y, en menor medida, pro/registro_pro_detail_screen.dart) abren a la vez
// 6-7 StreamBuilder anidados (Registro, Elemento, Pagos, Presupuestos,
// Cambios de alcance, Historial, Citas compartidas, Invitación...). Dos
// problemas reales, no solo uno:
//
// 1. Duplicados genuinos: PagoService.streamPagos(casaId, elementoId,
//    registroId) se llamaba de forma independiente desde hasta TRES sitios
//    a la vez con los mismos argumentos (la tarjeta económica, PagosSection
//    y ProgresoPago) -- tres listeners onSnapshot distintos para
//    exactamente los mismos documentos, pese a un comentario que decía lo
//    contrario.
// 2. Tormenta de listen/unlisten: cada streamX() de servicio abre un
//    `.snapshots()` NUEVO en cada llamada. Como el `stream:` de todos estos
//    StreamBuilder se calcula llamando al servicio directamente dentro de
//    build(), cada vez que el stream del Registro (el más externo) emite
//    un snapshot nuevo -- cosa que pasa por cualquier cambio de cualquier
//    campo, no solo los relevantes -- todo el árbol se reconstruye y cada
//    StreamBuilder anidado recibe un Stream distinto (aunque lógicamente
//    sea la misma consulta), así que Flutter cancela y vuelve a suscribir
//    TODOS esos listeners de golpe. Esa concurrencia de cancelaciones y
//    altas casi simultáneas sobre 6-7 consultas es lo que disparaba
//    "FIRESTORE INTERNAL ASSERTION FAILED (ID: ca9)" en el SDK de Firestore
//    Web (confirmado por correlación con el número de listeners activos,
//    no con `persistenceEnabled`).
//
// `compartido(clave)` resuelve ambos a la vez memoizando por clave: dos
// llamadas con la misma clave devuelven la MISMA instancia de Stream, así
// que (a) solo se abre un listener real de Firestore aunque varios widgets
// pidan los mismos datos, y (b) un StreamBuilder cuyo `stream:` sigue
// resolviendo a la misma instancia en cada rebuild nunca cancela ni
// resuscribe -- `StreamBuilder.didUpdateWidget` compara por identidad
// (`oldWidget.stream != widget.stream`) y aquí deja de cambiar.
//
// Vive por referencia, no por tiempo: la entrada se borra en cuanto el
// último suscriptor se cancela (p.ej. al cerrar la pantalla), momento en
// el que el listener real de Firestore se cierra exactamente igual que sin
// esta caché -- nunca queda un listener huérfano ni una fuga de memoria.
import 'dart:async';

import 'package:flutter/foundation.dart';

class _CacheDeStreamsCompartidos {
  final _entradas = <String, Stream<dynamic>>{};

  /// Seam de solo test -- nunca se llama en código de producción. La
  /// caché es un singleton de todo el proceso (en producción solo existe
  /// una FirebaseFirestore.instance real, así que nunca colisiona); en
  /// tests, donde varios archivos pueden reutilizar los mismos
  /// casaId/elementoId/registroId contra instancias FakeFirebaseFirestore
  /// distintas de un test a otro, hay que vaciarla entre tests para que
  /// una entrada que todavía no se haya limpiado (p.ej. porque su último
  /// suscriptor se cancela en un microtask posterior al `tearDown`) no
  /// filtre datos de un test al siguiente.
  @visibleForTesting
  void limpiar() => _entradas.clear();

  Stream<T> obtener<T>(String clave, Stream<T> Function() crear) {
    final existente = _entradas[clave];
    if (existente != null) return existente as Stream<T>;

    late final StreamController<T> controller;
    StreamSubscription<T>? sub;
    controller = StreamController<T>.broadcast(
      onListen: () {
        sub ??= crear().listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            _entradas.remove(clave);
            controller.close();
          },
        );
      },
      onCancel: () {
        _entradas.remove(clave);
        sub?.cancel();
        sub = null;
      },
    );
    // OJO: `controller.stream` de un StreamController.broadcast() NO es
    // idempotente -- cada acceso al getter crea un wrapper _BroadcastStream
    // nuevo (a diferencia de un controller normal, que sí cachea el suyo).
    // Hay que leerlo UNA sola vez y guardar esa misma referencia, o dos
    // llamadas con la misma clave dejarían de ser `identical` entre sí y
    // todo este arreglo no serviría de nada.
    final stream = controller.stream;
    _entradas[clave] = stream;
    return stream;
  }
}

final _cacheStreamsCompartidos = _CacheDeStreamsCompartidos();

/// Seam de solo test -- ver [_CacheDeStreamsCompartidos.limpiar]. Llamar
/// en `tearDown()` de cualquier test que use `debugFirestoreOverride` con
/// casaId/elementoId/registroId que puedan repetirse entre tests.
@visibleForTesting
void debugLimpiarCacheDeStreamsCompartidos() => _cacheStreamsCompartidos.limpiar();

extension CompartirStream<T> on Stream<T> {
  /// Memoiza este stream por [clave]: llamadas repetidas con la misma
  /// clave (incluida la que se produce en cada rebuild de un
  /// StreamBuilder) devuelven la misma instancia en vez de abrir una
  /// suscripción real nueva.
  Stream<T> compartido(String clave) {
    return _cacheStreamsCompartidos.obtener<T>(clave, () => this);
  }
}
