// lib/screens/garantias_proximas_screen.dart
//
// Lista de elementos cuya garantía vence en los próximos 30 días -- se abre
// al tocar el aviso de Inicio, para comprobar de un vistazo la fecha exacta
// de cada uno antes de entrar al detalle completo del elemento.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
import 'elemento_detail_screen.dart';

class GarantiasProximasScreen extends StatelessWidget {
  const GarantiasProximasScreen({required this.casa, required this.elementos, this.titulo = 'Garantías a punto de terminar', super.key});

  final Casa casa;
  final List<Elemento> elementos;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo, style: Theme.of(context).textTheme.displaySmall)),
      body: elementos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(Icons.shield_outlined, size: 32, color: context.colors.warning),
                    ),
                    const SizedBox(height: 16),
                    Text('Ningún elemento tiene una garantía guardada todavía.', textAlign: TextAlign.center, style: TextStyle(color: context.colors.inkMuted)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: elementos
                  .map((e) => Card(
                        margin: const EdgeInsets.only(bottom: 9),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(ReparaRadius.md),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: e.id))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(ReparaRadius.sm)),
                                  child: Icon(Icons.shield_outlined, size: 20, color: context.colors.warning),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.nombre, style: Theme.of(context).textTheme.titleMedium),
                                      if (e.garantiaHasta != null)
                                        Text(
                                          'Hasta ${DateFormat('d MMMM yyyy', 'es_ES').format(e.garantiaHasta!)}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.warningText, fontWeight: FontWeight.w600),
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
