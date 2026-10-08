// lib/services/stream_error_logging.dart
//
// Auditoría de "estados de error" (Fase K de la misión de seguridad local,
// octubre 2026): ninguno de los streams de servicio registraba sus errores
// en Crashlytics. Un StreamBuilder que no comprueba snapshot.hasError (la
// gran mayoría en esta app) convierte cualquier fallo -- permission-denied,
// un índice que falta, un documento con un campo corrupto que revienta
// fromDoc() -- en una lista vacía silenciosa: parece "no hay nada guardado
// todavía" en vez de "algo falló", y nadie se entera nunca, ni el usuario ni
// en Crashlytics.
//
// Arreglar esto pantalla por pantalla (18 sitios) habría sido un rediseño de
// UI fuera de alcance de esta misión. Esta extensión es el arreglo mínimo:
// registra el error en Crashlytics en el punto donde se genera cada stream
// (20 métodos en los servicios) y lo vuelve a lanzar tal cual, para no
// cambiar el comportamiento que ya ven las pantallas -- solo deja de ser
// invisible para quien mantiene la app.
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

extension RegistraErroresDeStream<T> on Stream<T> {
  Stream<T> conRegistroDeErrores() {
    return handleError((Object error, StackTrace stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false);
      Error.throwWithStackTrace(error, stackTrace);
    });
  }
}
