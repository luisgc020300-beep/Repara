// lib/widgets/app_error.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

/// Feedback de error compartido para acciones de escritura -- sin esto, un
/// fallo de red deja al usuario sin saber si su acción se guardó o no.
class AppError {
  AppError._();

  /// [error]/[stackTrace] son opcionales -- pásalos cuando `show` se llama
  /// desde un catch de una operación crítica (pagos, presupuestos, cambios
  /// de alcance, finalización) para que quede registrado en Crashlytics y
  /// no dependa de que el usuario lo reporte a mano (auditoría, octubre 2026).
  static void show(BuildContext context, String message, {Object? error, StackTrace? stackTrace}) {
    if (error != null) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
