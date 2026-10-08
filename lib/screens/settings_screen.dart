// lib/screens/settings_screen.dart
//
// Ajustes accesibles desde cualquier pestaña (icono de engranaje). Hub único
// de configuración (auditoría de producto, octubre 2026): antes "Perfil"
// (Hogar) y "Perfil profesional" (Pro) vivían como pestañas aparte,
// compitiendo con este mismo icono -- ahora todo vive aquí, con secciones
// que aparecen según desde dónde se abre (casa en Hogar, modoPro en Pro).
//
// Estilo "lista agrupada" de iOS (a petición del CEO, octubre 2026): secciones
// con cabecera en mayúsculas, filas dentro de una única tarjeta redondeada
// con separadores finos e indentados, icono en una insignia de color y
// chevron a la derecha -- en vez de una Card suelta por fila.
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/casa.dart';
import '../models/profesional.dart';
import '../services/analytics_service.dart';
import '../services/casa_service.dart';
import '../services/cuenta_service.dart';
import '../services/fcm_service.dart';
import '../core/service_locator.dart';
import '../services/invitacion_service.dart';
import '../services/profesional_service.dart';
import '../services/security/app_lock_controller.dart';
import '../services/security/biometric_service.dart';
import '../services/security/security_preferences_service.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'documentos_casa_screen.dart';
import 'expediente_vivienda_screen.dart';
import 'pro/repara_pro_shell_screen.dart';

// URL única con dos secciones (#privacidad / #terminos) -- más fácil de
// mantener que dos páginas separadas mientras la app es de un único
// desarrollador. OJO: compartir el enlace desde el menú de la propia página
// antes de publicar la app en las tiendas, o nadie fuera de esta cuenta
// podrá abrirlo.
const _urlLegal = 'https://claude.ai/artifact/G771r2pFWuiAFRXxHA69rC';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.casa, this.modoPro = false, super.key});

  /// Si no es null, se muestra la sección "Tu casa" (renombrar, miembros,
  /// código, documentos, activar modo profesional).
  final Casa? casa;

  /// true cuando se abre desde dentro de Repara Pro -- muestra "Tu perfil
  /// profesional" y "Volver a modo propietario" en vez de la sección de casa.
  final bool modoPro;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _eliminandoCuenta = false;
  bool _cerrandoTodo = false;

  Future<void> _confirmarCerrarSesionEnTodosLosDispositivos() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión en todos los dispositivos?'),
        content: const Text(
          'Este dispositivo se cierra al momento. Los demás seguirán abiertos hasta una hora más mientras se '
          'renueva su sesión automáticamente -- no es instantáneo en ellos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar en todos')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _cerrandoTodo = true);
    try {
      await CuentaService.cerrarSesionesEnTodosLosDispositivos();
      await FcmService.olvidarEsteDispositivo();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo cerrar la sesión en todos los dispositivos.');
    } finally {
      if (mounted) setState(() => _cerrandoTodo = false);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmar != true) return;
    await FcmService.olvidarEsteDispositivo();
    await FirebaseAuth.instance.signOut();
    // El StreamBuilder de MaterialApp ya muestra LoginScreen por debajo en
    // cuanto cambia la sesión, pero esta pantalla (y todo lo que haya encima,
    // p.ej. el shell de Pro) sigue empujado en la pila -- hay que volver a
    // la raíz para que se vea.
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmarEliminarCuenta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Se borra tu perfil y, si eres el único miembro de tu vivienda, también la vivienda entera con su '
          'historial, documentos y fotos. Si la compartes con alguien más, solo se elimina tu vinculación a ella. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _eliminandoCuenta = true);
    try {
      await CuentaService.eliminarCuenta();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseFunctionsException catch (e, st) {
      if (e.code != 'failed-precondition') {
        await FirebaseCrashlytics.instance.recordError(e, st);
      }
      if (mounted) AppError.show(context, e.message ?? 'No se pudo eliminar la cuenta.');
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo eliminar la cuenta. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _eliminandoCuenta = false);
    }
  }

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

  void _volverAModoPropietario() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _renombrarCasa(Casa casa) async {
    final ctrl = TextEditingController(text: casa.nombre);
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la casa'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty || nombre == casa.nombre) return;
    try {
      await CasaService.renombrarCasa(casa.id, nombre);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo renombrar la casa.');
    }
  }

  Future<void> _canjearCodigoTrabajo() async {
    final ctrl = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de invitación'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Ej. AB12CD'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Canjear')),
        ],
      ),
    );
    if (codigo == null || codigo.isEmpty || !mounted) return;
    try {
      final resultado = await InvitacionService.canjearCodigo(codigo);
      if (mounted) {
        AppError.showSuccess(
          context,
          'Vinculado a "${resultado.trabajoTitulo}" en ${resultado.casaNombre}. Acéptalo desde Inicio Pro.',
        );
      }
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'Ese código no es válido o ya se ha usado.');
    }
  }

  Future<void> _editarCampoProfesional(String titulo, String? actual, Future<void> Function(String) guardar) async {
    final ctrl = TextEditingController(text: actual ?? '');
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (valor == null) return;
    try {
      await guardar(valor);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo guardar.');
    }
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
            IosSection(
              header: 'Apariencia',
              rows: [
                IosRow(
                  icon: Icons.light_mode_outlined,
                  iconColor: Colors.orange,
                  title: 'Claro',
                  trailing: _check(context, ThemeController.instance.mode == ThemeMode.light),
                  onTap: () => ThemeController.instance.setMode(ThemeMode.light),
                ),
                IosRow(
                  icon: Icons.dark_mode_outlined,
                  iconColor: Colors.indigo,
                  title: 'Oscuro',
                  trailing: _check(context, ThemeController.instance.mode == ThemeMode.dark),
                  onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
                ),
                IosRow(
                  icon: Icons.smartphone_outlined,
                  iconColor: Colors.blueGrey,
                  title: 'Igual que el sistema',
                  trailing: _check(context, ThemeController.instance.mode == ThemeMode.system),
                  onTap: () => ThemeController.instance.setMode(ThemeMode.system),
                ),
              ],
            ),

            const _SeccionSeguridad(),

            if (casa != null) ...[
              IosSection(
                header: 'Tu casa',
                rows: [
                  IosRow(
                    icon: Icons.house_outlined,
                    iconColor: context.colors.brand,
                    title: casa.nombre,
                    subtitle: 'Toca para cambiar el nombre',
                    onTap: () => _renombrarCasa(casa),
                  ),
                  IosRow(
                    icon: Icons.folder_open_outlined,
                    iconColor: Colors.blue,
                    title: 'Documentos',
                    subtitle: 'Facturas, presupuestos y garantías guardados',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentosCasaScreen(casa: casa))),
                  ),
                  IosRow(
                    icon: Icons.summarize_outlined,
                    iconColor: Colors.orange,
                    title: 'Expediente de la vivienda',
                    subtitle: 'Para vender, asegurar o pedir financiación',
                    onTap: () {
                      unawaited(AnalyticsService.householdRecordViewed());
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteViviendaScreen(casa: casa)));
                    },
                  ),
                  IosRow(
                    icon: Icons.group_outlined,
                    iconColor: Colors.teal,
                    title: 'Miembros de esta casa',
                    subtitle: casa.memberProfiles.values.map((m) => m.displayName).join(', '),
                  ),
                  if (casa.joinCode != null)
                    IosRow(
                      icon: Icons.key_outlined,
                      iconColor: Colors.purple,
                      title: 'Código para invitar a alguien',
                      subtitle: casa.joinCode!,
                    ),
                ],
              ),
              _SeccionProfesional(),
              IosSection(
                rows: [
                  IosRow(
                    icon: Icons.confirmation_number_outlined,
                    iconColor: Colors.brown,
                    title: '¿Tienes un código de invitación?',
                    subtitle: 'Un cliente te lo habrá pasado para un trabajo suyo',
                    onTap: _canjearCodigoTrabajo,
                  ),
                ],
              ),
            ],

            if (widget.modoPro) ...[
              StreamBuilder<Profesional?>(
                stream: ProfesionalService.streamPerfilPropio(),
                builder: (context, snapshot) {
                  final perfil = snapshot.data;
                  return IosSection(
                    header: 'Tu perfil profesional',
                    rows: [
                      IosRow(
                        icon: Icons.badge_outlined,
                        iconColor: Colors.blue,
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
                        iconColor: Colors.purple,
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
                        iconColor: Colors.green,
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
                    icon: Icons.home_outlined,
                    iconColor: context.colors.brand,
                    title: 'Volver a modo propietario',
                    onTap: _volverAModoPropietario,
                  ),
                ],
              ),
            ],

            IosSection(
              header: 'Legal',
              rows: [
                IosRow(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: Colors.blueGrey,
                  title: 'Política de privacidad',
                  onTap: () => _abrirLegal('privacidad'),
                ),
                IosRow(
                  icon: Icons.description_outlined,
                  iconColor: Colors.blueGrey,
                  title: 'Términos de servicio',
                  onTap: () => _abrirLegal('terminos'),
                ),
              ],
            ),

            IosSection(
              rows: [
                IosRow(
                  icon: Icons.logout_outlined,
                  iconColor: context.colors.error,
                  title: 'Cerrar sesión',
                  titleColor: context.colors.error,
                  showChevron: false,
                  onTap: _confirmarCerrarSesion,
                ),
                IosRow(
                  icon: Icons.devices_outlined,
                  iconColor: context.colors.error,
                  title: 'Cerrar sesión en todos los dispositivos',
                  titleColor: context.colors.error,
                  showChevron: false,
                  trailing: _cerrandoTodo
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.error),
                        )
                      : null,
                  onTap: _cerrandoTodo ? null : _confirmarCerrarSesionEnTodosLosDispositivos,
                ),
              ],
            ),
            IosSection(
              rows: [
                IosRow(
                  icon: Icons.delete_outline,
                  iconColor: context.colors.error,
                  title: 'Eliminar cuenta',
                  titleColor: context.colors.error,
                  showChevron: false,
                  trailing: _eliminandoCuenta
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.error),
                        )
                      : null,
                  onTap: _eliminandoCuenta ? null : _confirmarEliminarCuenta,
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

/// Ajustes de seguridad local (Fase D de la misión de endurecimiento,
/// octubre 2026). Puramente local: nunca sustituye a Firebase Auth/reglas,
/// solo decide si AppLockController pide biometría (ver app_lock_controller.dart).
class _SeccionSeguridad extends StatefulWidget {
  const _SeccionSeguridad();

  @override
  State<_SeccionSeguridad> createState() => _SeccionSeguridadState();
}

class _SeccionSeguridadState extends State<_SeccionSeguridad> {
  bool _cargando = true;
  bool _biometriaDisponible = false;
  bool _activado = false;
  bool _documentosProtegidos = false;
  bool _proProtegido = false;
  LockTimeout _timeout = LockTimeout.fiveMinutes;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final biometria = sl<BiometricService>();
    final disponible = await biometria.isAvailable();
    final activado = await SecurityPreferencesService.instance.isBiometricLockEnabled();
    final timeout = await SecurityPreferencesService.instance.getLockTimeout();
    final documentosProtegidos = await SecurityPreferencesService.instance.isDocumentProtectionEnabled();
    final proProtegido = await SecurityPreferencesService.instance.isProGateEnabled();
    if (!mounted) return;
    setState(() {
      _biometriaDisponible = disponible;
      _activado = activado;
      _timeout = timeout;
      _documentosProtegidos = documentosProtegidos;
      _proProtegido = proProtegido;
      _cargando = false;
    });
  }

  Future<void> _cambiarActivado(bool valor) async {
    setState(() => _activado = valor);
    await SecurityPreferencesService.instance.setBiometricLockEnabled(valor);
    await AppLockController.instance.refrescarAjustes();
  }

  Future<void> _cambiarProProtegido(bool valor) async {
    setState(() => _proProtegido = valor);
    await SecurityPreferencesService.instance.setProGateEnabled(valor);
  }

  Future<void> _cambiarDocumentosProtegidos(bool valor) async {
    setState(() => _documentosProtegidos = valor);
    await SecurityPreferencesService.instance.setDocumentProtectionEnabled(valor);
  }

  Future<void> _elegirTimeout() async {
    final elegido = await showDialog<LockTimeout>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear tras'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opcion in LockTimeout.values)
              ListTile(
                title: Text(opcion.etiqueta),
                trailing: opcion == _timeout ? Icon(Icons.check, color: context.colors.brand) : null,
                onTap: () => Navigator.pop(ctx, opcion),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar'))],
      ),
    );
    if (elegido == null || elegido == _timeout) return;
    setState(() => _timeout = elegido);
    await SecurityPreferencesService.instance.setLockTimeout(elegido);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    return IosSection(
      header: 'Seguridad',
      footer: !_biometriaDisponible
          ? 'Este dispositivo no tiene biometría configurada (Face ID, huella) o la app no tiene permiso para usarla.'
          : null,
      rows: [
        IosRow(
          icon: Icons.fingerprint,
          iconColor: context.colors.brand,
          title: 'Bloqueo biométrico',
          subtitle: _biometriaDisponible ? 'Pide Face ID/huella al volver a abrir Repara' : 'No disponible en este dispositivo',
          showChevron: false,
          trailing: Switch(
            value: _activado && _biometriaDisponible,
            onChanged: _biometriaDisponible ? _cambiarActivado : null,
          ),
        ),
        if (_activado && _biometriaDisponible)
          IosRow(
            icon: Icons.timer_outlined,
            iconColor: Colors.blueGrey,
            title: 'Bloquear tras',
            subtitle: _timeout.etiqueta,
            onTap: _elegirTimeout,
          ),
        IosRow(
          icon: Icons.folder_shared_outlined,
          iconColor: Colors.deepOrange,
          title: 'Proteger documentos sensibles',
          subtitle: _biometriaDisponible
              ? 'Pide Face ID/huella antes de abrir una factura o garantía'
              : 'No disponible en este dispositivo',
          showChevron: false,
          trailing: Switch(
            value: _documentosProtegidos && _biometriaDisponible,
            onChanged: _biometriaDisponible ? _cambiarDocumentosProtegidos : null,
          ),
        ),
        IosRow(
          icon: Icons.engineering_outlined,
          iconColor: Colors.indigo,
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

/// Autoservicio de rol (sección 5 del spec: una persona puede tener varios
/// roles). Activar el modo profesional no cambia nada de Repara Hogar --
/// solo añade un acceso nuevo a Repara Pro desde aquí mismo.
class _SeccionProfesional extends StatefulWidget {
  @override
  State<_SeccionProfesional> createState() => _SeccionProfesionalState();
}

class _SeccionProfesionalState extends State<_SeccionProfesional> {
  bool _activando = false;

  Future<void> _entrarEnModoPro() async {
    if (await SecurityPreferencesService.instance.isProGateEnabled()) {
      final verificado =
          await sl<BiometricService>().authenticate('Verifica tu identidad para entrar en Repara Pro') ==
              BiometricAuthResult.success;
      if (!verificado) return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReparaProShellScreen()));
  }

  Future<void> _activar() async {
    setState(() => _activando = true);
    try {
      await ProfesionalService.activarModoProfesional();
      unawaited(AnalyticsService.setEsProfesional(true));
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo activar el modo profesional.');
    } finally {
      if (mounted) setState(() => _activando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ProfesionalService.streamEsProfesional(),
      builder: (context, snapshot) {
        final esProfesional = snapshot.data ?? false;
        if (!esProfesional) {
          return IosSection(
            rows: [
              IosRow(
                icon: Icons.engineering_outlined,
                iconColor: context.colors.brand,
                title: '¿Trabajas como profesional?',
                subtitle: 'Activa el modo profesional para gestionar trabajos que te inviten',
                showChevron: false,
                trailing: _activando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: _activar, child: const Text('Activar')),
              ),
            ],
          );
        }
        return IosSection(
          rows: [
            IosRow(
              icon: Icons.engineering_outlined,
              iconColor: context.colors.brand,
              title: 'Modo profesional',
              subtitle: 'Ver tus trabajos, clientes y presupuestos',
              onTap: _entrarEnModoPro,
            ),
          ],
        );
      },
    );
  }
}

