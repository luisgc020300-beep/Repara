// packages/repara_ui/lib/abrir_protegido.dart
//
// Apertura de un archivo externo (documento, comprobante) con una
// verificación de acceso opcional e inyectada (Fase 2B.3, noviembre 2026):
// el gate biométrico real es exclusivo de Hogar (SecurityPreferencesService
// + BiometricService, ver lib/services/security/documento_gate.dart en la
// app) -- este paquete compartido nunca los importa, solo declara el
// contrato ([VerificarAccesoDocumento]) y lo ejecuta si alguien lo inyecta.
// Sin capacidad inyectada, se abre directamente sin gate -- así es como Pro
// puede abrir documentos sin depender de servicios exclusivos de Hogar.
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
