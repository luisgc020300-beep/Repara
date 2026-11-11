// apps/repara_pro/lib/screens/ajustes_pro_screen.dart
//
// Versión Pro, mínima pero funcional, de lib/screens/settings_screen.dart
// (monolito). No incluye: el selector Hogar/Pro (aquí no existe "volver a
// modo propietario" -- esta app ya es solo Pro) ni la sección "Tu vivienda"
// (exclusiva de Hogar). Sí incluye: cuenta (eliminar/cerrar en todos los
// dispositivos, via el CuentaScreen compartido), perfil profesional
// editable, tema, preferencias de notificaciones y protección biométrica
// de documentos.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/profesional.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/theme_controller.dart';
import 'package:repara_ui/app_dialog.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/cuenta_screen.dart';
import 'package:repara_ui/ios_list.dart';
import 'package:repara_ui/notificaciones_preferencias_screen.dart';
import 'package:repara_ui/seccion_seguridad_documentos.dart';

class AjustesProScreen extends StatefulWidget {
  const AjustesProScreen({super.key});

  @override
  State<AjustesProScreen> createState() => _AjustesProScreenState();
}

class _AjustesProScreenState extends State<AjustesProScreen> {
  Future<void> _editarCampo(String titulo, String? actual, Future<void> Function(String) guardar) async {
    final valor = await AppDialog.promptText(context, title: titulo, initialValue: actual ?? '');
    if (valor == null) return;
    try {
      await guardar(valor);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo guardar.');
    }
  }

  void _abrirCuenta(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const CuentaScreen(
        eliminarCuentaMensaje:
            'Se borra tu perfil profesional y todos tus clientes y trabajos privados guardados en REPARA Pro. '
            'Si tienes una vivienda en REPARA Hogar con otros miembros, deberás salir de ella antes. '
            'Esta acción no se puede deshacer.',
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
            StreamBuilder<Profesional?>(
              stream: ProfesionalService.streamPerfilPropio(),
              builder: (context, snapshot) {
                final perfil = snapshot.data;
                return IosSection(
                  header: 'Tu perfil profesional',
                  rows: [
                    IosRow(
                      icon: Icons.badge_outlined,
                      iconColor: context.colors.brand,
                      title: perfil?.nombreComercial?.isNotEmpty == true ? perfil!.nombreComercial! : 'Nombre comercial',
                      subtitle: 'Toca para editar',
                      onTap: () => _editarCampo(
                        'Nombre comercial',
                        perfil?.nombreComercial,
                        (v) => ProfesionalService.actualizarPerfil(nombreComercial: v),
                      ),
                    ),
                    IosRow(
                      icon: Icons.category_outlined,
                      iconColor: context.colors.brand,
                      title: perfil?.especialidad?.isNotEmpty == true ? perfil!.especialidad! : 'Especialidad',
                      subtitle: 'Toca para editar',
                      onTap: () => _editarCampo(
                        'Especialidad',
                        perfil?.especialidad,
                        (v) => ProfesionalService.actualizarPerfil(especialidad: v),
                      ),
                    ),
                    IosRow(
                      icon: Icons.phone_outlined,
                      iconColor: context.colors.brand,
                      title: perfil?.telefono?.isNotEmpty == true ? perfil!.telefono! : 'Teléfono de contacto',
                      subtitle: 'Toca para editar',
                      onTap: () => _editarCampo(
                        'Teléfono',
                        perfil?.telefono,
                        (v) => ProfesionalService.actualizarPerfil(telefono: v),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: ReparaSpace.s4),
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
