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
    _mostrar(context, message, icon: Icons.error_outline);
  }

  static void showSuccess(BuildContext context, String message) {
    _mostrar(context, message, icon: Icons.check_circle_outline);
  }

  static void _mostrar(BuildContext context, String message, {required IconData icon}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).scaffoldBackgroundColor),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ));
  }
}
