// apps/repara_pro/lib/screens/acerca_pro_screen.dart
//
// "Acerca de REPARA" para el lado Pro -- paridad con
// apps/repara_hogar/lib/screens/acerca_hogar_screen.dart (mismo patrón,
// mismo enlace legal ya publicado, nunca uno inventado), adaptada solo en
// el texto de identidad.
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/ios_list.dart';
import 'guia_uso_pro_screen.dart';

// Misma URL que Hogar y el monolito -- un único documento legal para todo
// REPARA, con dos secciones (#privacidad / #terminos).
const _urlLegal = 'https://claude.ai/artifact/G771r2pFWuiAFRXxHA69rC';

// Contacto de soporte (noviembre 2026) -- mismo buzón en Hogar, Pro y el
// monolito: un único punto de contacto para todo REPARA.
const _emailSoporte = 'ayudaycontactorepara@gmail.com';

// pubspec.yaml de apps/repara_pro: version: 1.0.0+1 -- literal aquí por el
// mismo motivo que en Hogar: añadir package_info_plus solo para leer un
// dato ya estático en el build sería una dependencia nueva innecesaria.
const _version = '1.0.0 (1)';

class AcercaProScreen extends StatefulWidget {
  const AcercaProScreen({super.key});

  @override
  State<AcercaProScreen> createState() => _AcercaProScreenState();
}

class _AcercaProScreenState extends State<AcercaProScreen> {
  Future<void> _abrirLegal(String ancla) async {
    final uri = Uri.parse('$_urlLegal#$ancla');
    try {
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!abierto && mounted) {
        AppError.show(context, 'No se pudo abrir el enlace.');
      }
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo abrir el enlace.');
    }
  }

  Future<void> _contactarSoporte() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _emailSoporte,
      query: 'subject=${Uri.encodeComponent('Soporte REPARA Pro')}',
    );
    try {
      final abierto = await launchUrl(uri);
      if (!abierto && mounted) AppError.show(context, 'No se pudo abrir el correo.');
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo abrir el correo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de REPARA')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          IosSection(
            rows: [
              IosRow(
                icon: Icons.handyman_outlined,
                iconColor: context.colors.brand,
                title: 'REPARA Pro',
                subtitle: 'Gestiona tus trabajos y clientes desde un solo sitio',
                showChevron: false,
              ),
              IosRow(
                icon: Icons.info_outline,
                iconColor: context.colors.brand,
                title: 'Versión $_version',
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: ReparaSpace.s4),
          IosSection(
            header: 'Ayuda',
            rows: [
              IosRow(
                icon: Icons.menu_book_outlined,
                iconColor: context.colors.brand,
                title: 'Guía de uso',
                subtitle: 'Qué hace la app y preguntas frecuentes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuiaUsoProScreen()),
                ),
              ),
              IosRow(
                icon: Icons.email_outlined,
                iconColor: context.colors.brand,
                title: 'Contacto de soporte',
                subtitle: _emailSoporte,
                onTap: _contactarSoporte,
              ),
            ],
          ),
          const SizedBox(height: ReparaSpace.s4),
          IosSection(
            header: 'Legal',
            rows: [
              IosRow(
                icon: Icons.privacy_tip_outlined,
                iconColor: context.colors.brand,
                title: 'Política de privacidad',
                onTap: () => _abrirLegal('privacidad'),
              ),
              IosRow(
                icon: Icons.description_outlined,
                iconColor: context.colors.brand,
                title: 'Términos de servicio',
                onTap: () => _abrirLegal('terminos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
