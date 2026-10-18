// lib/widgets/app_dialog.dart
//
// Diálogos de confirmación y de texto repetidos por toda la app (eliminar,
// cerrar sesión, renombrar, canjear un código...) -- antes cada pantalla
// montaba su propio AlertDialog a mano, con el chrome por defecto de
// Material y el color "destructivo" aplicado a mano en unos sitios sí y en
// otros no. Centraliza solo el estilo y el armazón: el texto, el orden de
// las acciones y cuándo se ejecuta cada una los sigue decidiendo quien
// llama, igual que antes (rediseño "REPARA Professional", octubre 2026).
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class AppDialog {
  AppDialog._();

  static ShapeBorder _shape() => shape();

  /// Forma compartida para diálogos con contenido propio (formularios con
  /// selector de fecha, pasos con estado...) que no encajan en
  /// confirm/confirmText/promptText pero sí deben tener el mismo borde
  /// redondeado que el resto.
  static ShapeBorder shape() => RoundedRectangleBorder(borderRadius: BorderRadius.circular(ReparaRadius.md));

  /// Confirmación binaria (Cancelar / acción) con la acción principal en un
  /// botón relleno. [destructive] lo pinta en el rojo de marca -- eliminar
  /// cuenta, cerrar sesión en todos los dispositivos...
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String cancelLabel = 'Cancelar',
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _shape(),
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: ctx.colors.errorText) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  /// Misma confirmación binaria, pero con la acción principal en texto, no
  /// en botón relleno -- para los "¿eliminar esto?" sin cuerpo donde un
  /// botón relleno pesaría más que la propia pregunta. [destructive]
  /// (por defecto true aquí) pinta esa acción en rojo.
  static Future<bool> confirmText(
    BuildContext context, {
    required String title,
    String? message,
    String cancelLabel = 'Cancelar',
    required String confirmLabel,
    bool destructive = true,
  }) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _shape(),
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
          TextButton(
            style: destructive ? TextButton.styleFrom(foregroundColor: ctx.colors.errorText) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  /// Pide un texto corto (nombre, código, descripción...). Devuelve el
  /// valor ya recortado (`trim`) o null si se cancela -- igual que hacía
  /// cada pantalla a mano.
  static Future<String?> promptText(
    BuildContext context, {
    required String title,
    String? hint,
    String initialValue = '',
    String confirmLabel = 'Guardar',
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? minLines,
    int? maxLines,
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _shape(),
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: textCapitalization,
          minLines: minLines,
          maxLines: maxLines ?? minLines ?? 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(confirmLabel)),
        ],
      ),
    );
    ctrl.dispose();
    return valor;
  }
}
