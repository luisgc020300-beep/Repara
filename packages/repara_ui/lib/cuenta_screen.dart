// lib/cuenta_screen.dart
//
// "Tu cuenta": identidad + las tres acciones de sesión/cuenta (Cerrar
// sesión, Cerrar en todos los dispositivos, Eliminar cuenta). Movido del
// monolito a repara_ui en noviembre 2026 para que Hogar y Pro lo reutilicen
// sin duplicar la lógica -- solo dos cosas varían por app, inyectadas por
// quien instancia la pantalla:
//  - [eliminarCuentaMensaje]: qué se pierde exactamente al eliminar la
//    cuenta (en Hogar menciona la vivienda; en Pro, el perfil profesional).
//  - [antesDeCerrarSesion]: limpieza previa a signOut() exclusiva de cada
//    app (p.ej. FcmService.olvidarEsteDispositivo() en Hogar) -- opcional,
//    Pro no tiene hoy nada que limpiar aquí (sin FCM conectado todavía).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/cuenta_service.dart';

import 'package:repara_core/design_tokens.dart';
import 'app_dialog.dart';
import 'app_error.dart';
import 'editor_foto_perfil.dart';
import 'ios_list.dart';

/// Cierra sesión con la misma confirmación que ya usaba esta pantalla --
/// reutilizada también desde el menú principal de Ajustes (noviembre 2026,
/// rediseño de Ajustes) para que "Cerrar sesión" esté accesible sin tener
/// que entrar primero en "Tu cuenta". Mismo diálogo, mismo signOut(), misma
/// limpieza previa opcional -- ningún cambio de comportamiento, solo un
/// único sitio del que depender.
Future<void> confirmarYCerrarSesion(
  BuildContext context, {
  Future<void> Function()? antesDeCerrarSesion,
}) async {
  final confirmar = await AppDialog.confirm(
    context,
    title: '¿Cerrar sesión?',
    confirmLabel: 'Cerrar sesión',
  );
  if (!confirmar) return;
  await antesDeCerrarSesion?.call();
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class CuentaScreen extends StatefulWidget {
  const CuentaScreen({
    required this.eliminarCuentaMensaje,
    this.antesDeCerrarSesion,
    this.mostrarCerrarSesion = true,
    this.permitirEditarNombre = false,
    super.key,
  });

  /// Texto de advertencia mostrado en el diálogo de confirmación al
  /// eliminar la cuenta -- qué se borra exactamente, específico de la app.
  final String eliminarCuentaMensaje;

  /// Limpieza previa a FirebaseAuth.instance.signOut() -- p.ej. olvidar el
  /// token FCM de este dispositivo. Opcional: null si la app no tiene nada
  /// que limpiar.
  final Future<void> Function()? antesDeCerrarSesion;

  /// false cuando quien instancia esta pantalla ya ofrece "Cerrar sesión"
  /// en otro sitio (rediseño de Ajustes de Hogar, noviembre 2026: al final
  /// de la pantalla, no dentro de "Tu cuenta") -- evita la fila duplicada
  /// sin quitarle a Pro su único punto de cierre de sesión, que sigue
  /// mostrándola por defecto.
  final bool mostrarCerrarSesion;

  /// true solo en Hogar (rediseño de registro/perfil, noviembre 2026):
  /// convierte la fila de identidad en algo editable (nombre real que ven
  /// los demás, vía [CuentaService.actualizarNombrePerfil]). Pro conserva
  /// por defecto su fila de identidad de siempre, de solo lectura.
  final bool permitirEditarNombre;

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  bool _eliminandoCuenta = false;
  bool _cerrandoTodo = false;

  Future<void> _confirmarCerrarSesion() => confirmarYCerrarSesion(
    context,
    antesDeCerrarSesion: widget.antesDeCerrarSesion,
  );

  Future<void> _confirmarCerrarSesionEnTodosLosDispositivos() async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Cerrar sesión en todos los dispositivos?',
      message:
          'Este dispositivo se cierra al momento. Los demás seguirán abiertos hasta una hora más mientras se '
          'renueva su sesión automáticamente -- no es instantáneo en ellos.',
      confirmLabel: 'Cerrar en todos',
    );
    if (!confirmar || !mounted) return;
    setState(() => _cerrandoTodo = true);
    try {
      await CuentaService.cerrarSesionesEnTodosLosDispositivos();
      await widget.antesDeCerrarSesion?.call();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        AppError.show(
          context,
          'No se pudo cerrar la sesión en todos los dispositivos.',
        );
      }
    } finally {
      if (mounted) setState(() => _cerrandoTodo = false);
    }
  }

  Future<void> _editarNombre(String? actual) async {
    final nombre = await AppDialog.promptText(
      context,
      title: 'Tu nombre',
      hint: 'Como quieres que te vean en tus casas',
      initialValue: actual ?? '',
    );
    if (nombre == null || nombre.isEmpty || nombre == actual || !mounted) {
      return;
    }
    try {
      await CuentaService.actualizarNombrePerfil(nombre);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo guardar tu nombre.');
    }
  }

  /// Foto de perfil personal (mejora de perfiles, noviembre 2026) -- se
  /// guarda en FirebaseAuth.photoURL, no en Firestore: es exactamente el
  /// mismo campo que esta pantalla y ajustes_hogar_screen.dart/
  /// ajustes_pro_screen.dart ya leían para pintar el avatar (user?.photoURL),
  /// así que no hace falta ningún campo nuevo ni tocar dónde se muestra --
  /// solo rellenarlo de verdad. reload() + setState refrescan
  /// FirebaseAuth.instance.currentUser, que esta pantalla no escucha como
  /// stream.
  Future<void> _cambiarFoto(User? user) async {
    if (user == null) return;
    await editarFotoPerfil(
      context,
      storagePath: 'users/${user.uid}/avatar/foto',
      tieneFotoActual: user.photoURL != null,
      onGuardar: (url) async {
        await user.updateProfile(photoURL: url);
        await user.reload();
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _confirmarEliminarCuenta() async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Eliminar tu cuenta?',
      message: widget.eliminarCuentaMensaje,
      confirmLabel: 'Eliminar cuenta',
      destructive: true,
    );
    if (!confirmar || !mounted) return;

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
      if (mounted) {
        AppError.show(context, e.message ?? 'No se pudo eliminar la cuenta.');
      }
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        AppError.show(
          context,
          'No se pudo eliminar la cuenta. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _eliminandoCuenta = false);
    }
  }

  String _iniciales(String? nombre, String? email) {
    final limpio = nombre?.trim();
    if (limpio != null && limpio.isNotEmpty) {
      final partes = limpio.split(RegExp(r'\s+'));
      final letras = partes.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
      if (letras.isNotEmpty) return letras.toUpperCase();
    }
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  Widget _filaIdentidad(BuildContext context, User? user, String? nombre) {
    return IosRow(
      icon: Icons.person_outline,
      iconColor: context.colors.brand,
      title: (nombre?.isNotEmpty ?? false) ? nombre! : 'Tu perfil',
      subtitle: user?.email,
      showChevron: widget.permitirEditarNombre,
      onTap: widget.permitirEditarNombre ? () => _editarNombre(nombre) : null,
      // Foto independiente del resto de la fila: tocar el avatar cambia la
      // foto, tocar el resto de la fila edita el nombre (mejora de
      // perfiles, noviembre 2026) -- Material+InkWell circular propio para
      // que el tap/ripple se note como del avatar, no como de toda la fila.
      trailing: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _cambiarFoto(user),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: context.colors.brandStrong,
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null
                ? Text(
                    _iniciales(nombre, user?.email),
                    style: TextStyle(
                      color: context.colors.brandOn,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          IosSection(
            rows: [
              if (widget.permitirEditarNombre && user != null)
                StreamBuilder<String?>(
                  stream: CuentaService.streamNombrePerfil(user.uid),
                  builder: (context, snapshot) =>
                      _filaIdentidad(context, user, snapshot.data),
                )
              else
                _filaIdentidad(context, user, user?.displayName),
            ],
          ),
          IosSection(
            rows: [
              if (widget.mostrarCerrarSesion)
                IosRow(
                  icon: Icons.logout_outlined,
                  iconColor: context.colors.errorText,
                  title: 'Cerrar sesión',
                  titleColor: context.colors.errorText,
                  showChevron: false,
                  onTap: _confirmarCerrarSesion,
                ),
              IosRow(
                icon: Icons.devices_outlined,
                iconColor: context.colors.errorText,
                title: 'Cerrar sesión en todos los dispositivos',
                titleColor: context.colors.errorText,
                showChevron: false,
                trailing: _cerrandoTodo
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.errorText,
                        ),
                      )
                    : null,
                onTap: _cerrandoTodo
                    ? null
                    : _confirmarCerrarSesionEnTodosLosDispositivos,
              ),
            ],
          ),
          IosSection(
            rows: [
              IosRow(
                icon: Icons.delete_outline,
                iconColor: context.colors.errorText,
                title: 'Eliminar cuenta',
                titleColor: context.colors.errorText,
                showChevron: false,
                trailing: _eliminandoCuenta
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.errorText,
                        ),
                      )
                    : null,
                onTap: _eliminandoCuenta ? null : _confirmarEliminarCuenta,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
