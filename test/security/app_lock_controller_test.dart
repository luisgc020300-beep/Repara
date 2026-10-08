// test/security/app_lock_controller_test.dart
//
// Los 6 casos de biometría que pide la sección 32 de la misión de
// seguridad local, usando FakeBiometricService (sin hardware real) y un
// SecurityPreferencesService respaldado por un canal de secure storage
// simulado en memoria (sin dispositivo real).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repara/services/security/app_lock_controller.dart';
import 'package:repara/services/security/biometric_service.dart';
import 'package:repara/services/security/security_preferences_service.dart';

import '../fakes/fake_biometric_service.dart';
import '../fakes/fake_secure_storage_channel.dart';

void main() {
  late AppLockController controller;
  late FakeBiometricService biometria;

  setUp(() async {
    instalarSecureStorageFalso();
    await SecurityPreferencesService.instance.limpiarTodo();
    biometria = FakeBiometricService();
    // AppLockController.instance es un singleton de verdad (vive mientras
    // vive la app) -- no se destruye entre tests, solo se reinicializa su
    // estado lógico llamando a init() de nuevo sobre el almacenamiento ya
    // limpio de cada test.
    controller = AppLockController.instance;
  });

  test('Caso 1 -- biometría correcta desbloquea', () async {
    await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
    await controller.init();
    expect(controller.isLocked, isTrue);

    biometria.proximoResultado = BiometricAuthResult.success;
    final ok = await controller.tryUnlock(biometria, reason: 'test');

    expect(ok, isTrue);
    expect(controller.isLocked, isFalse);
  });

  test('Caso 2 -- biometría incorrecta deniega el acceso', () async {
    await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
    await controller.init();

    biometria.proximoResultado = BiometricAuthResult.failed;
    final ok = await controller.tryUnlock(biometria, reason: 'test');

    expect(ok, isFalse);
    expect(controller.isLocked, isTrue);
  });

  test('Caso 3 -- el usuario cancela, acceso denegado', () async {
    await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
    await controller.init();

    biometria.proximoResultado = BiometricAuthResult.cancelled;
    final ok = await controller.tryUnlock(biometria, reason: 'test');

    expect(ok, isFalse);
    expect(controller.isLocked, isTrue);
  });

  test('Caso 4 -- sin biometría disponible, authenticate() informa unavailable', () async {
    await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
    await controller.init();

    biometria.disponible = false;
    final ok = await controller.tryUnlock(biometria, reason: 'test');

    expect(ok, isFalse);
    expect(controller.isLocked, isTrue);
    expect(await biometria.isAvailable(), isFalse);
    // El "fallback correcto" (dejar recuperar el acceso por el login normal
    // de Firebase Auth en vez de dejar al usuario atrapado) es la pantalla
    // de bloqueo de la Fase E, que todavía no existe -- este test solo
    // verifica que la capa de servicio informa bien de que no hay
    // biometría disponible, para que esa pantalla pueda reaccionar.
  });

  test('Caso 5 -- biometría desactivada en ajustes, no se pide nunca', () async {
    await SecurityPreferencesService.instance.setBiometricLockEnabled(false);
    await controller.init();

    expect(controller.isLocked, isFalse);

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isLocked, isFalse);
    expect(biometria.llamadasAAuthenticate, 0);
  });

  group('Caso 6 -- bloqueo al volver de segundo plano según configuración', () {
    test('con "inmediatamente", bloquea aunque el segundo plano sea breve', () async {
      await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
      await SecurityPreferencesService.instance.setLockTimeout(LockTimeout.immediate);
      await controller.init();

      biometria.proximoResultado = BiometricAuthResult.success;
      await controller.tryUnlock(biometria, reason: 'test');
      expect(controller.isLocked, isFalse);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLocked, isTrue);
    });

    test('con "5 minutos", NO bloquea si el segundo plano fue breve', () async {
      await SecurityPreferencesService.instance.setBiometricLockEnabled(true);
      await SecurityPreferencesService.instance.setLockTimeout(LockTimeout.fiveMinutes);
      await controller.init();

      biometria.proximoResultado = BiometricAuthResult.success;
      await controller.tryUnlock(biometria, reason: 'test');
      expect(controller.isLocked, isFalse);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLocked, isFalse);
    });
  });
}
