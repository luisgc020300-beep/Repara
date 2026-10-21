// lib/widgets/historial_timeline.dart
//
// Línea de tiempo vertical (icono + línea conectora) para el historial de un
// registro -- deliberadamente ciego a Firestore/HistorialEvento: recibe una
// lista ya preparada de [TimelineItem], así que cualquier pantalla que tenga
// una secuencia de sucesos puede reutilizarlo sin acoplarse al modelo de
// historial.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class TimelineItem {
  const TimelineItem({
    required this.titulo,
    this.subtitulo,
    this.fechaTexto,
    this.icono = Icons.check,
    this.color,
  });

  final String titulo;
  final String? subtitulo;

  /// null cuando no hay una fecha real que mostrar (nunca se inventa una).
  final String? fechaTexto;
  final IconData icono;
  final Color? color;
}

class HistorialTimeline extends StatelessWidget {
  const HistorialTimeline({required this.items, super.key});

  final List<TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _Fila(item: items[i], esUltima: i == items.length - 1),
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
    return IntrinsicHeight(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
