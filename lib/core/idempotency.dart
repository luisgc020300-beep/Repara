// lib/core/idempotency.dart
//
// Clave de idempotencia estable por intento lógico de usuario (crear un
// pago, crear un cambio de alcance), para que una Cloud Function pueda usar
// un id de documento determinista y así un reintento de red no duplique el
// efecto económico. Se genera UNA SOLA VEZ por pantalla/formulario (campo
// `late final` en el State), nunca de nuevo en cada intento de guardado --
// si se regenerara en cada llamada, dejaría de proteger justo el caso que
// debe proteger (auditoría de integridad económica, octubre 2026).
import 'dart:math';

String generarIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
