// lib/screens/settings_screen.dart
//
// Ajustes accesibles desde cualquier pestaña (icono de engranaje). Hub único
// de configuración (auditoría de producto, octubre 2026): antes "Perfil"
// (Hogar) y "Perfil profesional" (Pro) vivían como pestañas aparte,
// compitiendo con este mismo icono -- ahora todo vive aquí, con secciones
// que aparecen según desde dónde se abre (casa en Hogar, modoPro en Pro).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/profesional.dart';
import '../services/analytics_service.dart';
import '../services/casa_service.dart';
import '../services/fcm_service.dart';
import '../services/invitacion_service.dart';
import '../services/profesional_service.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_error.dart';
import 'documentos_casa_screen.dart';
import 'expediente_vivienda_screen.dart';
import 'pro/repara_pro_shell_screen.dart';

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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo guardar.');
    }
  }

  Widget _seccion(BuildContext context, String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 24),
        child: Text(titulo, style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: context.colors.inkMuted)),
      );

  @override
  Widget build(BuildContext context) {
    final casa = widget.casa;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Apariencia', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: context.colors.inkMuted)),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<ThemeMode>(
                groupValue: ThemeController.instance.mode,
                onChanged: (m) => ThemeController.instance.setMode(m!),
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(value: ThemeMode.light, title: Text('Claro'), secondary: Icon(Icons.light_mode_outlined)),
                    Divider(height: 1),
                    RadioListTile<ThemeMode>(value: ThemeMode.dark, title: Text('Oscuro'), secondary: Icon(Icons.dark_mode_outlined)),
                    Divider(height: 1),
                    RadioListTile<ThemeMode>(value: ThemeMode.system, title: Text('Igual que el sistema'), secondary: Icon(Icons.smartphone_outlined)),
                  ],
                ),
              ),
            ),

            if (casa != null) ...[
              _seccion(context, 'Tu casa'),
              Card(
                child: ListTile(
                  leading: Icon(Icons.house_outlined, color: context.colors.brand),
                  title: Text(casa.nombre),
                  subtitle: const Text('Toca para cambiar el nombre'),
                  onTap: () => _renombrarCasa(casa),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.folder_open_outlined, color: context.colors.brand),
                  title: const Text('Documentos'),
                  subtitle: const Text('Facturas, presupuestos y garantías guardados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentosCasaScreen(casa: casa))),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.summarize_outlined, color: context.colors.brand),
                  title: const Text('Expediente de la vivienda'),
                  subtitle: const Text('Resumen de elementos, trabajos y garantías -- para vender, asegurar o pedir financiación'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    unawaited(AnalyticsService.householdRecordViewed());
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteViviendaScreen(casa: casa)));
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Miembros de esta casa'),
                  subtitle: Text(casa.memberProfiles.values.map((m) => m.displayName).join(', ')),
                ),
              ),
              if (casa.joinCode != null) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Código para invitar a alguien'),
                    subtitle: Text(casa.joinCode!, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _SeccionProfesional(),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: const Text('¿Tienes un código de invitación?'),
                  subtitle: const Text('Un cliente te lo habrá pasado para un trabajo suyo'),
                  onTap: _canjearCodigoTrabajo,
                ),
              ),
            ],

            if (widget.modoPro) ...[
              _seccion(context, 'Tu perfil profesional'),
              StreamBuilder<Profesional?>(
                stream: ProfesionalService.streamPerfilPropio(),
                builder: (context, snapshot) {
                  final perfil = snapshot.data;
                  return Column(
                    children: [
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.badge_outlined, color: context.colors.brand),
                          title: Text(perfil?.nombreComercial?.isNotEmpty == true ? perfil!.nombreComercial! : 'Nombre comercial'),
                          subtitle: const Text('Toca para editar'),
                          onTap: () => _editarCampoProfesional(
                            'Nombre comercial',
                            perfil?.nombreComercial,
                            (v) => ProfesionalService.actualizarPerfil(nombreComercial: v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.category_outlined),
                          title: Text(perfil?.especialidad?.isNotEmpty == true ? perfil!.especialidad! : 'Especialidad'),
                          subtitle: const Text('Toca para editar'),
                          onTap: () => _editarCampoProfesional(
                            'Especialidad',
                            perfil?.especialidad,
                            (v) => ProfesionalService.actualizarPerfil(especialidad: v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.phone_outlined),
                          title: Text(perfil?.telefono?.isNotEmpty == true ? perfil!.telefono! : 'Teléfono de contacto'),
                          subtitle: const Text('Toca para editar'),
                          onTap: () => _editarCampoProfesional(
                            'Teléfono',
                            perfil?.telefono,
                            (v) => ProfesionalService.actualizarPerfil(telefono: v),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _volverAModoPropietario,
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver a modo propietario'),
              ),
            ],

            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout_outlined, color: context.colors.error),
                title: Text('Cerrar sesión', style: TextStyle(color: context.colors.error, fontWeight: FontWeight.w600)),
                onTap: _confirmarCerrarSesion,
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _activar() async {
    setState(() => _activando = true);
    try {
      await ProfesionalService.activarModoProfesional();
      unawaited(AnalyticsService.setEsProfesional(true));
    } catch (e) {
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
          return Card(
            child: ListTile(
              leading: Icon(Icons.engineering_outlined, color: context.colors.brand),
              title: const Text('¿Trabajas como profesional?'),
              subtitle: const Text('Activa el modo profesional para gestionar trabajos que te inviten'),
              trailing: _activando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: _activar, child: const Text('Activar')),
            ),
          );
        }
        return Card(
          child: ListTile(
            leading: Icon(Icons.engineering_outlined, color: context.colors.brand),
            title: const Text('Modo profesional'),
            subtitle: const Text('Ver tus trabajos, clientes y presupuestos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReparaProShellScreen())),
          ),
        );
      },
    );
  }
}
