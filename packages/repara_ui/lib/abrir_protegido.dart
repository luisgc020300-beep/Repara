// packages/repara_ui/lib/abrir_protegido.dart
//
// Apertura de un archivo externo (documento, comprobante) con una
// verificación de acceso opcional e inyectada (Fase 2B.3, noviembre 2026).
// El gate biométrico real (BiometricService/SecurityPreferencesService)
// vive en repara_core/documento_gate.dart (movido ahí en noviembre 2026
// para que el monolito, Hogar y Pro lo reutilicen sin duplicarlo) -- este
// paquete solo declara el contrato ([VerificarAccesoDocumento]) y lo
// ejecuta si alguien lo inyecta, sin importar repara_core para nada de
// esto. Sin capacidad inyectada, se abre directamente sin gate.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_error.dart';

/// Debe devolver `true` para continuar abriendo el archivo, `false` para
/// cancelar (p.ej. el usuario no superó el gate biométrico).
typedef VerificarAccesoDocumento = Future<bool> Function(BuildContext context);

Future<void> abrirArchivoProtegido(
  BuildContext context,
  String url, {
  VerificarAccesoDocumento? verificarAcceso,
}) async {
  if (verificarAcceso != null) {
    final autorizado = await verificarAcceso(context);
    if (!autorizado) return;
  }
  if (!context.mounted) return;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      AppError.show(context, 'No se pudo abrir el documento.');
    }
  }
}
