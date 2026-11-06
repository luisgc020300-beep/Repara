// apps/repara_hogar/lib/firebase_options.dart
//
// PLACEHOLDER DELIBERADO -- NO generado por `flutterfire configure`.
// REPARA Hogar todavia no esta registrada como aplicacion en el proyecto
// Firebase compartido (repara-hogar-app) -- ver README.md de este paquete
// y el informe de la integracion funcional de Hogar.
//
// Mismo criterio que apps/repara_pro/lib/firebase_options.dart: `web`
// apunta al proyecto de pruebas "repara-test" (emulador local unicamente);
// `android`/`ios` lanzan un error explicito hasta que se ejecute
// `flutterfire configure` de verdad (requiere autorizacion expresa).
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
          'REPARA Hogar todavia no esta registrada en Firebase para esta '
          'plataforma -- falta ejecutar `flutterfire configure` (pendiente '
          'de autorizacion expresa, ver README.md). Usa '
          '`flutter run -d chrome --dart-define=USE_EMULATOR=true` contra '
          'el Emulator Suite local mientras tanto.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyFakeKeyOnlyValidAgainstLocalEmulator00',
    appId: '1:199074592333:web:0000000000000000000001',
    messagingSenderId: '199074592333',
    projectId: 'repara-test',
    storageBucket: 'repara-test.firebasestorage.app',
  );
}
