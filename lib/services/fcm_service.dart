// lib/services/fcm_service.dart
//
// Notificaciones push (sección 29 del spec, FCM): complementan -- no
// sustituyen -- las notificaciones internas de NotificacionService. El
// token se guarda en users/{uid}.fcmTokens (array, un dispositivo puede
// tener varios si el usuario tiene más de un teléfono con sesión abierta).
// La navegación al tocar una push usa el mismo abrirDestinoNotificacion que
// la lista interna (notificacion_router.dart), para no duplicar lógica.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  FcmService._();

  static final _db = FirebaseFirestore.instance;
  static StreamSubscription<String>? _refreshSub;

  /// Pide permiso y registra el token del dispositivo. Se llama una vez
  /// autenticado (ver main.dart) -- un rechazo de permiso no debe impedir
  /// que el resto de la app funcione, por eso todo va envuelto en try/catch.
  static Future<void> inicializar() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _guardarToken(token);

      unawaited(_refreshSub?.cancel());
      _refreshSub = messaging.onTokenRefresh.listen(_guardarToken);
    } catch (e, st) {
      debugPrint('FcmService.inicializar: $e');
      await FirebaseCrashlytics.instance.recordError(e, st);
    }
  }

  static Future<void> _guardarToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e, st) {
      debugPrint('FcmService._guardarToken: $e');
      await FirebaseCrashlytics.instance.recordError(e, st);
    }
  }

  /// Se llama antes de cerrar sesión -- sin esto, el dispositivo seguiría
  /// recibiendo pushes de una cuenta de la que ya no se ha hecho logout.
  static Future<void> olvidarEsteDispositivo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (uid != null && token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e, st) {
      debugPrint('FcmService.olvidarEsteDispositivo: $e');
      await FirebaseCrashlytics.instance.recordError(e, st);
    }
    await _refreshSub?.cancel();
    _refreshSub = null;
  }
}
