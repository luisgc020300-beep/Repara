// lib/screens/notificaciones_screen.dart
//
// Notificaciones internas persistentes (sección 29 del spec) -- sin push
// real todavía, se consultan dentro de la app.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notificacion.dart';
import '../services/casa_service.dart';
import '../services/notificacion_service.dart';
import '../theme/design_tokens.dart';
import 'pro/trabajo_pro_detail_screen.dart';
import 'trabajo_detail_screen.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({required this.modoPro, super.key});

  /// true si se abrió desde Repara Pro -- filtra la lista a solo las
  /// notificaciones de ese lado y decide a qué pantalla de trabajo navegar.
  final bool modoPro;

  Future<void> _abrirTrabajo(BuildContext context, Notificacion n) async {
    if (!n.leida) await NotificacionService.marcarLeida(n.id);
    final casaId = n.casaId;
    final trabajoId = n.trabajoId;
    if (casaId == null || trabajoId == null || !context.mounted) return;

    if (modoPro) {
      // El profesional no es miembro de la casa (ver firestore.rules) -- solo
      // tiene acceso al trabajo concreto, no hace falta ni se puede leer la
      // casa entera.
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => TrabajoProDetailScreen(casaId: casaId, trabajoId: trabajoId)),
      );
      return;
    }
    final casa = await CasaService.streamCasa(casaId).first;
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => TrabajoDetailScreen(casa: casa, trabajoId: trabajoId)),
    );
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
                  onTap: () => _abrirTrabajo(context, n),
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
