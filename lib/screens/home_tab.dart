// lib/screens/home_tab.dart
//
// Home del propietario (sección 8 del spec): no es una lista de funciones,
// representa la vivienda -- estado general, garantías próximas y la
// actividad reciente de la casa.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../models/evento.dart';
import '../services/elemento_service.dart';
import '../services/evento_service.dart';
import '../theme/design_tokens.dart';
import 'nuevo_evento_sheet.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(casa.nombre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarNuevoEventoSheet(context, casaId: casa.id),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<List<Elemento>>(
              future: ElementoService.conGarantiaProximaAVencer(casa.id),
              builder: (context, snapshot) {
                final elementos = snapshot.data ?? [];
                if (elementos.isEmpty) return const SizedBox.shrink();
                return Card(
                  color: context.colors.warning.withValues(alpha: 0.12),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: context.colors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            elementos.length == 1
                                ? 'La garantía de "${elementos.first.nombre}" termina pronto.'
                                : '${elementos.length} garantías están a punto de terminar.',
                            style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Text('Historia reciente', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            StreamBuilder<List<Evento>>(
              stream: EventoService.streamHistorial(casa.id),
              builder: (context, snapshot) {
                final eventos = (snapshot.data ?? []).take(5).toList();
                if (eventos.isEmpty) {
                  return _EmptyCard(
                    icon: Icons.auto_stories_outlined,
                    texto: 'La historia de tu casa empieza aquí.\nRegistra tu primer trabajo, factura o elemento.',
                  );
                }
                return Column(
                  children: eventos.map((e) => _EventoTile(evento: e)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EventoTile extends StatelessWidget {
  const _EventoTile({required this.evento});

  final Evento evento;

  IconData get _icono => switch (evento.tipo) {
        TipoEvento.instalacion => Icons.add_box_outlined,
        TipoEvento.revision => Icons.fact_check_outlined,
        TipoEvento.reparacion => Icons.build_outlined,
        TipoEvento.sustitucion => Icons.swap_horiz,
        TipoEvento.reforma => Icons.architecture_outlined,
        TipoEvento.nota => Icons.push_pin_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.colors.brand.withValues(alpha: 0.1),
          child: Icon(_icono, color: context.colors.brand, size: 20),
        ),
        title: Text(evento.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(DateFormat('d MMM yyyy', 'es_ES').format(evento.fecha)),
        trailing: evento.coste != null ? Text('${evento.coste!.toStringAsFixed(0)} €') : null,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 32, color: context.colors.inkMuted),
            const SizedBox(height: 10),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: context.colors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
