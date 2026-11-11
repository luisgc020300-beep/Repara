// lib/claims_sync.dart
//
// Mecanismo compartido para disparar el backfill de custom claims
// (casaIds/registrosProId -- ver CasaService.sincronizarClaims() en
// Hogar/monolito y ProfesionalService.sincronizarClaims() en Pro) una vez
// por cada inicio de sesión real, nunca en cada rebuild del árbol de
// widgets ni mientras no haya nadie autenticado.
//
// Extraído a repara_core en noviembre 2026 (problema #6 de la auditoría de
// comunicación cruzada) para que Hogar y Pro usen exactamente el mismo
// criterio de "evitar llamadas redundantes" que ya usaba el monolito en su
// propio main.dart, en vez de que cada app reimplemente su propio listener
// a mano.
//
// Genérico sobre T (no atado a firebase_auth.User) a propósito: lo único
// que importa aquí es "¿el valor que emite el stream es no-nulo?", nunca
// qué representa ese valor -- lo que además permite testear el mecanismo
// con un stream falso de cualquier tipo, sin tener que construir un User
// real de Firebase Auth.
import 'dart:async';

/// [authStateChanges] debe ser un stream donde `null` significa "sin
/// sesión" y cualquier otro valor significa "hay una sesión iniciada" --
/// típicamente `FirebaseAuth.instance.authStateChanges()`. `authStateChanges`
/// de Firebase solo emite cuando el estado de verdad cambia (nunca repite
/// el mismo usuario dos veces seguidas), así que no hace falta ninguna
/// comprobación extra de "¿ya llamé para este usuario?" aquí --
/// delegar en esa garantía es lo que mantiene este mecanismo idéntico al
/// que ya usaba el monolito, sin añadir lógica nueva que no existía.
StreamSubscription<T?> registrarSincronizacionDeClaims<T>(
  Stream<T?> authStateChanges,
  Future<void> Function() sincronizar,
) {
  return authStateChanges.listen((valor) {
    if (valor != null) unawaited(sincronizar());
  });
}
