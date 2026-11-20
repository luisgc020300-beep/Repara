// packages/repara_core/test/primer_uso_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:repara_core/primer_uso_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('yaVisto() es false la primera vez para una clave nueva', () async {
    expect(await PrimerUsoService.yaVisto('nuevo_elemento'), isFalse);
  });

  test('marcarVisto() hace que yaVisto() pase a true para esa misma clave', () async {
    await PrimerUsoService.marcarVisto('nuevo_elemento');
    expect(await PrimerUsoService.yaVisto('nuevo_elemento'), isTrue);
  });

  test('marcar una clave como vista no afecta a otra clave distinta', () async {
    await PrimerUsoService.marcarVisto('nuevo_elemento');
    expect(await PrimerUsoService.yaVisto('nuevo_contacto'), isFalse);
  });
}
