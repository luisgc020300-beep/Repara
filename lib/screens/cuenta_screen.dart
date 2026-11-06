// lib/screens/cuenta_screen.dart
//
// "Tu cuenta" (rediseño Ajustes, noviembre 2026): identidad + las tres
// acciones de sesión/cuenta que antes vivían sueltas al final de Ajustes
// (Cerrar sesión, Cerrar en todos los dispositivos, Eliminar cuenta).
// Lógica movida tal cual desde settings_screen.dart -- solo cambia dónde vive.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/cuenta_service.dart';
import '../services/fcm_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_ui/app_dialog.dart';
import 'package:repara_ui/app_error.dart';
import 'package:repara_ui/ios_list.dart';

class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  bool _eliminandoCuenta = false;
  bool _cerrandoTodo = false;

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
    );
    if (!confirmar) return;
    await FcmService.olvidarEsteDispositivo();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
      await FcmService.olvidarEsteDispositivo();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        AppError.show(context, 'No se pudo cerrar la sesión en todos los dispositivos.');
      }
    } finally {
      if (mounted) setState(() => _cerrandoTodo = false);
    }
  }

  Future<void> _confirmarEliminarCuenta() async {
    final confirmar = await AppDialog.confirm(
      context,
      title: '¿Eliminar tu cuenta?',
      message:
          'Se borra tu perfil y, si eres el único miembro de tu vivienda, también la vivienda entera con su '
          'historial, documentos y fotos. Si la compartes con alguien más, solo se elimina tu vinculación a ella. '
          'Esta acción no se puede deshacer.',
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
      if (mounted) AppError.show(context, e.message ?? 'No se pudo eliminar la cuenta.');
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) AppError.show(context, 'No se pudo eliminar la cuenta. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _eliminandoCuenta = false);
    }
  }

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
              IosRow(
                icon: Icons.person_outline,
                iconColor: context.colors.brand,
                title: user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Tu perfil',
                subtitle: user?.email,
                showChevron: false,
                trailing: CircleAvatar(
                  radius: 16,
                  backgroundColor: context.colors.brandStrong,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null
                      ? Text(
                          _iniciales(user),
                          style: TextStyle(
                            color: context.colors.brandOn,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
          IosSection(
            rows: [
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.errorText),
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
                iconColor: context.colors.errorText,
                title: 'Eliminar cuenta',
                titleColor: context.colors.errorText,
                showChevron: false,
                trailing: _eliminandoCuenta
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.errorText),
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
