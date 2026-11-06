// lib/services/security/documento_gate.dart
//
// Capacidad real de Hogar para inyectar en abrir_protegido.dart/
// miniatura_documento.dart de repara_ui (ver VerificarAccesoDocumento) --
// el gate biométrico sigue siendo exclusivo de Hogar: SecurityPreferences
// Service y BiometricService nunca se mueven a un paquete compartido
// (misión de seguridad local, sección 6).
//
// Separado a propósito de documento_abrir.dart (Fase 2B.3, noviembre
// 2026): ese archivo también arrastra editar_documento_sheet.dart, una
// pantalla completa que pagos_section.dart (compartida con Pro) no
// necesita para nada -- aislar solo el gate en este archivo mínimo es lo
// que de verdad desbloquea pagos_section.dart de esa pantalla.
import 'package:flutter/material.dart';

import '../../core/service_locator.dart';
import 'biometric_service.dart';
import 'security_preferences_service.dart';

/// El [VerificarAccesoDocumento] real de Hogar: antes de abrir un archivo,
/// solo pide biometría si el propietario activó la protección de
/// documentos en Ajustes (ver seguridad_screen.dart) -- mismo
/// comportamiento exacto que tenía abrirArchivoProtegido() antes de esta
/// separación.
Future<bool> verificarAccesoDocumentoHogar(BuildContext context) async {
  if (!await SecurityPreferencesService.instance
      .isDocumentProtectionEnabled()) {
    return true;
  }
  return await sl<BiometricService>().authenticate(
        'Verifica tu identidad para abrir este documento',
      ) ==
      BiometricAuthResult.success;
}
