// lib/screens/notificaciones_screen.dart
//
// Notificaciones internas persistentes (sección 29 del spec) -- sin push
// real todavía, se consultan dentro de la app.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notificacion.dart';
import '../services/analytics_service.dart';
import '../services/notificacion_router.dart';
import '../services/notificacion_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({required this.modoPro, super.key});

  /// true si se abrió desde Repara Pro -- filtra la lista a solo las
  /// notificaciones de ese lado y decide a qué pantalla de trabajo navegar.
  final bool modoPro;

  Future<void> _abrirTrabajo(BuildContext context, Notificacion n) async {
    if (!n.leida) await NotificacionService.marcarLeida(n.id);
    if (!context.mounted) return;
    if (n.tipo == 'presupuesto_enviado') unawaited(AnalyticsService.quoteViewed());
    await abrirDestinoNotificacion(context, tipo: n.tipo, casaId: n.casaId, elementoId: n.elementoId, registroId: n.registroId, pagoId: n.pagoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notificaciones', style: Theme.of(context).textTheme.displaySmall)),
      body: StreamBuilder<List<Notificacion>>(
        stream: NotificacionService.streamMisNotificaciones(),
        builder: (context, snapshot) {
          final notificaciones = (snapshot.data ?? []).where((n) => n.esParaProfesional == modoPro).toList();
          if (notificaciones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                      child: Icon(Icons.notifications_outlined, size: 32, color: context.colors.brand),
                    ),
                    const SizedBox(height: 16),
                    Text('No tienes notificaciones todavía.', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [IosSection(rows: notificaciones.map((n) => _filaNotificacion(context, n, () => _abrirTrabajo(context, n))).toList())],
          );
        },
      ),
    );
  }
}

Widget _filaNotificacion(BuildContext context, Notificacion n, VoidCallback onTap) {
  final color = n.leida ? context.colors.inkMuted : context.colors.brand;
  return IosRow(
    icon: _iconoTipo(n.tipo),
    iconColor: color,
    title: n.titulo,
    titleColor: n.leida ? context.colors.inkMuted : null,
    subtitle: n.cuerpo,
    showChevron: false,
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!n.leida) Container(width: 7, height: 7, decoration: BoxDecoration(color: context.colors.brand, shape: BoxShape.circle)),
        if (n.createdAt != null) ...[
          const SizedBox(height: 4),
          Text(DateFormat('d MMM', 'es_ES').format(n.createdAt!), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
        ],
      ],
    ),
    onTap: onTap,
  );
}

IconData _iconoTipo(String tipo) => switch (tipo) {
      'presupuesto_enviado' || 'presupuesto_aceptado' || 'presupuesto_rechazado' => Icons.request_quote_outlined,
      'cambio_alcance_solicitado' || 'cambio_alcance_aprobado' || 'cambio_alcance_rechazado' => Icons.rule_outlined,
      'trabajo_finalizado' => Icons.check_circle_outline,
      'trabajo_pendiente_confirmacion' => Icons.hourglass_top_outlined,
      'trabajo_finalizacion_rechazada' => Icons.undo_outlined,
      'pago_registrado' => Icons.payments_outlined,
      _ => Icons.notifications_outlined,
    };
