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
// resuscribe.
//
// CORRECCIÓN (misma auditoría, hallazgo en producción -- "al entrar a un
// trabajo desde REPARA Pro se queda cargando para siempre"): la primera
// versión de esto usaba un StreamController.broadcast() normal, que NO
// repite el último valor a un oyente que se suscribe más tarde que otro.
// trabajo_pro_agregado.dart mantiene suscripciones propias de larga
// duración a estos mismos streamX() mientras la pestaña Trabajos/Dashboard
// está montada; en cuanto el profesional entra al detalle de un trabajo
// concreto, su StreamBuilder se suscribe DESPUÉS de esa suscripción ya
// viva -- con un broadcast normal, nunca recibía el snapshot inicial (que
// Firestore sí entrega siempre a cada listener nuevo) y se quedaba en
// ConnectionState.waiting para siempre. Se arregla con Stream.multi: cada
// llamada a listen() dispara su propio callback (aunque el stream sea
// broadcast), así que aquí se le repite a CADA oyente nuevo el último
// valor o error conocido antes de engancharlo a los eventos futuros --
// igual que haría Firestore de verdad.
//
// Vive por referencia, no por tiempo: la entrada se borra en cuanto el
// último suscriptor se cancela (p.ej. al cerrar la pantalla), momento en
// el que el listener real de Firestore se cierra exactamente igual que sin
// esta caché -- nunca queda un listener huérfano ni una fuga de memoria.
import 'dart:async';

import 'package:flutter/foundation.dart';

class _EntradaCompartida<T> {
  _EntradaCompartida(String clave, Stream<T> Function() crear, void Function(String) onVacia) {
    stream = Stream<T>.multi((controlador) {
      // Repetir primero lo último conocido -- si todavía no ha llegado
      // nada (primer oyente de todos), no hay nada que repetir y sigue
      // exactamente igual que antes.
      if (_tieneValor) {
        controlador.addSync(_ultimoValor as T);
      } else if (_tieneError) {
        controlador.addErrorSync(_ultimoError!, _ultimoErrorStack);
      }
      _oyentes.add(controlador);
      controlador.onCancel = () {
        _oyentes.remove(controlador);
        if (_oyentes.isEmpty) {
          onVacia(clave);
          _subReal?.cancel();
          _subReal = null;
        }
      };
      // La suscripción real a Firestore se abre UNA sola vez, en cuanto
      // llega el primer oyente -- los siguientes se enganchan a la misma.
      // Aquí (a diferencia de la repetición de arriba) se usan las
      // variantes asíncronas normales: este callback corre en un turno
      // posterior del event loop, no de forma síncrona dentro de
      // onListen, que es el único caso que addSync/addErrorSync/closeSync
      // admiten de verdad.
      _subReal ??= crear().listen(
        (valor) {
          _tieneValor = true;
          _tieneError = false;
          _ultimoValor = valor;
          for (final o in List.of(_oyentes)) {
            o.add(valor);
          }
        },
        onError: (Object error, StackTrace stack) {
          _tieneError = true;
          _ultimoError = error;
          _ultimoErrorStack = stack;
          for (final o in List.of(_oyentes)) {
            o.addError(error, stack);
          }
        },
        onDone: () {
          onVacia(clave);
          for (final o in List.of(_oyentes)) {
            o.close();
          }
        },
      );
    }, isBroadcast: true);
  }

  late final Stream<T> stream;
  final _oyentes = <MultiStreamController<T>>[];
  StreamSubscription<T>? _subReal;

  bool _tieneValor = false;
  T? _ultimoValor;
  bool _tieneError = false;
  Object? _ultimoError;
  StackTrace? _ultimoErrorStack;
}

class _CacheDeStreamsCompartidos {
  final _entradas = <String, _EntradaCompartida<dynamic>>{};

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
    if (existente != null) return (existente as _EntradaCompartida<T>).stream;

    final entrada = _EntradaCompartida<T>(clave, crear, _entradas.remove);
    _entradas[clave] = entrada;
    return entrada.stream;
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
  /// suscripción real nueva -- y cualquier oyente que llegue más tarde que
  /// otro recibe de inmediato el último valor conocido, igual que haría
  /// Firestore con un listener nuevo.
  Stream<T> compartido(String clave) {
    return _cacheStreamsCompartidos.obtener<T>(clave, () => this);
  }
}
