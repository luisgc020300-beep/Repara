// apps/repara_pro/lib/firebase_options.dart
//
// PLACEHOLDER DELIBERADO -- NO generado por `flutterfire configure`.
// REPARA Pro todavía no está registrada como aplicación en el proyecto
// Firebase compartido (repara-hogar-app) -- ver README.md de este paquete
// y el informe de la integración funcional de Pro (noviembre 2026).
//
// `web` apunta, a propósito, al mismo proyecto de pruebas "repara-test"
// que usan functions-tests/firestore-tests (apiKey inventada, nunca válida
// contra ningún backend real) -- solo sirve para arrancar la app con
// `flutter run -d chrome --dart-define=USE_EMULATOR=true` contra el
// Emulator Suite local. `android`/`ios` lanzan un error explícito: no hay
// ningún build nativo real posible hasta que se ejecute `flutterfire
// configure` de verdad (requiere autorización expresa -- ver CLAUDE.md /
// instrucciones de esta tarea) y se registre la app en Firebase Console.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        throw UnsupportedError(
          'REPARA Pro todavía no está registrada en Firebase para esta '
          'plataforma -- falta ejecutar `flutterfire configure` (pendiente '
          'de autorización expresa, ver README.md). Usa '
          '`flutter run -d chrome --dart-define=USE_EMULATOR=true` contra '
          'el Emulator Suite local mientras tanto.',
        );
    }
  }

  // Solo válido contra el Emulator Suite local -- ver comentario de arriba.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyFakeKeyOnlyValidAgainstLocalEmulator00',
    appId: '1:199074592333:web:0000000000000000000000',
    messagingSenderId: '199074592333',
    projectId: 'repara-test',
    storageBucket: 'repara-test.firebasestorage.app',
  );
}
