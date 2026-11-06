// apps/repara_pro/lib/screens/notificaciones_pro_screen.dart
//
// Versión Pro de lib/screens/notificaciones_screen.dart (monolito) -- la
// lista en sí (NotificacionesListView) es compartida vía repara_ui; lo
// único exclusivo de cada app es el AppBar/BotonAjustes y a qué pantalla
// enruta cada notificación (ver notificacion_router_pro.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:repara_core/analytics_service.dart';
import 'package:repara_core/notificacion.dart';
import 'package:repara_core/notificacion_service.dart';
import 'package:repara_ui/notificaciones_list.dart';

import '../services/notificacion_router_pro.dart';
import '../widgets/boton_ajustes_pro.dart';

class NotificacionesProScreen extends StatelessWidget {
  const NotificacionesProScreen({super.key});

  Future<void> _abrirTrabajo(BuildContext context, Notificacion n) async {
    if (!n.leida) await NotificacionService.marcarLeida(n.id);
    if (!context.mounted) return;
    if (n.tipo == 'presupuesto_enviado') unawaited(AnalyticsService.quoteViewed());
    await abrirDestinoNotificacionPro(
      context,
      tipo: n.tipo,
      casaId: n.casaId,
      elementoId: n.elementoId,
      registroId: n.registroId,
      pagoId: n.pagoId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
        actions: const [BotonAjustesPro()],
      ),
      body: StreamBuilder<List<Notificacion>>(
        stream: NotificacionService.streamMisNotificaciones(),
        builder: (context, snapshot) {
          final notificaciones = (snapshot.data ?? []).where((n) => n.esParaProfesional).toList();
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
