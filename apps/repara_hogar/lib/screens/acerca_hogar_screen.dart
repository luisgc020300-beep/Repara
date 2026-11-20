// apps/repara_hogar/lib/screens/acerca_hogar_screen.dart
//
// "Acerca de REPARA" (rediseño de Ajustes, noviembre 2026) -- identidad de
// la app, versión (de pubspec.yaml, sin añadir package_info_plus solo para
// esto), la guía de uso (texto nativo, ver guia_uso_screen.dart) y los
// enlaces legales. Versión Hogar de lib/screens/acerca_screen.dart
// (monolito), con el mismo enlace legal -- no se inventa ningún documento
// nuevo, es el mismo ya publicado.
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/ios_list.dart';
import 'guia_uso_screen.dart';

// Misma URL que el monolito (lib/screens/acerca_screen.dart) -- un único
// documento legal para todo REPARA, con dos secciones (#privacidad /
// #terminos).
const _urlLegal = 'https://claude.ai/artifact/G771r2pFWuiAFRXxHA69rC';

// Contacto de soporte (noviembre 2026) -- mismo buzón en Hogar, Pro y el
// monolito: un único punto de contacto para todo REPARA.
const _emailSoporte = 'ayudaycontactorepara@gmail.com';

// pubspec.yaml: version: 1.0.0+1 -- literal aquí porque añadir
// package_info_plus solo para leer esto en tiempo de ejecución sería una
// dependencia nueva innecesaria para un dato que ya es estático en el build.
const _version = '1.0.0 (1)';

class AcercaHogarScreen extends StatefulWidget {
  const AcercaHogarScreen({super.key});

  @override
  State<AcercaHogarScreen> createState() => _AcercaHogarScreenState();
}

class _AcercaHogarScreenState extends State<AcercaHogarScreen> {
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
      query: 'subject=${Uri.encodeComponent('Soporte REPARA Hogar')}',
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
                icon: Icons.home_repair_service_outlined,
                iconColor: context.colors.brand,
                title: 'REPARA Hogar',
                subtitle: 'La memoria digital de tu vivienda',
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
                  MaterialPageRoute(builder: (_) => const GuiaUsoScreen()),
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
