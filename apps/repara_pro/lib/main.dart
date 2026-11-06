// apps/repara_pro/lib/main.dart
//
// Entrada propia de REPARA Pro -- NO depende de lib/main.dart del monolito
// ni de su service_locator.dart (GetIt), que registra CasaContext/
// BiometricService, exclusivos de Hogar. Pro no necesita ese gate
// biométrico (no hay "casa" que proteger aquí).
//
// Pendiente de conexión real (ver README.md e informe de esta integración):
// - `firebase_options.dart` es un placeholder deliberado, solo válido
//   contra el emulador local (USE_EMULATOR=true) -- falta `flutterfire
//   configure` para registrar esta app de verdad en el proyecto Firebase
//   compartido (repara-hogar-app).
// - Notificaciones push (FCM) no están conectadas todavía -- las
//   notificaciones internas (NotificacionesProScreen) sí funcionan en
//   cuanto hay backend real, son independientes de FCM.
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/theme_controller.dart';
import 'package:repara_ui/keyboard_dismiss_bar.dart';
import 'package:repara_ui/login_screen.dart';

import 'firebase_options.dart';
import 'screens/repara_pro_shell_screen.dart';

// Mismo criterio que lib/main.dart del monolito: SOLO cuando se compila con
// `--dart-define=USE_EMULATOR=true`. En cualquier build normal este bloque
// queda eliminado en tiempo de compilación.
const bool _usarEmulador = bool.fromEnvironment('USE_EMULATOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_usarEmulador) {
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
    FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).useFunctionsEmulator('127.0.0.1', 5001);
  }
  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  final themeController = await ThemeController.load();

  runApp(ReparaProApp(themeController: themeController));
}

class ReparaProApp extends StatelessWidget {
  const ReparaProApp({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'REPARA Pro',
        themeMode: themeController.mode,
        theme: buildReparaLightTheme(),
        darkTheme: buildReparaDarkTheme(),
        navigatorObservers: [AnalyticsService.observer],
        builder: (context, child) => KeyboardDismissBar(child: child!),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasData) return const ReparaProShellScreen();
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
