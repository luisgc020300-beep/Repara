// lib/widgets/historial_timeline.dart
//
// Línea de tiempo vertical (icono + línea conectora) para el historial de un
// registro -- deliberadamente ciego a Firestore/HistorialEvento: recibe una
// lista ya preparada de [TimelineItem], así que cualquier pantalla que tenga
// una secuencia de sucesos puede reutilizarlo sin acoplarse al modelo de
// historial.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:repara_core/design_tokens.dart';

class TimelineItem {
  const TimelineItem({
    required this.titulo,
    this.subtitulo,
    this.fechaTexto,
    this.fecha,
    this.autor,
    this.categoria,
    this.icono = Icons.check,
    this.color,
    this.onTap,
  });

  final String titulo;
  final String? subtitulo;

  /// null cuando no hay una fecha real que mostrar (nunca se inventa una).
  final String? fechaTexto;

  /// Fecha real (no solo el texto ya formateado) -- la usa HistorialTimeline
  /// para agrupar visualmente los eventos del mismo día (sección 4.3:
  /// "Los eventos deben estar agrupados por fecha"). null tiene el mismo
  /// significado que en [fechaTexto]: no se inventa una fecha.
  final DateTime? fecha;

  /// Quién lo realizó (sección 3.3) -- null cuando no se conoce, nunca se
  /// inventa un autor.
  final String? autor;

  /// Agrupa el filtro por categoría (sección 4.3: chips Todo/Presupuestos/
  /// Cambios/Pagos/Documentos/Finalización/Citas) -- null cae siempre en el
  /// filtro "Todo", nunca se oculta en ningún filtro concreto.
  final String? categoria;
  final IconData icono;
  final Color? color;

  /// Abre el presupuesto/pago/cambio relacionado -- null cuando no existe
  /// todavía una pantalla de detalle natural a la que llevar (nunca se
  /// fabrica una navegación que no hay).
  final VoidCallback? onTap;
}

class HistorialTimeline extends StatelessWidget {
  const HistorialTimeline({required this.items, super.key});

  final List<TimelineItem> items;

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (items[i].fecha != null &&
              (i == 0 ||
                  items[i - 1].fecha == null ||
                  !_mismoDia(items[i].fecha!, items[i - 1].fecha!)))
            Padding(
              padding: EdgeInsets.only(bottom: 8, top: i == 0 ? 0 : 12),
              child: Text(
                DateFormat('d MMMM yyyy', 'es_ES').format(items[i].fecha!),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.inkMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          _Fila(item: items[i], esUltima: i == items.length - 1),
        ],
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.item, required this.esUltima});

  final TimelineItem item;
  final bool esUltima;

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? context.colors.success;
    final contenido = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icono, size: 14, color: color),
              ),
              if (!esUltima)
                Expanded(
                  child: Container(width: 1.5, color: context.colors.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltima ? 0 : 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.titulo,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (item.fechaTexto != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.fechaTexto!,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                  if (item.subtitulo != null && item.subtitulo!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitulo!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (item.autor != null && item.autor!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.autor!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.inkFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (item.onTap == null) return contenido;
    return InkWell(onTap: item.onTap, child: contenido);
  }
}
