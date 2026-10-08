// test/security/security_preferences_service_test.dart
//
// Fase O de la misión de seguridad local (octubre 2026): cobertura directa
// de SecurityPreferencesService, hasta ahora solo probado indirectamente a
// través de app_lock_controller_test.dart. Cubre en particular el valor por
// defecto cuando no hay nada guardado (debe ser "todo desactivado", nunca
// "todo activado" -- un fallo aquí dejaría el bloqueo biométrico encendido
// para quien nunca lo pidió) y el caso de un valor de timeout corrupto o de
// un enum futuro eliminado, que debe caer a fiveMinutes en vez de reventar.
import 'package:flutter_test/flutter_test.dart';
import 'package:repara/services/security/security_preferences_service.dart';

import '../fakes/fake_secure_storage_channel.dart';

void main() {
  late Map<String, String> almacen;

  setUp(() {
    almacen = instalarSecureStorageFalso();
  });

  test('sin nada guardado, todo empieza desactivado', () async {
    expect(await SecurityPreferencesService.instance.isBiometricLockEnabled(), isFalse);
    expect(await SecurityPreferencesService.instance.isDocumentProtectionEnabled(), isFalse);
    expect(await SecurityPreferencesService.instance.isProGateEnabled(), isFalse);
  });

  test('sin nada guardado, el timeout por defecto es 5 minutos', () async {
    expect(await SecurityPreferencesService.instance.getLockTimeout(), LockTimeout.fiveMinutes);
  });

  test('setBiometricLockEnabled/isBiometricLockEnabled hacen ida y vuelta', () async {
    await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
    expect(await SecurityPreferencesService.instance.isBiometricLockEnabled(), isTrue);
    await SecurityPreferencesService.instance.setBiometricLockEnabled(false);
    expect(await SecurityPreferencesService.instance.isBiometricLockEnabled(), isFalse);
  });

  test('setLockTimeout/getLockTimeout hacen ida y vuelta para cada opción', () async {
    for (final opcion in LockTimeout.values) {
      await SecurityPreferencesService.instance.setLockTimeout(opcion);
      expect(await SecurityPreferencesService.instance.getLockTimeout(), opcion);
    }
  });

  test('un valor de timeout corrupto/desconocido cae a fiveMinutes, no revienta', () async {
    almacen['security_lock_timeout'] = 'un_valor_que_ya_no_existe';
    expect(await SecurityPreferencesService.instance.getLockTimeout(), LockTimeout.fiveMinutes);
  });

  test('setDocumentProtectionEnabled/isDocumentProtectionEnabled hacen ida y vuelta', () async {
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(true);
    expect(await SecurityPreferencesService.instance.isDocumentProtectionEnabled(), isTrue);
  });

  test('setProGateEnabled/isProGateEnabled hacen ida y vuelta', () async {
    await SecurityPreferencesService.instance.setProGateEnabled(true);
    expect(await SecurityPreferencesService.instance.isProGateEnabled(), isTrue);
  });

  test('limpiarTodo() borra los 4 ajustes y vuelven a sus valores por defecto', () async {
    await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
    await SecurityPreferencesService.instance.setLockTimeout(LockTimeout.immediate);
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(true);
    await SecurityPreferencesService.instance.setProGateEnabled(true);

    await SecurityPreferencesService.instance.limpiarTodo();

    expect(await SecurityPreferencesService.instance.isBiometricLockEnabled(), isFalse);
    expect(await SecurityPreferencesService.instance.getLockTimeout(), LockTimeout.fiveMinutes);
    expect(await SecurityPreferencesService.instance.isDocumentProtectionEnabled(), isFalse);
    expect(await SecurityPreferencesService.instance.isProGateEnabled(), isFalse);
  });
}
