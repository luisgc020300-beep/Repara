// lib/screens/trabajos_pendientes_screen.dart
//
// Lista de elementos con al menos un registro en curso con un profesional
// -- se abre al tocar "Trabajos pendientes" en Inicio, mismo patrón que
// garantias_proximas_screen.dart y revisiones_pendientes_screen.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
import 'elemento_detail_screen.dart';

class TrabajosPendientesScreen extends StatelessWidget {
  const TrabajosPendientesScreen({required this.casa, required this.items, super.key});

  final Casa casa;
  final List<({Elemento elemento, String registroTitulo, DateTime fecha})> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Trabajos pendientes', style: Theme.of(context).textTheme.displaySmall)),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                      child: Icon(Icons.hourglass_top_outlined, size: 32, color: context.colors.brand),
                    ),
                    const SizedBox(height: 16),
                    Text('No tienes ningún trabajo en curso con un profesional.', textAlign: TextAlign.center, style: TextStyle(color: context.colors.inkMuted)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: items
                  .map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 9),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(ReparaRadius.md),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: item.elemento.id))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: context.colors.brandTint, borderRadius: BorderRadius.circular(ReparaRadius.sm)),
                                  child: Icon(Icons.hourglass_top_outlined, size: 20, color: context.colors.brand),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.elemento.nombre, style: Theme.of(context).textTheme.titleMedium),
                                      Text(
                                        '${item.registroTitulo} · ${DateFormat('d MMM yyyy', 'es_ES').format(item.fecha)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: context.colors.inkMuted),
                              ],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
