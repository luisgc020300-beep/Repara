// lib/widgets/documento_abrir.dart
//
// Abrir el archivo real de un documento (CEO, noviembre 2026: "no lee
// documentos ni deja entrar a ellos") -- compartido entre la ficha de
// elemento, la pestaña Documentos de un registro y el listado de Documentos
// de la casa (Ajustes), que antes tenían cada una su propio trozo de lógica
// (o, en el caso de las dos primeras, ninguna -- las filas no tenían onTap).
// El gate biométrico es el mismo para los tres sitios: abrir el archivo en sí
// es el contenido sensible (sección 6 de la misión de seguridad local).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/service_locator.dart';
import '../models/documento.dart';
import '../services/security/biometric_service.dart';
import '../services/security/security_preferences_service.dart';
import 'app_error.dart';

Future<void> abrirDocumento(BuildContext context, Documento documento) async {
  if (await SecurityPreferencesService.instance.isDocumentProtectionEnabled()) {
    final verificado = await sl<BiometricService>().authenticate('Verifica tu identidad para abrir este documento') ==
        BiometricAuthResult.success;
    if (!verificado) return;
  }
  if (!context.mounted) return;
  final uri = Uri.tryParse(documento.url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) AppError.show(context, 'No se pudo abrir el documento.');
  }
}
