// lib/widgets/app_error.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

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

/// Aviso de "todavía no hay nada aquí" para una lista o sección embebida
/// (pagos, documentos, historial...) -- antes cada pantalla ponía un Text
/// suelto con un color distinto a mano; esto le da el mismo icono apagado +
/// texto secundario en todos los sitios donde cabe una línea, no un estado
/// vacío a pantalla completa (ese ya tiene su propio tratamiento con icono
/// grande, ver HomeTab/ExpedienteViviendaScreen).
class EmptyHint extends StatelessWidget {
  const EmptyHint({required this.message, this.icon = Icons.inbox_outlined, super.key});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: context.colors.inkFaint),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
