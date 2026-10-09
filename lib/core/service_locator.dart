// lib/core/service_locator.dart
//
// Punto único de arranque de servicios globales. Deliberadamente mínimo en
// v1 -- sin FCM/conectividad todavía (sección 42 del spec de producto,
// notificaciones, es explícitamente posterior al MVP).
import 'package:get_it/get_it.dart';

import '../services/security/biometric_service.dart';
import 'casa_context.dart';

final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {
  sl.registerSingleton<CasaContext>(CasaContext.instance);

  // BiometricService SIEMPRE se resuelve vía sl<BiometricService>(), nunca
  // instanciando LocalAuthBiometricService() directamente en una pantalla
  // -- es lo que permite a los tests sustituirlo por un
  // FakeBiometricService sin tocar hardware real. Se usa para los gates
  // puntuales de documentos sensibles y de entrar en Repara Pro (el
  // bloqueo general de la app al abrirla se quitó -- el launcher del
  // móvil ya ofrece "requerir Face ID" por app, octubre 2026).
  if (!sl.isRegistered<BiometricService>()) {
    sl.registerLazySingleton<BiometricService>(() => LocalAuthBiometricService());
  }
}
