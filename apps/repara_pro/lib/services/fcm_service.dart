// lib/services/fcm_service.dart
//
// Notificaciones push (FCM, noviembre 2026) -- complementan, no sustituyen,
// las notificaciones internas de NotificacionService. El token se guarda en
// users/{uid}.fcmTokens (mismo campo que ya escribe REPARA Hogar para la
// misma cuenta -- un usuario con las dos apps instaladas en dispositivos
// distintos simplemente acumula un token por dispositivo en el mismo
// array, igual que si tuviera Hogar en dos teléfonos). La navegación al
// tocar una push usa el mismo abrirDestinoNotificacionPro que la lista
// interna (notificacion_router_pro.dart), para no duplicar lógica.
//
// Copia exacta del patrón ya probado en apps/repara_hogar/lib/services/
// fcm_service.dart -- mismo campo de Firestore, mismo criterio de
// try/catch (un rechazo de permiso nunca debe impedir que el resto de la
// app funcione).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  FcmService._();

  /// Seams de solo test -- nunca se asignan en código de producción. Ver
  /// fcm_service.dart de Hogar para el criterio general.
  @visibleForTesting
  static FirebaseFirestore? debugFirestoreOverride;
  @visibleForTesting
  static String? debugUidOverride;

  static FirebaseFirestore get _db =>
      debugFirestoreOverride ?? FirebaseFirestore.instance;
  static String? get _uid => debugFirestoreOverride != null
      ? debugUidOverride
      : FirebaseAuth.instance.currentUser?.uid;
  static StreamSubscription<String>? _refreshSub;

  // FirebaseCrashlytics.instance en sí mismo puede lanzar (p.ej.
  // "[core/no-app]" si no hay una app de Firebase real inicializada, como
  // en un test de widgets que monta ReparaProShellScreen sin
  // Firebase.initializeApp()) -- sin este segundo try/catch, ese fallo de
  // "reportar el error" se escapaba del catch que lo rodeaba y acababa
  // rompiendo el árbol de widgets entero, justo lo que este servicio existe
  // para evitar.
  static Future<void> _registrarError(
    String contexto,
    Object e,
    StackTrace st,
  ) async {
    debugPrint('$contexto: $e');
    try {
      await FirebaseCrashlytics.instance.recordError(e, st);
    } catch (_) {
      // Ver comentario de arriba -- un fallo al reportar el error nunca
      // debe propagarse.
    }
  }

  /// Pide permiso y registra el token del dispositivo. Se llama una vez
  /// autenticado y activado el modo profesional (ver repara_pro_shell_screen.
  /// dart) -- un rechazo de permiso no debe impedir que el resto de la app
  /// funcione, por eso todo va envuelto en try/catch.
  static Future<void> inicializar() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _guardarToken(token);

      unawaited(_refreshSub?.cancel());
      _refreshSub = messaging.onTokenRefresh.listen(_guardarToken);
    } catch (e, st) {
      await _registrarError('FcmService.inicializar', e, st);
    }
  }

  static Future<void> _guardarToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e, st) {
      await _registrarError('FcmService._guardarToken', e, st);
    }
  }

  /// Se llama antes de cerrar sesión -- sin esto, el dispositivo seguiría
  /// recibiendo pushes de una cuenta de la que ya no se ha hecho logout.
  static Future<void> olvidarEsteDispositivo() async {
    final uid = _uid;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (uid != null && token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e, st) {
      await _registrarError('FcmService.olvidarEsteDispositivo', e, st);
    }
    await _refreshSub?.cancel();
    _refreshSub = null;
  }
}
