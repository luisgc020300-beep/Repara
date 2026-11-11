// apps/repara_hogar/lib/screens/ajustes_hogar_screen.dart
//
// Version Hogar, minima pero funcional, de lib/screens/settings_screen.dart
// (monolito). No incluye el selector Hogar/Pro (esta app ya es solo
// Hogar). Si incluye: cuenta (eliminar/cerrar en todos los dispositivos,
// via el CuentaScreen compartido), tu vivienda, tema, preferencias de
// notificaciones y proteccion biometrica de documentos.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/theme_controller.dart';
import 'package:repara_ui/cuenta_screen.dart';
import 'package:repara_ui/ios_list.dart';
import 'package:repara_ui/notificaciones_preferencias_screen.dart';
import 'package:repara_ui/seccion_seguridad_documentos.dart';

import '../models/casa.dart';
import '../services/fcm_service.dart';
import 'gestionar_vivienda_screen.dart';

class AjustesHogarScreen extends StatefulWidget {
  const AjustesHogarScreen({this.casa, super.key});

  final Casa? casa;

  @override
  State<AjustesHogarScreen> createState() => _AjustesHogarScreenState();
}

class _AjustesHogarScreenState extends State<AjustesHogarScreen> {
  void _abrirCuenta(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CuentaScreen(
        eliminarCuentaMensaje:
            'Se borra tu perfil y, si eres el único miembro de tu vivienda, también la vivienda entera con su '
            'historial, documentos y fotos. Si la compartes con alguien más, solo se elimina tu vinculación a ella. '
            'Esta acción no se puede deshacer.',
        antesDeCerrarSesion: FcmService.olvidarEsteDispositivo,
      ),
    ),
  );

  String _temaLabel() => switch (ThemeController.instance.mode) {
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
    ThemeMode.system => 'Sistema',
  };

  Widget _valorConChevron(BuildContext context, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.inkMuted)),
      const SizedBox(width: 2),
      Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
    ],
  );

  Future<void> _abrirSelectorTema(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ReparaSpace.s4, ReparaSpace.s2, ReparaSpace.s4, ReparaSpace.s4),
          child: AnimatedBuilder(
            animation: ThemeController.instance,
            builder: (context, _) => IosSection(
              rows: [
                IosRow(
                  icon: Icons.light_mode_outlined,
                  iconColor: context.colors.brand,
                  title: 'Claro',
                  selected: ThemeController.instance.mode == ThemeMode.light,
                  onTap: () {
                    ThemeController.instance.setMode(ThemeMode.light);
                    Navigator.pop(ctx);
                  },
                ),
                IosRow(
                  icon: Icons.dark_mode_outlined,
                  iconColor: context.colors.brand,
                  title: 'Oscuro',
                  selected: ThemeController.instance.mode == ThemeMode.dark,
                  onTap: () {
                    ThemeController.instance.setMode(ThemeMode.dark);
                    Navigator.pop(ctx);
                  },
                ),
                IosRow(
                  icon: Icons.smartphone_outlined,
                  iconColor: context.colors.brand,
                  title: 'Igual que el sistema',
                  selected: ThemeController.instance.mode == ThemeMode.system,
                  onTap: () {
                    ThemeController.instance.setMode(ThemeMode.system);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final casa = widget.casa;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            IosSection(
              header: 'Tu cuenta',
              rows: [
                IosRow(
                  icon: Icons.person_outline,
                  iconColor: context.colors.brand,
                  title: user?.email ?? 'Tu cuenta',
                  subtitle: 'Gestiona tu cuenta',
                  onTap: () => _abrirCuenta(context),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            if (casa != null) ...[
              IosSection(
                header: 'Tu vivienda',
                rows: [
                  IosRow(
                    icon: Icons.house_rounded,
                    iconColor: context.colors.brand,
                    title: casa.nombre,
                    subtitle: 'Gestiona tu vivienda',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GestionarViviendaScreen(casa: casa)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s4),
            ],
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.palette_outlined,
                  iconColor: context.colors.brand,
                  title: 'Tema',
                  trailing: _valorConChevron(context, _temaLabel()),
                  onTap: () => _abrirSelectorTema(context),
                ),
                IosRow(
                  icon: Icons.notifications_outlined,
                  iconColor: context.colors.brand,
                  title: 'Notificaciones',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificacionesPreferenciasScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            const SeccionSeguridadDocumentos(),
          ],
        ),
      ),
    );
  }
}
