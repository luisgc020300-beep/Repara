// lib/core/service_locator.dart
//
// Punto único de arranque de servicios globales. Deliberadamente mínimo en
// v1 -- sin FCM/conectividad todavía (sección 42 del spec de producto,
// notificaciones, es explícitamente posterior al MVP).
import 'package:get_it/get_it.dart';

import 'casa_context.dart';

final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {
  sl.registerSingleton<CasaContext>(CasaContext.instance);
}
