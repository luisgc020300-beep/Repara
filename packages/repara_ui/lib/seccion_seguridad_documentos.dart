// lib/seccion_seguridad_documentos.dart
//
// Interruptor de "Proteger documentos sensibles" (misión de seguridad
// local, octubre 2026 -- extraído del monolito a repara_ui en noviembre
// 2026 para que Hogar y Pro lo muestren en sus propios Ajustes sin
// reimplementar la misma fila). Solo la fila; el monolito añade además, en
// su propia pantalla de Seguridad, un segundo interruptor exclusivo suyo
// ("Proteger el acceso a Repara Pro") que no aplica aquí -- Hogar y Pro ya
// son apps separadas, no hay ningún "entrar en modo profesional" que
// proteger dentro de ellas.
import 'package:flutter/material.dart';
import 'package:repara_core/biometric_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/security_preferences_service.dart';

import 'app_error.dart';
import 'ios_list.dart';

class SeccionSeguridadDocumentos extends StatefulWidget {
  const SeccionSeguridadDocumentos({super.key});

  @override
  State<SeccionSeguridadDocumentos> createState() =>
      _SeccionSeguridadDocumentosState();
}

class _SeccionSeguridadDocumentosState
    extends State<SeccionSeguridadDocumentos> {
  bool _cargando = true;
  bool _biometriaDisponible = false;
  bool _documentosProtegidos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final disponible = await BiometricAuth.instance.isAvailable();
    final documentosProtegidos = await SecurityPreferencesService.instance
        .isDocumentProtectionEnabled();
    if (!mounted) return;
    setState(() {
      _biometriaDisponible = disponible;
      _documentosProtegidos = documentosProtegidos;
      _cargando = false;
    });
  }

  // Al ACTIVAR se pide Face ID/huella ahora mismo (mismo criterio que el
  // monolito: confirma que la biometría funciona de verdad en este
  // dispositivo antes de depender de ella). Al DESACTIVAR no hace falta --
  // quitar una protección no necesita la propia protección.
  Future<void> _cambiarDocumentosProtegidos(bool valor) async {
    if (valor) {
      final resultado = await BiometricAuth.instance.authenticate(
        'Verifica tu identidad para proteger tus documentos',
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
    setState(() => _documentosProtegidos = valor);
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(
      valor,
    );
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
            onChanged: _biometriaDisponible
                ? _cambiarDocumentosProtegidos
                : null,
          ),
        ),
      ],
    );
  }
}
