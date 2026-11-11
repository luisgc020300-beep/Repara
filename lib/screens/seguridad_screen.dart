// lib/screens/seguridad_screen.dart
//
// "Seguridad" como pantalla propia (rediseño Ajustes, noviembre 2026):
// antes vivía como sección fija directamente en Ajustes -- ahora Ajustes
// solo tiene una fila de entrada con el estado resumido.
//
// La fila "Proteger documentos sensibles" se extrajo a
// repara_ui/seccion_seguridad_documentos.dart (noviembre 2026) para que
// Hogar y Pro la reutilicen tal cual -- aquí solo queda, además de esa
// fila compartida, la fila "Proteger el acceso a Repara Pro", que sigue
// siendo exclusiva del monolito: Hogar y Pro ya son apps separadas, no
// existe en ellas un "entrar en modo profesional" que proteger.
import 'package:flutter/material.dart';

import 'package:repara_core/biometric_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/security_preferences_service.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/ios_list.dart';
import 'package:repara_ui/seccion_seguridad_documentos.dart';

class SeguridadScreen extends StatelessWidget {
  const SeguridadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          SeccionSeguridadDocumentos(),
          _SeccionProtegerPro(),
        ],
      ),
    );
  }
}

/// Fila exclusiva del monolito -- ver cabecera del archivo.
class _SeccionProtegerPro extends StatefulWidget {
  const _SeccionProtegerPro();

  @override
  State<_SeccionProtegerPro> createState() => _SeccionProtegerProState();
}

class _SeccionProtegerProState extends State<_SeccionProtegerPro> {
  bool _cargando = true;
  bool _biometriaDisponible = false;
  bool _proProtegido = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final disponible = await BiometricAuth.instance.isAvailable();
    final proProtegido = await SecurityPreferencesService.instance
        .isProGateEnabled();
    if (!mounted) return;
    setState(() {
      _biometriaDisponible = disponible;
      _proProtegido = proProtegido;
      _cargando = false;
    });
  }

  // Al ACTIVAR se pide Face ID/huella ahora mismo (CEO, noviembre 2026:
  // "pedir el Face ID cuando marques los permisos en ajustes") -- confirma
  // que la biometría funciona de verdad en este dispositivo antes de
  // depender de ella; si falla, se cancela o da error, el interruptor no
  // llega a activarse. Al DESACTIVAR no hace falta -- quitar una
  // protección no necesita la propia protección.
  Future<void> _cambiarProProtegido(bool valor) async {
    if (valor) {
      final resultado = await BiometricAuth.instance.authenticate(
        'Verifica tu identidad para proteger el acceso a Repara Pro',
      );
      if (resultado != BiometricAuthResult.success) {
        if (mounted) {
          AppError.show(
            context,
            resultado == BiometricAuthResult.cancelled
                ? 'Verificación cancelada -- no se ha activado.'
                : 'No se pudo verificar tu identidad. Inténtalo de nuevo.',
          );
        }
        return;
      }
    }
    setState(() => _proProtegido = valor);
    await SecurityPreferencesService.instance.setProGateEnabled(valor);
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
