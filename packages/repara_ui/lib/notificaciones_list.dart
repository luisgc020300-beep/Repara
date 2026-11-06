// packages/repara_ui/lib/notificaciones_list.dart
//
// Lista de notificaciones (icono, color por categoría, agrupado por
// día) -- compartida entre REPARA (Hogar) y REPARA Pro. El enrutamiento al
// tocar una notificación (abrirDestinoNotificacion/abrirDestinoNotificacionPro)
// no vive aquí: cada app importa pantallas exclusivas de su lado, así que
// ese routing no se puede compartir entre apps (ver notificacion_router.dart
// de cada lado). Esta vista solo pinta la lista y delega el tap.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/notificacion.dart';

import 'ios_list.dart';
import 'package:repara_core/design_tokens.dart';

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

IconData iconoNotificacion(String tipo) => switch (tipo) {
  'presupuesto_enviado' ||
  'presupuesto_aceptado' ||
  'presupuesto_rechazado' ||
  'presupuesto_sin_respuesta' => Icons.request_quote_outlined,
  'cambio_alcance_solicitado' ||
  'cambio_alcance_aprobado' ||
  'cambio_alcance_rechazado' ||
  'cambio_alcance_cancelado' => Icons.rule_outlined,
  'trabajo_finalizado' => Icons.check_circle_outline,
  'trabajo_pendiente_confirmacion' => Icons.hourglass_top_outlined,
  'trabajo_finalizacion_rechazada' => Icons.undo_outlined,
  'elemento_archivado' => Icons.archive_outlined,
  'elemento_restaurado' => Icons.unarchive_outlined,
  'pago_registrado' => Icons.payments_outlined,
  'cita_creada' ||
  'cita_modificada' ||
  'recordatorio_cita_cliente' ||
  'recordatorio_cita_profesional' => Icons.event_outlined,
  'cita_cancelada' => Icons.event_busy_outlined,
  'documento_anadido_cliente' ||
  'documento_anadido_profesional' => Icons.description_outlined,
  'invitacion_aceptada' || 'invitacion_rechazada' => Icons.person_add_alt_outlined,
  'invitacion_hogar_recibida' ||
  'invitacion_hogar_aceptada' ||
  'invitacion_hogar_rechazada' => Icons.link_outlined,
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

Color colorNotificacion(BuildContext context, String tipo) {
  if (_tiposNegativos.contains(tipo)) return context.colors.errorText;
  if (_tiposDeAtencion.contains(tipo)) return context.colors.warningText;
  if (_tiposPositivos.contains(tipo)) return context.colors.success;
  return context.colors.brand;
}

/// Cuerpo completo de la pantalla de notificaciones: estado vacío, botón
/// "marcar todas como leídas" y la lista agrupada en Hoy/Ayer/Anteriores.
/// [onMarcarLeida]/[onMarcarTodasLeidas] son capacidades inyectadas (mismo
/// criterio que el resto de repara_ui) porque escriben en Firestore vía
/// `NotificacionService`, que esta vista no importa directamente.
class NotificacionesListView extends StatelessWidget {
  const NotificacionesListView({
    required this.notificaciones,
    required this.onAbrir,
    required this.onMarcarTodasLeidas,
    super.key,
  });

  final List<Notificacion> notificaciones;
  final void Function(Notificacion) onAbrir;
  final void Function(List<String> ids) onMarcarTodasLeidas;

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(
                  color: context.colors.brandTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 32,
                  color: context.colors.brand,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No tienes notificaciones todavía.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                  noLeidas.isEmpty ? 'Todo al día' : '${noLeidas.length} sin leer',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (noLeidas.isNotEmpty)
                TextButton(
                  onPressed: () => onMarcarTodasLeidas(noLeidas.map((n) => n.id).toList()),
                  child: const Text('Marcar todas como leídas'),
                ),
            ],
          ),
        ),
        if (deHoy.isNotEmpty)
          IosSection(
            header: 'Hoy',
            rows: deHoy.map((n) => _filaNotificacion(context, n, () => onAbrir(n))).toList(),
          ),
        if (deAyer.isNotEmpty)
          IosSection(
            header: 'Ayer',
            rows: deAyer.map((n) => _filaNotificacion(context, n, () => onAbrir(n))).toList(),
          ),
        if (anteriores.isNotEmpty)
          IosSection(
            header: 'Anteriores',
            rows: anteriores.map((n) => _filaNotificacion(context, n, () => onAbrir(n))).toList(),
          ),
      ],
    );
  }
}

IosRow _filaNotificacion(BuildContext context, Notificacion n, VoidCallback onTap) {
  final color = n.leida ? context.colors.inkMuted : colorNotificacion(context, n.tipo);
  return IosRow(
    icon: iconoNotificacion(n.tipo),
    iconColor: color,
    title: n.titulo,
    titleColor: n.leida ? context.colors.inkMuted : null,
    subtitle: n.cuerpo,
    showChevron: false,
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!n.leida)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: context.colors.brand, shape: BoxShape.circle),
          ),
        if (n.createdAt != null) ...[
          const SizedBox(height: 4),
          Text(
            DateFormat('d MMM', 'es_ES').format(n.createdAt!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ],
    ),
    onTap: onTap,
  );
}
