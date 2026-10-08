// lib/screens/security/app_lock_screen.dart
//
// Pantalla de bloqueo (Fase E de la misión de seguridad local, octubre
// 2026). Se muestra por encima de toda la app (ver _LockGate en main.dart)
// cuando AppLockController.isLocked es true y hay sesión de Firebase
// activa -- nunca sustituye al login, solo tapa la app mientras no se
// verifica la biometría.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/service_locator.dart';
import '../../services/security/app_lock_controller.dart';
import '../../services/security/biometric_service.dart';
import '../../theme/design_tokens.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with WidgetsBindingObserver {
  bool _verificando = false;
  bool _sinBiometriaDisponible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Se intenta sola al aparecer -- el usuario no debería tener que tocar
    // un botón para que se le pida Face ID/huella, igual que en iOS nativo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _intentarDesbloquear());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si el usuario cambió de opinión en el selector nativo de biometría y
    // volvió a primer plano sin completar el reto, reintentar es más útil
    // que dejar la pantalla esperando un toque manual.
    if (state == AppLifecycleState.resumed && mounted && !_verificando) {
      _intentarDesbloquear();
    }
  }

  Future<void> _intentarDesbloquear() async {
    if (_verificando || !mounted) return;
    setState(() {
      _verificando = true;
      _sinBiometriaDisponible = false;
    });
    final biometria = sl<BiometricService>();
    final disponible = await biometria.isAvailable();
    if (!disponible) {
      if (mounted) setState(() => _sinBiometriaDisponible = true);
    } else {
      await AppLockController.instance.tryUnlock(biometria, reason: 'Desbloquea Repara');
    }
    if (mounted) setState(() => _verificando = false);
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    // El cierre de sesión ya hace que _LockGate dibuje LoginScreen en vez
    // de esta pantalla (deja de haber currentUser) -- no hace falta tocar
    // isLocked aquí.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: context.colors.brand),
                const SizedBox(height: 20),
                Text(
                  'Repara está bloqueado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.ink),
                ),
                const SizedBox(height: 10),
                if (_sinBiometriaDisponible) ...[
                  Text(
                    'No se pudo verificar tu biometría en este dispositivo. Cierra sesión y vuelve a entrar para '
                    'seguir usando Repara.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: context.colors.inkMuted),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _cerrarSesion, child: const Text('Cerrar sesión')),
                ] else ...[
                  Text(
                    'Verifica tu identidad para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: context.colors.inkMuted),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _verificando ? null : _intentarDesbloquear,
                    icon: _verificando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fingerprint),
                    label: Text(_verificando ? 'Verificando…' : 'Desbloquear'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
