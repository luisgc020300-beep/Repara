// lib/core/service_locator.dart
//
// Punto único de arranque de servicios globales. Deliberadamente mínimo en
// v1 -- sin FCM/conectividad todavía (sección 42 del spec de producto,
// notificaciones, es explícitamente posterior al MVP).
import 'package:get_it/get_it.dart';

import '../services/security/app_lock_controller.dart';
import '../services/security/biometric_service.dart';
import 'casa_context.dart';

final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {
  sl.registerSingleton<CasaContext>(CasaContext.instance);

  // BiometricService SIEMPRE se resuelve vía sl<BiometricService>(), nunca
  // instanciando LocalAuthBiometricService() directamente en una pantalla
  // -- es lo que permite a los tests sustituirlo por un
  // FakeBiometricService sin tocar hardware real (sección 32 de la misión
  // de seguridad local). AppLockController.instance no necesita pasar por
  // aquí porque nada lo testea en aislamiento sin también testear
  // BiometricService.
  if (!sl.isRegistered<BiometricService>()) {
    sl.registerLazySingleton<BiometricService>(() => LocalAuthBiometricService());
  }
  await AppLockController.instance.init();
}
