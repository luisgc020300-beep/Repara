// lib/screens/settings_screen.dart
//
// Ajustes accesibles desde cualquier pestaña (icono de engranaje). Hub único
// de configuración (auditoría de producto, octubre 2026): antes "Perfil"
// (Hogar) y "Perfil profesional" (Pro) vivían como pestañas aparte,
// compitiendo con este mismo icono -- ahora todo vive aquí, con secciones
// que aparecen según desde dónde se abre (casa en Hogar, modoPro en Pro).
//
// Rediseño visual (CEO, noviembre 2026, a partir de un mockup de
// referencia): tarjetas grandes para "Tu cuenta" y "Tu vivienda", selector
// Hogar/Pro como interruptor de dos posiciones, y una lista plana de accesos
// (Tema, Seguridad, Compartir, Descargar PDF, Ayuda, Acerca de) -- cada uno
// de los cuales antes era una sección entera suelta aquí mismo. Nada de eso
// se perdió: cada fila de antes vive ahora en su propia pantalla
// (CuentaScreen, GestionarViviendaScreen, SeguridadScreen, AcercaScreen) o
// en el interruptor de modo. El icono de engranaje que abre esta pantalla
// desde las demás (BotonAjustes) no cambia.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/profesional.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/service_locator.dart';
import '../models/casa.dart';
import '../services/security/biometric_service.dart';
import '../services/security/security_preferences_service.dart';
import 'package:repara_core/design_tokens.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'acerca_screen.dart';
import 'cuenta_screen.dart';
import 'expediente_vivienda_screen.dart';
import 'gestionar_vivienda_screen.dart';
import 'notificaciones_preferencias_screen.dart';
import 'pro/repara_pro_shell_screen.dart';
import 'seguridad_screen.dart';

const _emailSoporte = 'luisgc020300@gmail.com';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.casa, this.modoPro = false, super.key});

  /// Si no es null, se muestra la tarjeta "Tu vivienda" y la fila
  /// "Descargar PDF".
  final Casa? casa;

  /// true cuando se abre desde dentro de Repara Pro -- el interruptor de
  /// modo aparece en "Pro" y se muestra "Tu perfil profesional".
  final bool modoPro;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _volverAModoPropietario() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _editarCampoProfesional(String titulo, String? actual, Future<void> Function(String) guardar) async {
    final valor = await AppDialog.promptText(context, title: titulo, initialValue: actual ?? '');
    if (valor == null) return;
    try {
      await guardar(valor);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo guardar.');
    }
  }

  Future<void> _abrirSelectorTema(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ReparaSpace.s4, ReparaSpace.s2, ReparaSpace.s4, ReparaSpace.s4),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _compartirApp(BuildContext context) async {
    try {
      await Share.share(
        'Llevo el mantenimiento de mi vivienda con REPARA: presupuestos, pagos y documentos de cada reparación, '
        'todo organizado en un sitio. Pregúntame si quieres probarla.',
      );
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (context.mounted) AppError.show(context, 'No se pudo abrir el selector para compartir.');
    }
  }

  Future<void> _abrirSoporte(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: _emailSoporte, query: 'subject=${Uri.encodeComponent('Ayuda con REPARA')}');
    try {
      final abierto = await launchUrl(uri);
      if (!abierto && context.mounted) AppError.show(context, 'No se pudo abrir el correo.');
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (context.mounted) AppError.show(context, 'No se pudo abrir el correo.');
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

            _cabecera(context, 'Modo de la app'),
            _ModoAppToggle(modoPro: widget.modoPro, onVolverAHogar: _volverAModoPropietario),

            if (widget.modoPro)
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
                        onTap: () => _editarCampoProfesional(
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
                        onTap: () => _editarCampoProfesional(
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
                        onTap: () => _editarCampoProfesional(
                          'Teléfono',
                          perfil?.telefono,
                          (v) => ProfesionalService.actualizarPerfil(telefono: v),
                        ),
                      ),
                    ],
                  );
                },
              ),

            IosSection(
              rows: [
                IosRow(
                  icon: Icons.palette_outlined,
                  iconColor: context.colors.brand,
                  title: 'Tema',
                  trailing: _valorConChevron(context, _temaLabel()),
                  onTap: () => _abrirSelectorTema(context),
                ),
                _FilaSeguridad(valorConChevron: _valorConChevron),
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
                  icon: Icons.ios_share_outlined,
                  iconColor: context.colors.brand,
                  title: 'Compartir REPARA',
                  onTap: () => _compartirApp(context),
                ),
                if (casa != null)
                  IosRow(
                    icon: Icons.download_outlined,
                    iconColor: context.colors.brand,
                    title: 'Descargar PDF',
                    subtitle: 'Dossier de la vivienda',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteViviendaScreen(casa: casa))),
                  ),
                IosRow(
                  icon: Icons.help_outline,
                  iconColor: context.colors.brand,
                  title: 'Ayuda y soporte',
                  onTap: () => _abrirSoporte(context),
                ),
                IosRow(
                  icon: Icons.info_outline,
                  iconColor: context.colors.brand,
                  title: 'Acerca de REPARA',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcercaScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _check(BuildContext context, bool seleccionado) =>
      seleccionado ? Icon(Icons.check, color: context.colors.brand, size: 20) : null;
}

Widget _cabecera(BuildContext context, String texto) => Padding(
  padding: const EdgeInsets.only(left: 6, bottom: 6),
  child: Text(texto.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.inkMuted)),
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
/// cuenta tiene una), nombre y correo.
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CuentaScreen())),
          child: Padding(
            padding: const EdgeInsets.all(ReparaSpace.s4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: context.colors.brandStrong,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null
                      ? Text(
                          _iniciales(user),
                          style: TextStyle(color: context.colors.brandOn, fontWeight: FontWeight.w700, fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: ReparaSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Tu cuenta',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: context.colors.ink),
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user!.email!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de entrada a [GestionarViviendaScreen].
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GestionarViviendaScreen(casa: casa))),
          child: Padding(
            padding: const EdgeInsets.all(ReparaSpace.s4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: context.colors.brandTint, borderRadius: BorderRadius.circular(ReparaRadius.sm)),
                  child: Icon(Icons.house_rounded, color: context.colors.brandStrong, size: 24),
                ),
                const SizedBox(width: ReparaSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        casa.nombre,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: context.colors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gestiona tu vivienda',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.inkMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interruptor Hogar/Pro (reemplaza la antigua sección "¿Trabajas como
/// profesional?" + "Modo profesional"): un solo toque activa el modo
/// profesional si hace falta y entra directo, respetando el gate biométrico
/// si está activado (ver SeguridadScreen).
class _ModoAppToggle extends StatefulWidget {
  const _ModoAppToggle({required this.modoPro, required this.onVolverAHogar});

  final bool modoPro;
  final VoidCallback onVolverAHogar;

  @override
  State<_ModoAppToggle> createState() => _ModoAppToggleState();
}

class _ModoAppToggleState extends State<_ModoAppToggle> {
  bool _procesando = false;

  Future<void> _entrarEnPro(bool esProfesionalYa) async {
    if (widget.modoPro || _procesando) return;
    setState(() => _procesando = true);
    try {
      if (!esProfesionalYa) {
        await ProfesionalService.activarModoProfesional();
        unawaited(AnalyticsService.setEsProfesional(true));
      }
      if (await SecurityPreferencesService.instance.isProGateEnabled()) {
        final verificado =
            await sl<BiometricService>().authenticate('Verifica tu identidad para entrar en Repara Pro') ==
            BiometricAuthResult.success;
        if (!verificado) return;
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReparaProShellScreen()));
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo activar el modo profesional.');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ProfesionalService.streamEsProfesional(),
      builder: (context, snapshot) {
        final esProfesional = snapshot.data ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: ReparaSpace.s5),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: BorderRadius.circular(ReparaRadius.sm)),
            child: Row(
              children: [
                Expanded(
                  child: _Segmento(
                    icon: Icons.home_outlined,
                    label: 'Hogar',
                    selected: !widget.modoPro,
                    onTap: widget.modoPro ? widget.onVolverAHogar : null,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _Segmento(
                    icon: Icons.work_outline,
                    label: 'Pro',
                    selected: widget.modoPro,
                    loading: _procesando,
                    onTap: widget.modoPro ? null : () => _entrarEnPro(esProfesional),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({required this.icon, required this.label, required this.selected, this.onTap, this.loading = false});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.brandStrong : context.colors.inkMuted;
    // Semantics propio con container:true (auditoría visual/accesibilidad,
    // noviembre 2026): sin esto, los dos segmentos vecinos de este
    // interruptor (Hogar/Pro) se fusionaban en un único nodo de
    // accesibilidad "Hogar Pro" -- un lector de pantalla no podía
    // distinguirlos ni saber cuál estaba activo. excludeSemantics en el
    // contenido visual evita que el icono/texto internos vuelvan a
    // filtrarse como nodos sueltos.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? context.colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(ReparaRadius.xs),
        elevation: selected ? 1 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(ReparaRadius.xs),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: ExcludeSemantics(
              child: loading
                  ? SizedBox(
                      height: 18,
                      child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 6),
                        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila "Seguridad" de la lista plana -- resume con una palabra si hay algún
/// bloqueo activado y navega a [SeguridadScreen] para el detalle/los switches.
class _FilaSeguridad extends StatefulWidget {
  const _FilaSeguridad({required this.valorConChevron});

  final Widget Function(BuildContext, String) valorConChevron;

  @override
  State<_FilaSeguridad> createState() => _FilaSeguridadState();
}

class _FilaSeguridadState extends State<_FilaSeguridad> {
  bool _cargando = true;
  bool _activado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final documentos = await SecurityPreferencesService.instance.isDocumentProtectionEnabled();
    final pro = await SecurityPreferencesService.instance.isProGateEnabled();
    if (!mounted) return;
    setState(() {
      _activado = documentos || pro;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IosRow(
      icon: Icons.lock_outline,
      iconColor: context.colors.brand,
      title: 'Seguridad',
      trailing: _cargando ? null : widget.valorConChevron(context, _activado ? 'Bloqueo activado' : 'Desactivado'),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SeguridadScreen())),
    );
  }
}
