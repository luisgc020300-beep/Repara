// lib/main.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/service_locator.dart';
import 'firebase_options.dart';
import 'screens/casa_gate_screen.dart';
import 'screens/login_screen.dart';
import 'services/analytics_service.dart';
import 'services/casa_service.dart';
import 'theme/design_tokens.dart';
import 'theme/theme_controller.dart';

// Analítica de retorno (auditoría de producto, octubre 2026) -- sin ningún
// dato personal, solo compara la fecha de la última apertura guardada
// localmente con hoy. D1/D7/D30/D90 de verdad los calcula Firebase
// Analytics solo con tener el SDK activo (recolección automática); esto es
// un evento complementario, no la fuente de esa métrica.
Future<void> _registrarRetornoSiProcede() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final ultimaApertura = prefs.getString('repara_ultima_apertura');
    if (ultimaApertura != null && ultimaApertura != hoy) {
      await AnalyticsService.userReturned();
    }
    await prefs.setString('repara_ultima_apertura', hoy);
  } catch (e) {
    // La analítica nunca debe impedir que la app arranque.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';

  // App Check en modo "Monitor" -- igual que RiskRunner/Convive, no activar
  // "Enforce" en la consola hasta que la app se instale de verdad desde
  // Play Store/TestFlight (los builds de prueba se sideloadean).
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
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

  await setupLocator();
  final themeController = await ThemeController.load();
  unawaited(_registrarRetornoSiProcede());

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) CasaService.asegurarPerfilUsuario();
  });

  runApp(ReparaApp(themeController: themeController));
}

class ReparaApp extends StatelessWidget {
  const ReparaApp({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Repara',
        themeMode: themeController.mode,
        theme: buildReparaLightTheme(),
        darkTheme: buildReparaDarkTheme(),
        navigatorObservers: [AnalyticsService.observer],
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasData) return const CasaGateScreen();
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
