// lib/screens/acerca_screen.dart
//
// "Acerca de REPARA" (rediseño Ajustes, noviembre 2026): identidad de la
// app + los enlaces legales, que antes vivían como sección "Legal" suelta
// directamente en Ajustes.
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/ios_list.dart';

// URL única con dos secciones (#privacidad / #terminos) -- más fácil de
// mantener que dos páginas separadas mientras la app es de un único
// desarrollador.
const _urlLegal = 'https://claude.ai/artifact/G771r2pFWuiAFRXxHA69rC';

class AcercaScreen extends StatefulWidget {
  const AcercaScreen({super.key});

  @override
  State<AcercaScreen> createState() => _AcercaScreenState();
}

class _AcercaScreenState extends State<AcercaScreen> {
  Future<void> _abrirLegal(String ancla) async {
    final uri = Uri.parse('$_urlLegal#$ancla');
    try {
      final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abierto && mounted) AppError.show(context, 'No se pudo abrir el enlace.');
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo abrir el enlace.');
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
                title: 'REPARA',
                subtitle: 'La memoria digital de tu vivienda',
                showChevron: false,
              ),
            ],
          ),
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
