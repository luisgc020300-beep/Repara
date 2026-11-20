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
import 'package:repara_core/especialidad_profesional.dart';
import 'package:repara_core/location_service.dart';
import 'package:repara_core/profesional.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/theme_controller.dart';
import 'package:repara_ui/app_dialog.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/cuenta_screen.dart';
import 'package:repara_ui/editor_foto_perfil.dart';
import 'package:repara_ui/ios_list.dart';
import 'package:repara_ui/notificaciones_preferencias_screen.dart';
import 'package:repara_ui/seccion_seguridad_documentos.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'acerca_pro_screen.dart';
import 'mis_valoraciones_screen.dart';

// Mismo canal de contacto ya usado en Hogar/monolito
// (ajustes_hogar_screen.dart / settings_screen.dart) -- nunca se inventa
// una dirección ni un servicio nuevo.
const _emailSoporte = 'luisgc020300@gmail.com';

// "Mi reputación" e "Invita a un cliente a Repara" vivían en los Accesos
// rápidos de Inicio -- el CEO pidió moverlos aquí (noviembre 2026): la
// reputación como una fila más de "Tu perfil profesional" (es un dato del
// perfil, no una acción del día a día) y la invitación como su propia
// sección independiente, para que Inicio se quede solo con lo operativo.
const _mensajeInvitarCliente =
    'Llevo el mantenimiento de tus trabajos con Repara -- así queda todo el historial, '
    'presupuestos y fotos organizados en un solo sitio, no perdido entre WhatsApps. '
    'Créate una cuenta gratis y así te puedo mandar presupuestos y avisarte de cambios directamente ahí.';

class AjustesProScreen extends StatefulWidget {
  const AjustesProScreen({super.key});

  @override
  State<AjustesProScreen> createState() => _AjustesProScreenState();
}

class _AjustesProScreenState extends State<AjustesProScreen> {
  Future<void> _abrirSoporte(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _emailSoporte,
      query: 'subject=${Uri.encodeComponent('Ayuda con REPARA Pro')}',
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

  Future<void> _guardarCampo(Future<void> Function() guardar) async {
    try {
      await guardar();
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo guardar.');
    }
  }

  Future<void> _editarCampo(
    String titulo,
    String? actual,
    Future<void> Function(String) guardar, {
    int? minLines,
    int? maxLines,
  }) async {
    final valor = await AppDialog.promptText(
      context,
      title: titulo,
      initialValue: actual ?? '',
      minLines: minLines,
      maxLines: maxLines,
    );
    if (valor == null) return;
    await _guardarCampo(() => guardar(valor));
  }

  /// Especialidad (organizar las especialidades profesionales, noviembre
  /// 2026): selector con una lista cerrada en vez de solo texto libre --
  /// "Otro" sigue abriendo el mismo diálogo de texto de siempre, así que
  /// cualquier profesional que ya tuviera guardado algo fuera de la lista
  /// puede seguir escribiéndolo igual, sin perder nada.
  Future<void> _abrirSelectorEspecialidad(
    BuildContext context,
    String? actual,
  ) {
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
          child: SingleChildScrollView(
            child: IosSection(
              rows: [
                for (final e in especialidadesProfesionales)
                  IosRow(
                    icon: Icons.category_outlined,
                    iconColor: context.colors.brand,
                    title: e,
                    selected: actual == e,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (e == especialidadProfesionalOtra) {
                        _editarCampo(
                          'Especialidad',
                          actual,
                          (v) =>
                              ProfesionalService.actualizarPerfil(especialidad: v),
                        );
                      } else {
                        _guardarCampo(
                          () => ProfesionalService.actualizarPerfil(
                            especialidad: e,
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Foto del perfil profesional (mejora de perfiles, noviembre 2026) --
  /// distinta de la foto personal de CuentaScreen (FirebaseAuth.photoURL):
  /// esta es la que ve el propietario en perfil_profesional_screen.dart/
  /// Cercanos, así que vive en profesionales/{uid}.fotoUrl, sincronizada a
  /// profesionalesPublico por la Cloud Function correspondiente.
  Future<void> _cambiarFotoProfesional(String? fotoActual) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await editarFotoPerfil(
      context,
      storagePath: 'profesionales/$uid/foto',
      tieneFotoActual: fotoActual != null,
      onGuardar: ProfesionalService.actualizarFoto,
    );
  }

  void _abrirCuenta(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const CuentaScreen(
        eliminarCuentaMensaje:
            'Se borra tu perfil profesional y todos tus clientes y trabajos privados guardados en REPARA Pro. '
            'Si tienes una vivienda en REPARA Hogar con otros miembros, deberás salir de ella antes. '
            'Esta acción no se puede deshacer.',
        // false porque "Cerrar sesión" ya está en el menú principal de
        // Ajustes (mismo motivo que en Hogar) -- evita la fila duplicada.
        mostrarCerrarSesion: false,
      ),
    ),
  );

  // Cercanos (noviembre 2026): activar pide permiso de ubicación y manda
  // una posición aproximada (ver ProfesionalService.actualizarVisibilidadCercana
  // -- solo COARSE, nunca coordenadas exactas). Desactivar nunca necesita
  // permiso, se manda directo.
  Future<void> _alternarVisibleCercano(bool activar) async {
    if (!activar) {
      await ProfesionalService.actualizarVisibilidadCercana(visible: false);
      return;
    }
    final permiso = await DeviceLocation.instance.solicitarPermiso();
    if (!mounted) return;
    if (permiso != SolicitudUbicacionResultado.concedido) {
      AppError.show(
        context,
        permiso == SolicitudUbicacionResultado.servicioDesactivado
            ? 'Activa la ubicación de tu dispositivo para hacerte visible en Cercanos.'
            : 'Necesitamos permiso de ubicación para hacerte visible en Cercanos.',
      );
      return;
    }
    final posicion = await DeviceLocation.instance.posicionActual();
    if (!mounted) return;
    if (posicion == null) {
      AppError.show(context, 'No se pudo obtener tu ubicación. Inténtalo de nuevo.');
      return;
    }
    try {
      await ProfesionalService.actualizarVisibilidadCercana(
        visible: true,
        lat: posicion.lat,
        lng: posicion.lng,
      );
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo activar Cercanos.');
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
      Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.inkMuted)),
      const SizedBox(width: 2),
      Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
    ],
  );

  // Igual criterio que Hogar (ajustes_hogar_screen.dart): marca de
  // verificación junto al modo activo, no solo el resaltado de `selected`
  // -- coherencia de personalización de tema entre las dos apps (punto 9,
  // noviembre 2026).
  Widget? _check(BuildContext context, bool seleccionado) => seleccionado
      ? Icon(Icons.check, color: context.colors.brand, size: 20)
      : null;

  Future<void> _abrirSelectorApariencia(BuildContext context) {
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
                  trailing: _check(context, ThemeController.instance.mode == ThemeMode.light),
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
                  trailing: _check(context, ThemeController.instance.mode == ThemeMode.dark),
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
                  trailing: _check(context, ThemeController.instance.mode == ThemeMode.system),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto del perfil público -- toca para cambiarla/
                    // eliminarla (mejora de perfiles, noviembre 2026).
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _cambiarFotoProfesional(perfil?.fotoUrl),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: context.colors.brandTint,
                            backgroundImage: perfil?.fotoUrl != null
                                ? NetworkImage(perfil!.fotoUrl!)
                                : null,
                            child: perfil?.fotoUrl == null
                                ? Icon(
                                    Icons.add_a_photo_outlined,
                                    color: context.colors.brand,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ReparaSpace.s3),
                    IosSection(
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
                          subtitle: 'Toca para elegir',
                          onTap: () => _abrirSelectorEspecialidad(
                            context,
                            perfil?.especialidad,
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
                        IosRow(
                          icon: Icons.notes_outlined,
                          iconColor: context.colors.brand,
                          title: perfil?.descripcion?.isNotEmpty == true ? perfil!.descripcion! : 'Descripción',
                          subtitle: 'Toca para editar',
                          dense: perfil?.descripcion?.isNotEmpty == true,
                          onTap: () => _editarCampo(
                            'Descripción',
                            perfil?.descripcion,
                            (v) => ProfesionalService.actualizarPerfil(descripcion: v),
                            minLines: 3,
                            maxLines: 6,
                          ),
                        ),
                        IosRow(
                          icon: Icons.star_outline_rounded,
                          iconColor: context.colors.brand,
                          title: 'Mi reputación',
                          subtitle: 'Nota media, valoraciones y comentarios recibidos',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MisValoracionesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: ReparaSpace.s4),
            IosSection(
              header: 'Invita a tus clientes',
              rows: [
                IosRow(
                  icon: Icons.person_add_alt_outlined,
                  iconColor: context.colors.brand,
                  title: 'Invita a un cliente a Repara',
                  subtitle:
                      'Para que puedas mandarle presupuestos y avisos desde aquí',
                  trailing: Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: context.colors.inkMuted,
                  ),
                  showChevron: false,
                  // sharePositionOrigin obligatorio en iOS -- ver nota en
                  // contacto_acciones.dart.
                  onTap: () => Share.share(
                    _mensajeInvitarCliente,
                    sharePositionOrigin:
                        Offset.zero & MediaQuery.of(context).size,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            StreamBuilder<Profesional?>(
              stream: ProfesionalService.streamPerfilPropio(),
              builder: (context, snapshot) {
                final visible = snapshot.data?.visibleCercano ?? false;
                return IosSection(
                  header: 'Cercanos',
                  footer:
                      'Si lo activas, los propietarios podrán encontrarte en "Cercanos" cuando no tengan disponible a ninguno de sus profesionales habituales. Nunca compartimos tu ubicación exacta, solo una distancia aproximada.',
                  rows: [
                    IosRow(
                      icon: Icons.near_me_outlined,
                      iconColor: context.colors.brand,
                      title: 'Visible cerca de ti',
                      subtitle: visible ? 'Activado' : 'Desactivado',
                      showChevron: false,
                      trailing: Switch(
                        value: visible,
                        onChanged: _alternarVisibleCercano,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: ReparaSpace.s4),
            // Mismo header+fila que Hogar ("Tema" / "Apariencia") -- antes
            // esta fila se llamaba "Tema" aquí pero "Apariencia" en Hogar
            // para el mismo ajuste (punto 9, noviembre 2026: coherencia de
            // personalización entre las dos apps).
            IosSection(
              header: 'Tema',
              rows: [
                IosRow(
                  icon: Icons.palette_outlined,
                  iconColor: context.colors.brand,
                  title: 'Apariencia',
                  trailing: _valorConChevron(context, _temaLabel()),
                  onTap: () => _abrirSelectorApariencia(context),
                ),
              ],
            ),
            const SizedBox(height: ReparaSpace.s4),
            const SeccionSeguridadDocumentos(),
            const SizedBox(height: ReparaSpace.s4),
            IosSection(
              header: 'Acerca de la app',
              rows: [
                IosRow(
                  icon: Icons.notifications_outlined,
                  iconColor: context.colors.brand,
                  title: 'Notificaciones',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificacionesPreferenciasScreen()),
                  ),
                ),
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
                    MaterialPageRoute(builder: (_) => const AcercaProScreen()),
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
                  onTap: () => confirmarYCerrarSesion(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
