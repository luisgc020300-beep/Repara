// apps/repara_hogar/lib/screens/ajustes_hogar_screen.dart
//
// Version Hogar, minima pero funcional, de lib/screens/settings_screen.dart
// (monolito). No incluye el selector Hogar/Pro (esta app ya es solo
// Hogar). Si incluye: cuenta (eliminar/cerrar en todos los dispositivos,
// via el CuentaScreen compartido), tu vivienda, apariencia, privacidad,
// notificaciones, contacto y soporte, acerca de, y cerrar sesion.
//
// Reorganización visual (noviembre 2026, sobre el mismo rediseño ya hecho
// en el monolito): tarjetas grandes para "Tu cuenta" y "Tu vivienda"
// (mismo patrón que _CuentaCard/_ViviendaCard de settings_screen.dart),
// "Tema" renombrado a "Apariencia" con un selector más claro (degradado
// con marca de verificación por modo, igual que el monolito), nueva
// sección "Contacto y soporte técnico" (mismo correo ya usado por el
// monolito, nunca uno inventado) y "Acerca de REPARA" (versión + enlaces
// legales ya publicados), y "Cerrar sesión" ahora visible en el menú
// principal, no solo dentro de "Tu cuenta".
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/theme_controller.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/cuenta_screen.dart';
import 'package:repara_ui/ios_list.dart';
import 'package:repara_ui/notificaciones_preferencias_screen.dart';
import 'package:repara_ui/seccion_seguridad_documentos.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/casa.dart';
import '../services/fcm_service.dart';
import 'acerca_hogar_screen.dart';
import 'gestionar_vivienda_screen.dart';

// Mismo canal de contacto ya implementado en el monolito
// (lib/screens/settings_screen.dart) -- nunca se inventa una dirección ni
// un servicio nuevo.
const _emailSoporte = 'luisgc020300@gmail.com';

class AjustesHogarScreen extends StatefulWidget {
  const AjustesHogarScreen({this.casa, super.key});

  final Casa? casa;

  @override
  State<AjustesHogarScreen> createState() => _AjustesHogarScreenState();
}

class _AjustesHogarScreenState extends State<AjustesHogarScreen> {
  Future<void> _abrirSoporte(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _emailSoporte,
      query: 'subject=${Uri.encodeComponent('Ayuda con REPARA Hogar')}',
    );
    try {
      final abierto = await launchUrl(uri);
      if (!abierto && context.mounted) {
        AppError.show(context, 'No se pudo abrir el correo.');
      }
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (context.mounted) {
        AppError.show(context, 'No se pudo abrir el correo.');
      }
    }
  }

  String _temaLabel() => switch (ThemeController.instance.mode) {
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
    ThemeMode.system => 'Sistema',
  };

  Widget _valorConChevron(BuildContext context, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        texto,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.colors.inkMuted),
      ),
      const SizedBox(width: 2),
      Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
    ],
  );

  Widget? _check(BuildContext context, bool seleccionado) => seleccionado
      ? Icon(Icons.check, color: context.colors.brand, size: 20)
      : null;

  // "Apariencia" (antes "Tema"): mismo selector modal, con marca de
  // verificación junto al modo activo y un asa de arrastre -- más claro
  // para distinguir claro/oscuro/sistema que el simple resaltado de antes.
  Future<void> _abrirSelectorApariencia(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ReparaSpace.s4,
            ReparaSpace.s2,
            ReparaSpace.s4,
            ReparaSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: ReparaSpace.s4),
                decoration: BoxDecoration(
                  color: ctx.colors.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedBuilder(
                animation: ThemeController.instance,
                builder: (context, _) => IosSection(
                  rows: [
                    IosRow(
                      icon: Icons.light_mode_outlined,
                      iconColor: context.colors.brand,
                      title: 'Claro',
                      trailing: _check(
                        context,
                        ThemeController.instance.mode == ThemeMode.light,
                      ),
                      selected:
                          ThemeController.instance.mode == ThemeMode.light,
                      onTap: () {
                        ThemeController.instance.setMode(ThemeMode.light);
                        Navigator.pop(ctx);
                      },
                    ),
                    IosRow(
                      icon: Icons.dark_mode_outlined,
                      iconColor: context.colors.brand,
                      title: 'Oscuro',
                      trailing: _check(
                        context,
                        ThemeController.instance.mode == ThemeMode.dark,
                      ),
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
                      trailing: _check(
                        context,
                        ThemeController.instance.mode == ThemeMode.system,
                      ),
                      selected:
                          ThemeController.instance.mode == ThemeMode.system,
                      onTap: () {
                        ThemeController.instance.setMode(ThemeMode.system);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final casa = widget.casa;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _cabecera(context, 'Tu cuenta'),
            const _CuentaCard(),

            if (casa != null) ...[
              _cabecera(context, 'Tu vivienda'),
              _ViviendaCard(casa: casa),
            ],

            IosSection(
              rows: [
                IosRow(
                  icon: Icons.palette_outlined,
                  iconColor: context.colors.brand,
                  title: 'Apariencia',
                  trailing: _valorConChevron(context, _temaLabel()),
                  onTap: () => _abrirSelectorApariencia(context),
                ),
                IosRow(
                  icon: Icons.notifications_outlined,
                  iconColor: context.colors.brand,
                  title: 'Notificaciones',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificacionesPreferenciasScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            const SeccionSeguridadDocumentos(),
            const SizedBox(height: ReparaSpace.s4),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.help_outline,
                  iconColor: context.colors.brand,
                  title: 'Contacto y soporte técnico',
                  onTap: () => _abrirSoporte(context),
                ),
                IosRow(
                  icon: Icons.info_outline,
                  iconColor: context.colors.brand,
                  title: 'Acerca de REPARA',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AcercaHogarScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.logout_outlined,
                  iconColor: context.colors.errorText,
                  title: 'Cerrar sesión',
                  titleColor: context.colors.errorText,
                  showChevron: false,
                  onTap: () => confirmarYCerrarSesion(
                    context,
                    antesDeCerrarSesion: FcmService.olvidarEsteDispositivo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _cabecera(BuildContext context, String texto) => Padding(
  padding: const EdgeInsets.only(left: 6, bottom: 6),
  child: Text(
    texto.toUpperCase(),
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: context.colors.inkMuted),
  ),
);

String _iniciales(User? user) {
  final nombre = user?.displayName?.trim();
  if (nombre != null && nombre.isNotEmpty) {
    final partes = nombre.split(RegExp(r'\s+'));
    final letras = partes.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
    if (letras.isNotEmpty) return letras.toUpperCase();
  }
  final email = user?.email;
  if (email != null && email.isNotEmpty) return email[0].toUpperCase();
  return '?';
}

/// Tarjeta de entrada a [CuentaScreen] -- avatar con iniciales (o foto si la
/// cuenta tiene una), nombre y correo. Mismo patrón que _CuentaCard en
/// lib/screens/settings_screen.dart (monolito).
class _CuentaCard extends StatelessWidget {
  const _CuentaCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: ReparaSpace.s5),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
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
          ),
          child: Padding(
            padding: const EdgeInsets.all(ReparaSpace.s4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: context.colors.brandStrong,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Text(
                          _iniciales(user),
                          style: TextStyle(
                            color: context.colors.brandOn,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: ReparaSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName!
                            : 'Tu cuenta',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.ink,
                            ),
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user!.email!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.colors.inkMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de entrada a [GestionarViviendaScreen]. Mismo patrón que
/// _ViviendaCard en lib/screens/settings_screen.dart (monolito).
class _ViviendaCard extends StatelessWidget {
  const _ViviendaCard({required this.casa});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ReparaSpace.s5),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GestionarViviendaScreen(casa: casa),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ReparaSpace.s4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.brandTint,
                    borderRadius: BorderRadius.circular(ReparaRadius.sm),
                  ),
                  child: Icon(
                    Icons.house_rounded,
                    color: context.colors.brandStrong,
                    size: 24,
                  ),
                ),
                const SizedBox(width: ReparaSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        casa.nombre,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gestiona tu vivienda',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.colors.inkMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
