// lib/documento_gate.dart
//
// La implementación real del contrato [VerificarAccesoDocumento]
// (packages/repara_ui/lib/abrir_protegido.dart): antes de abrir un archivo,
// solo pide biometría si el usuario activó la protección de documentos en
// Ajustes. Extraído a repara_core en noviembre 2026 (antes era exclusivo
// del monolito, `verificarAccesoDocumentoHogar`) para que Hogar y Pro
// reutilicen exactamente la misma lógica en vez de cada una tener la suya.
import 'package:flutter/material.dart';

import 'biometric_service.dart';
import 'security_preferences_service.dart';

Future<bool> verificarAccesoDocumento(BuildContext context) async {
  if (!await SecurityPreferencesService.instance.isDocumentProtectionEnabled()) {
    return true;
  }
  return await BiometricAuth.instance.authenticate(
        'Verifica tu identidad para abrir este documento',
      ) ==
      BiometricAuthResult.success;
}
