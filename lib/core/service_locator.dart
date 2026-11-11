// lib/core/service_locator.dart
//
// Punto único de arranque de servicios globales. Deliberadamente mínimo en
// v1 -- sin FCM/conectividad todavía (sección 42 del spec de producto,
// notificaciones, es explícitamente posterior al MVP).
//
// BiometricService ya no se registra aquí (noviembre 2026): se movió a
// repara_core como BiometricAuth, con su propio seam de test
// (debugServiceOverride) en vez de GetIt -- lo que permite a Hogar y Pro
// reutilizarlo sin arrastrar get_it como dependencia nueva. Ver
// repara_core/lib/biometric_service.dart.
import 'package:get_it/get_it.dart';

import 'casa_context.dart';

final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {
  sl.registerSingleton<CasaContext>(CasaContext.instance);
}
