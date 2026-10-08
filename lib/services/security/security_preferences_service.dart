// lib/services/security/security_preferences_service.dart
//
// Ajustes de seguridad local (misión de seguridad local, octubre 2026):
// bloqueo biométrico, tiempo de bloqueo, protección de documentos
// sensibles y verificación al entrar en REPARA Pro.
//
// Se guardan con flutter_secure_storage (Keychain en iOS, Keystore/
// EncryptedSharedPreferences en Android) y NUNCA con SharedPreferences --
// son ajustes que controlan una cerradura de seguridad local, y un
// dispositivo rooteado/jailbreak no debería poder desactivarlos solo con
// editar un archivo de preferencias en claro (sección 8 de la misión).
//
// Esto nunca concede permisos de negocio: solo decide si la UI pide
// biometría antes de dejar continuar. Los permisos reales siguen estando
// en Firebase Auth / Firestore / Storage / Cloud Functions.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Opciones de "bloquear después de" (sección 5 de la misión). 5 minutos
/// por defecto -- ni tan agresivo como para resultar molesto en el uso
/// normal (abrir y cerrar la app varias veces seguidas revisando algo), ni
/// tan laxo como para dejar la app desbloqueada toda una tarde.
enum LockTimeout {
  immediate(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15));

  const LockTimeout(this.duration);
  final Duration duration;
}

class SecurityPreferencesService {
  SecurityPreferencesService._();
  static final SecurityPreferencesService instance = SecurityPreferencesService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kBiometricLockEnabled = 'security_biometric_lock_enabled';
  static const _kLockTimeout = 'security_lock_timeout';
  static const _kDocumentProtectionEnabled = 'security_document_protection_enabled';
  static const _kProGateEnabled = 'security_pro_gate_enabled';

  Future<bool> isBiometricLockEnabled() async => (await _storage.read(key: _kBiometricLockEnabled)) == 'true';

  Future<void> setBiometricLockEnabled(bool valor) =>
      _storage.write(key: _kBiometricLockEnabled, value: valor.toString());

  Future<LockTimeout> getLockTimeout() async {
    final guardado = await _storage.read(key: _kLockTimeout);
    return LockTimeout.values.firstWhere((t) => t.name == guardado, orElse: () => LockTimeout.fiveMinutes);
  }

  Future<void> setLockTimeout(LockTimeout valor) => _storage.write(key: _kLockTimeout, value: valor.name);

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
    await _storage.delete(key: _kBiometricLockEnabled);
    await _storage.delete(key: _kLockTimeout);
    await _storage.delete(key: _kDocumentProtectionEnabled);
    await _storage.delete(key: _kProGateEnabled);
  }
}
