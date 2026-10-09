// test/security/security_preferences_service_test.dart
//
// Cobertura de SecurityPreferencesService: solo quedan los dos gates
// puntuales (documentos sensibles, acceso a Repara Pro) -- el bloqueo
// general de la app al abrirla se quitó (octubre 2026, el launcher del
// móvil ya ofrece "requerir Face ID" por app). Cubre en particular el valor
// por defecto cuando no hay nada guardado (debe ser "todo desactivado",
// nunca lo contrario).
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/services/security/security_preferences_service.dart';

import '../fakes/fake_secure_storage_channel.dart';

void main() {
  setUp(() {
    instalarSecureStorageFalso();
  });

  test('sin nada guardado, todo empieza desactivado', () async {
    expect(await SecurityPreferencesService.instance.isDocumentProtectionEnabled(), isFalse);
    expect(await SecurityPreferencesService.instance.isProGateEnabled(), isFalse);
  });

  test('setDocumentProtectionEnabled/isDocumentProtectionEnabled hacen ida y vuelta', () async {
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(true);
    expect(await SecurityPreferencesService.instance.isDocumentProtectionEnabled(), isTrue);
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(false);
    expect(await SecurityPreferencesService.instance.isDocumentProtectionEnabled(), isFalse);
  });

  test('setProGateEnabled/isProGateEnabled hacen ida y vuelta', () async {
    await SecurityPreferencesService.instance.setProGateEnabled(true);
    expect(await SecurityPreferencesService.instance.isProGateEnabled(), isTrue);
    await SecurityPreferencesService.instance.setProGateEnabled(false);
    expect(await SecurityPreferencesService.instance.isProGateEnabled(), isFalse);
  });

  test('limpiarTodo() borra los 2 ajustes y vuelven a sus valores por defecto', () async {
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(true);
    await SecurityPreferencesService.instance.setProGateEnabled(true);

    await SecurityPreferencesService.instance.limpiarTodo();

    expect(await SecurityPreferencesService.instance.isDocumentProtectionEnabled(), isFalse);
    expect(await SecurityPreferencesService.instance.isProGateEnabled(), isFalse);
  });
}
