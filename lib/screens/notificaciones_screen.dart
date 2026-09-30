// lib/screens/notificaciones_screen.dart
//
// Notificaciones internas persistentes (sección 29 del spec) -- sin push
// real todavía, se consultan dentro de la app.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notificacion.dart';
import '../services/notificacion_service.dart';
import '../theme/design_tokens.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: StreamBuilder<List<Notificacion>>(
        stream: NotificacionService.streamMisNotificaciones(),
        builder: (context, snapshot) {
          final notificaciones = snapshot.data ?? [];
          if (notificaciones.isEmpty) {
            return Center(child: Text('No tienes notificaciones todavía.', style: TextStyle(color: context.colors.inkMuted)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notificaciones.length,
            itemBuilder: (context, i) {
              final n = notificaciones[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: n.leida ? null : context.colors.brand.withValues(alpha: 0.06),
                child: ListTile(
                  leading: Icon(_iconoTipo(n.tipo), color: n.leida ? context.colors.inkMuted : context.colors.brand),
                  title: Text(n.titulo, style: TextStyle(fontWeight: n.leida ? FontWeight.w500 : FontWeight.w700)),
                  subtitle: Text(n.cuerpo),
                  trailing: n.createdAt != null ? Text(DateFormat('d MMM', 'es_ES').format(n.createdAt!)) : null,
                  onTap: () {
                    if (!n.leida) NotificacionService.marcarLeida(n.id);
                  },
                ),
              );
            },
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
      _ => Icons.notifications_outlined,
    };
