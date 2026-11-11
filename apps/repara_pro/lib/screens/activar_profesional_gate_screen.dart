// apps/repara_pro/lib/screens/activar_profesional_gate_screen.dart
//
// Puerta de entrada de REPARA Pro para cuentas nuevas que nunca han pasado
// por el monolito (auditoría de comunicación cruzada, noviembre 2026 --
// problema #3): sin esto, un usuario que instala solo Pro nunca llega a
// tener esProfesional=true ni el documento profesionales/{uid}, y queda
// atrapado en el shell sin que el backend lo reconozca como profesional.
//
// Mismo patrón reactivo que CasaGateScreen en Hogar: un StreamBuilder sobre
// esProfesional decide qué pantalla mostrar. No hace falta navegar
// manualmente tras activar -- en cuanto activarModoProfesional() escribe en
// Firestore, el propio stream pasa al shell solo.
import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/design_tokens.dart';
import 'package:repara_core/profesional_service.dart';
import 'package:repara_ui/app_error.dart';

import 'repara_pro_shell_screen.dart';

class ActivarProfesionalGateScreen extends StatefulWidget {
  const ActivarProfesionalGateScreen({super.key});

  @override
  State<ActivarProfesionalGateScreen> createState() =>
      _ActivarProfesionalGateScreenState();
}

class _ActivarProfesionalGateScreenState
    extends State<ActivarProfesionalGateScreen> {
  bool _activando = false;

  Future<void> _activar() async {
    if (_activando) return;
    setState(() => _activando = true);
    try {
      await ProfesionalService.activarModoProfesional();
      unawaited(AnalyticsService.setEsProfesional(true));
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (mounted) {
        AppError.show(context, 'No se pudo activar tu cuenta profesional.');
      }
    } finally {
      if (mounted) setState(() => _activando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ProfesionalService.streamEsProfesional(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) return const ReparaProShellScreen();
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(ReparaSpace.s6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.colors.brandTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.engineering_outlined,
                      color: context.colors.brandStrong,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: ReparaSpace.s6),
                  Text(
                    'Activa tu cuenta profesional',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.colors.ink,
                    ),
                  ),
                  const SizedBox(height: ReparaSpace.s3),
                  Text(
                    'Para gestionar trabajos, clientes y presupuestos con '
                    'REPARA Pro, primero tenemos que activar tu perfil '
                    'profesional.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: ReparaSpace.s8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _activando ? null : _activar,
                      child: _activando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Activar cuenta profesional'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
