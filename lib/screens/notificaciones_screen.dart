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
    await abrirDestinoNotificacion(context, tipo: n.tipo, casaId: n.casaId, trabajoId: n.trabajoId, pagoId: n.pagoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: StreamBuilder<List<Notificacion>>(
        stream: NotificacionService.streamMisNotificaciones(),
        builder: (context, snapshot) {
          final notificaciones = (snapshot.data ?? []).where((n) => n.esParaProfesional == modoPro).toList();
          if (notificaciones.isEmpty) {
            return Center(child: Text('No tienes notificaciones todavía.', style: TextStyle(color: context.colors.inkMuted)));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              IosSection(
                rows: notificaciones
                    .map((n) => IosRow(
                          icon: _iconoTipo(n.tipo),
                          iconColor: n.leida ? context.colors.inkMuted : context.colors.brand,
                          title: n.titulo,
                          titleColor: n.leida ? null : context.colors.ink,
                          subtitle: n.cuerpo,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!n.leida) ...[
                                Container(width: 7, height: 7, decoration: BoxDecoration(color: context.colors.brand, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                              ],
                              if (n.createdAt != null)
                                Text(DateFormat('d MMM', 'es_ES').format(n.createdAt!), style: TextStyle(color: context.colors.inkMuted, fontSize: 12)),
                            ],
                          ),
                          onTap: () => _abrirTrabajo(context, n),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData _iconoTipo(String tipo) => switch (tipo) {
      'presupuesto_enviado' || 'presupuesto_aceptado' || 'presupuesto_rechazado' => Icons.request_quote_outlined,
      'cambio_alcance_solicitado' || 'cambio_alcance_aprobado' || 'cambio_alcance_rechazado' => Icons.rule_outlined,
      'trabajo_finalizado' => Icons.check_circle_outline,
      'pago_registrado' => Icons.payments_outlined,
      _ => Icons.notifications_outlined,
    };
