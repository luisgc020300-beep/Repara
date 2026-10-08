// lib/services/security/app_lock_controller.dart
//
// Máquina de estados del bloqueo de app (misión de seguridad local, octubre
// 2026). Deliberadamente sin UI aquí dentro -- la pantalla de bloqueo
// (Fase E) solo lee `isLocked` y llama a `tryUnlock`. Esto permite testear
// los 6 casos de la sección 32 de la misión sin levantar ningún widget.
//
// Importante: esto es una cerradura LOCAL sobre un dispositivo que ya tiene
// sesión de Firebase Auth iniciada -- nunca decide permisos de negocio.
// Si `isLocked` es true, la UI no debe enseñar nada sensible, pero la
// sesión de Firebase sigue intacta por debajo.
import 'package:flutter/widgets.dart';

import 'biometric_service.dart';
import 'security_preferences_service.dart';

class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController._();
  static final AppLockController instance = AppLockController._();

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  DateTime? _backgroundedAt;

  bool _observando = false;

  /// Llamar una sola vez al arrancar la app, tras iniciar sesión. Si el
  /// bloqueo biométrico está activado, la app arranca bloqueada (sección 42
  /// de la misión: "Abrir app bloqueada" también aplica en frío, no solo al
  /// volver de segundo plano).
  Future<void> init() async {
    if (!_observando) {
      WidgetsBinding.instance.addObserver(this);
      _observando = true;
    }
    final activado = await SecurityPreferencesService.instance.isBiometricLockEnabled();
    _setLocked(activado);
  }

  /// Llamar justo después de cambiar el interruptor en Ajustes → Seguridad.
  /// Desactivarlo desbloquea al instante -- activarlo NO bloquea de
  /// inmediato (el usuario sigue dentro de su propia acción de ajustes),
  /// solo se aplicará la próxima vez que la app pase a segundo plano.
  Future<void> refrescarAjustes() async {
    final activado = await SecurityPreferencesService.instance.isBiometricLockEnabled();
    if (!activado) _setLocked(false);
  }

  Future<bool> tryUnlock(BiometricService biometria, {required String reason}) async {
    final resultado = await biometria.authenticate(reason);
    if (resultado == BiometricAuthResult.success) {
      _setLocked(false);
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _alVolverAPrimerPlano();
    } else {
      // No pisar un _backgroundedAt ya guardado -- inactive/paused pueden
      // alternarse varias veces (p.ej. un selector nativo de foto) antes de
      // volver de verdad a resumed.
      _backgroundedAt ??= DateTime.now();
    }
  }

  Future<void> _alVolverAPrimerPlano() async {
    final fueASegundoPlano = _backgroundedAt;
    _backgroundedAt = null;
    if (fueASegundoPlano == null) return;

    final activado = await SecurityPreferencesService.instance.isBiometricLockEnabled();
    if (!activado) return;

    final limite = await SecurityPreferencesService.instance.getLockTimeout();
    final transcurrido = DateTime.now().difference(fueASegundoPlano);
    if (transcurrido >= limite.duration) {
      _setLocked(true);
    }
  }

  void _setLocked(bool valor) {
    if (_isLocked == valor) return;
    _isLocked = valor;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_observando) {
      WidgetsBinding.instance.removeObserver(this);
      _observando = false;
    }
    super.dispose();
  }
}
