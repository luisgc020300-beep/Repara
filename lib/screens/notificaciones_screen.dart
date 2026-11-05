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
import 'package:intl/intl.dart';
import 'package:repara_core/notificacion.dart';

import '../models/casa.dart';
import '../services/analytics_service.dart';
import '../services/notificacion_router.dart';
import '../services/notificacion_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/ios_list.dart';

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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

          final noLeidas = notificaciones.where((n) => !n.leida).toList();
          final hoy = _soloFecha(DateTime.now());
          final ayer = hoy.subtract(const Duration(days: 1));
          final deHoy = <Notificacion>[];
          final deAyer = <Notificacion>[];
          final anteriores = <Notificacion>[];
          for (final n in notificaciones) {
            final fecha = n.createdAt;
            if (fecha != null && _mismoDia(fecha, hoy)) {
              deHoy.add(n);
            } else if (fecha != null && _mismoDia(fecha, ayer)) {
              deAyer.add(n);
            } else {
              anteriores.add(n);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        noLeidas.isEmpty
                            ? 'Todo al día'
                            : '${noLeidas.length} sin leer',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (noLeidas.isNotEmpty)
                      TextButton(
                        onPressed: () => NotificacionService.marcarTodasLeidas(
                          noLeidas.map((n) => n.id).toList(),
                        ),
                        child: const Text('Marcar todas como leídas'),
                      ),
                  ],
                ),
              ),
              if (deHoy.isNotEmpty)
                IosSection(
                  header: 'Hoy',
                  rows: deHoy.map((n) => _filaNotificacion(context, n, () => _abrirTrabajo(context, n))).toList(),
                ),
              if (deAyer.isNotEmpty)
                IosSection(
                  header: 'Ayer',
                  rows: deAyer.map((n) => _filaNotificacion(context, n, () => _abrirTrabajo(context, n))).toList(),
                ),
              if (anteriores.isNotEmpty)
                IosSection(
                  header: 'Anteriores',
                  rows: anteriores.map((n) => _filaNotificacion(context, n, () => _abrirTrabajo(context, n))).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

Widget _filaNotificacion(BuildContext context, Notificacion n, VoidCallback onTap) {
  // Leída se apaga a gris sin importar el tipo (ya se distingue por estar
  // en negrita o no); no leída se colorea por categoría -- verde lo
  // positivo, naranja lo que pide atención, rojo solo lo negativo/rechazado,
  // azul de marca el resto (informativo neutral) -- sección 4.1 del encargo.
  final color = n.leida ? context.colors.inkMuted : _colorTipo(context, n.tipo);
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
      'presupuesto_enviado' || 'presupuesto_aceptado' || 'presupuesto_rechazado' || 'presupuesto_sin_respuesta' =>
        Icons.request_quote_outlined,
      'cambio_alcance_solicitado' || 'cambio_alcance_aprobado' || 'cambio_alcance_rechazado' || 'cambio_alcance_cancelado' =>
        Icons.rule_outlined,
      'trabajo_finalizado' => Icons.check_circle_outline,
      'trabajo_pendiente_confirmacion' => Icons.hourglass_top_outlined,
      'trabajo_finalizacion_rechazada' => Icons.undo_outlined,
      'elemento_archivado' => Icons.archive_outlined,
      'elemento_restaurado' => Icons.unarchive_outlined,
      'pago_registrado' => Icons.payments_outlined,
      'cita_creada' || 'cita_modificada' || 'recordatorio_cita_cliente' || 'recordatorio_cita_profesional' =>
        Icons.event_outlined,
      'cita_cancelada' => Icons.event_busy_outlined,
      'documento_anadido_cliente' || 'documento_anadido_profesional' => Icons.description_outlined,
      'invitacion_aceptada' || 'invitacion_rechazada' => Icons.person_add_alt_outlined,
      'invitacion_hogar_recibida' || 'invitacion_hogar_aceptada' || 'invitacion_hogar_rechazada' =>
        Icons.link_outlined,
      _ => Icons.notifications_outlined,
    };

const _tiposNegativos = {
  'presupuesto_rechazado',
  'cambio_alcance_rechazado',
  'cambio_alcance_cancelado',
  'trabajo_finalizacion_rechazada',
  'invitacion_rechazada',
  'invitacion_hogar_rechazada',
  'cita_cancelada',
};

const _tiposDeAtencion = {
  'trabajo_pendiente_confirmacion',
  'presupuesto_sin_respuesta',
  'recordatorio_cita_cliente',
  'recordatorio_cita_profesional',
  'elemento_archivado',
  'invitacion_hogar_recibida',
};

const _tiposPositivos = {
  'presupuesto_aceptado',
  'cambio_alcance_aprobado',
  'trabajo_finalizado',
  'pago_registrado',
  'invitacion_aceptada',
  'invitacion_hogar_aceptada',
  'cita_creada',
  'elemento_restaurado',
};

Color _colorTipo(BuildContext context, String tipo) {
  if (_tiposNegativos.contains(tipo)) return context.colors.errorText;
  if (_tiposDeAtencion.contains(tipo)) return context.colors.warningText;
  if (_tiposPositivos.contains(tipo)) return context.colors.success;
  return context.colors.brand;
}
