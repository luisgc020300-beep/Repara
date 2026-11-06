// lib/screens/notificaciones_screen.dart
//
// Notificaciones internas persistentes (sección 29 del spec): se consultan
// dentro de la app, y complementan -- no sustituyen -- al push real por FCM
// (ver fcm_service.dart, que sí envía notificaciones push de verdad). Pendiente
// de verificar en dispositivo real y de configurar la clave APNs en consola
// para iOS (ver CLAUDE.md) -- pero la infraestructura de envío, recepción y
// enrutamiento ya existe y funciona, no es solo esta pantalla.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/notificacion.dart';
import 'package:repara_core/notificacion_service.dart';

import '../models/casa.dart';
import '../services/notificacion_router.dart';
import '../widgets/boton_ajustes.dart';
import 'package:repara_ui/notificaciones_list.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({required this.modoPro, this.casa, super.key});

  /// true si se abrió desde Repara Pro -- filtra la lista a solo las
  /// notificaciones de ese lado y decide a qué pantalla de trabajo navegar.
  final bool modoPro;

  /// Se pasa desde Hogar para que el engranaje abra Ajustes con la sección
  /// "Tu casa". Se omite desde Pro (mismo patrón que BotonAjustes).
  final Casa? casa;

  Future<void> _abrirTrabajo(BuildContext context, Notificacion n) async {
    if (!n.leida) await NotificacionService.marcarLeida(n.id);
    if (!context.mounted) return;
    if (n.tipo == 'presupuesto_enviado') unawaited(AnalyticsService.quoteViewed());
    await abrirDestinoNotificacion(context, tipo: n.tipo, casaId: n.casaId, elementoId: n.elementoId, registroId: n.registroId, pagoId: n.pagoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
        actions: [BotonAjustes(casa: casa, modoPro: modoPro)],
      ),
      body: StreamBuilder<List<Notificacion>>(
        stream: NotificacionService.streamMisNotificaciones(),
        builder: (context, snapshot) {
          final notificaciones = (snapshot.data ?? []).where((n) => n.esParaProfesional == modoPro).toList();
          return NotificacionesListView(
            notificaciones: notificaciones,
            onAbrir: (n) => _abrirTrabajo(context, n),
            onMarcarTodasLeidas: NotificacionService.marcarTodasLeidas,
          );
        },
      ),
    );
  }
}
