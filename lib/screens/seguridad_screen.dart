// lib/screens/seguridad_screen.dart
//
// "Seguridad" como pantalla propia (rediseño Ajustes, noviembre 2026):
// antes vivía como sección fija directamente en Ajustes -- ahora Ajustes
// solo tiene una fila de entrada con el estado resumido. Contenido y lógica
// movidos tal cual desde settings_screen.dart -- solo cambia dónde viven.
import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../services/security/biometric_service.dart';
import '../services/security/security_preferences_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/ios_list.dart';

class SeguridadScreen extends StatelessWidget {
  const SeguridadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          SeccionSeguridad(),
        ],
      ),
    );
  }
}

/// Ajustes de seguridad local (misión de endurecimiento, octubre 2026).
/// Puramente local: nunca sustituye a Firebase Auth/reglas. El bloqueo
/// general de la app al abrirla se quitó (octubre 2026, a petición del CEO:
/// el propio launcher del móvil ya ofrece "requerir Face ID" por app) --
/// solo quedan los dos gates puntuales, documentos y acceso a Pro.
class SeccionSeguridad extends StatefulWidget {
  const SeccionSeguridad({super.key});

  @override
  State<SeccionSeguridad> createState() => _SeccionSeguridadState();
}

class _SeccionSeguridadState extends State<SeccionSeguridad> {
  bool _cargando = true;
  bool _biometriaDisponible = false;
  bool _documentosProtegidos = false;
  bool _proProtegido = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final biometria = sl<BiometricService>();
    final disponible = await biometria.isAvailable();
    final documentosProtegidos = await SecurityPreferencesService.instance.isDocumentProtectionEnabled();
    final proProtegido = await SecurityPreferencesService.instance.isProGateEnabled();
    if (!mounted) return;
    setState(() {
      _biometriaDisponible = disponible;
      _documentosProtegidos = documentosProtegidos;
      _proProtegido = proProtegido;
      _cargando = false;
    });
  }

  Future<void> _cambiarProProtegido(bool valor) async {
    setState(() => _proProtegido = valor);
    await SecurityPreferencesService.instance.setProGateEnabled(valor);
  }

  Future<void> _cambiarDocumentosProtegidos(bool valor) async {
    setState(() => _documentosProtegidos = valor);
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(valor);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    return IosSection(
      footer: !_biometriaDisponible
          ? 'Este dispositivo no tiene biometría configurada (Face ID, huella) o la app no tiene permiso para usarla.'
          : null,
      rows: [
        IosRow(
          icon: Icons.folder_shared_outlined,
          iconColor: context.colors.brand,
          title: 'Proteger documentos sensibles',
          subtitle: _biometriaDisponible
              ? 'Pide Face ID/huella antes de abrir una factura o garantía'
              : 'No disponible en este dispositivo',
          showChevron: false,
          trailing: Switch(
            value: _documentosProtegidos && _biometriaDisponible,
            onChanged: _biometriaDisponible ? _cambiarDocumentosProtegidos : null,
          ),
        ),
        IosRow(
          icon: Icons.engineering_outlined,
          iconColor: context.colors.brand,
          title: 'Proteger el acceso a Repara Pro',
          subtitle: _biometriaDisponible
              ? 'Pide Face ID/huella antes de entrar en modo profesional'
              : 'No disponible en este dispositivo',
          showChevron: false,
          trailing: Switch(
            value: _proProtegido && _biometriaDisponible,
            onChanged: _biometriaDisponible ? _cambiarProProtegido : null,
          ),
        ),
      ],
    );
  }
}
