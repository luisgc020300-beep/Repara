// lib/services/security/security_preferences_service.dart
//
// Ajustes de seguridad local (misión de seguridad local, octubre 2026):
// protección de documentos sensibles y verificación al entrar en REPARA Pro.
// El bloqueo general de la app al abrirla (con su propio timeout) se quitó
// -- el launcher del móvil ya ofrece "requerir Face ID" por app, así que
// duplicarlo dentro de Repara no aportaba nada.
//
// Se guardan con flutter_secure_storage (Keychain en iOS, Keystore/
// EncryptedSharedPreferences en Android) y NUNCA con SharedPreferences --
// son ajustes que controlan una cerradura de seguridad local, y un
// dispositivo rooteado/jailbreak no debería poder desactivarlos solo con
// editar un archivo de preferencias en claro.
//
// Esto nunca concede permisos de negocio: solo decide si la UI pide
// biometría antes de dejar continuar. Los permisos reales siguen estando
// en Firebase Auth / Firestore / Storage / Cloud Functions.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityPreferencesService {
  SecurityPreferencesService._();
  static final SecurityPreferencesService instance = SecurityPreferencesService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kDocumentProtectionEnabled = 'security_document_protection_enabled';
  static const _kProGateEnabled = 'security_pro_gate_enabled';

  Future<bool> isDocumentProtectionEnabled() async =>
      (await _storage.read(key: _kDocumentProtectionEnabled)) == 'true';

  Future<void> setDocumentProtectionEnabled(bool valor) =>
      _storage.write(key: _kDocumentProtectionEnabled, value: valor.toString());

  Future<bool> isProGateEnabled() async => (await _storage.read(key: _kProGateEnabled)) == 'true';

  Future<void> setProGateEnabled(bool valor) => _storage.write(key: _kProGateEnabled, value: valor.toString());

  /// Solo para el flujo de eliminar cuenta -- deja el dispositivo en un
  /// estado limpio, igual que FcmService.olvidarEsteDispositivo() ya hace
  /// con el token de notificaciones.
  Future<void> limpiarTodo() async {
    await _storage.delete(key: _kDocumentProtectionEnabled);
    await _storage.delete(key: _kProGateEnabled);
  }
}
