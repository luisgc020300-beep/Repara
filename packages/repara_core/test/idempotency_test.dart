// packages/repara_core/test/idempotency_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/idempotency.dart';

void main() {
  test('generarIdempotencyKey() devuelve 32 caracteres hexadecimales', () {
    final clave = generarIdempotencyKey();
    expect(clave.length, 32);
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(clave), isTrue);
  });

  test('generarIdempotencyKey() nunca repite dos claves consecutivas', () {
    final claves = List.generate(50, (_) => generarIdempotencyKey());
    expect(claves.toSet().length, 50);
  });
}
