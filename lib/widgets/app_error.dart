// lib/widgets/app_error.dart
import 'package:flutter/material.dart';

/// Feedback de error compartido para acciones de escritura -- sin esto, un
/// fallo de red deja al usuario sin saber si su acción se guardó o no.
class AppError {
  AppError._();

  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
