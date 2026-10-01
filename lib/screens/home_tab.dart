// lib/screens/home_tab.dart
//
// Inicio + Historial fusionados en una sola pestaña (decisión del CEO: eran
// demasiado parecidos para ocupar dos huecos en la barra de navegación).
// Arriba, el estado actual de la casa (avisos de garantías); debajo, la
// historia completa filtrable -- sección 8 y 12 del spec de producto.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../models/evento.dart';
import '../services/elemento_service.dart';
import '../services/evento_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/boton_notificaciones.dart';
import 'menu_anadir.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({required this.casa, super.key});

  final Casa casa;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  TipoEvento? _filtro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.casa.nombre), actions: const [BotonNotificaciones(modoPro: false), BotonAjustes()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarMenuAnadir(context, casaId: widget.casa.id),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
      body: Column(
        children: [
          FutureBuilder<List<Elemento>>(
            future: ElementoService.conGarantiaProximaAVencer(widget.casa.id),
            builder: (context, snapshot) {
              final elementos = snapshot.data ?? [];
              if (elementos.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Card(
                  color: context.colors.warning.withValues(alpha: 0.12),
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
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(label: const Text('Todo'), selected: _filtro == null, onSelected: (_) => setState(() => _filtro = null)),
                  const SizedBox(width: 8),
                  ...TipoEvento.values.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_nombreTipo(t)),
                          selected: _filtro == t,
                          onSelected: (_) => setState(() => _filtro = t),
                        ),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Evento>>(
              stream: EventoService.streamHistorial(widget.casa.id),
              builder: (context, snapshot) {
                var eventos = snapshot.data ?? [];
                if (_filtro != null) eventos = eventos.where((e) => e.tipo == _filtro).toList();
                if (eventos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filtro == null
                            ? 'La historia de tu casa empieza aquí.\nRegistra tu primer trabajo, factura o elemento.'
                            : 'Nada de este tipo todavía.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.inkMuted),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: eventos.length,
                  itemBuilder: (context, i) => _EventoTile(evento: eventos[i]),
                );
              },
            ),
          ),
        ],
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
        subtitle: Text(
          [
            DateFormat('d MMM yyyy', 'es_ES').format(evento.fecha),
            if (evento.profesionalNombre != null) evento.profesionalNombre!,
          ].join(' · '),
        ),
        trailing: evento.coste != null ? Text('${evento.coste!.toStringAsFixed(0)} €') : null,
      ),
    );
  }
}

String _nombreTipo(TipoEvento t) => switch (t) {
      TipoEvento.instalacion => 'Instalación',
      TipoEvento.revision => 'Revisión',
      TipoEvento.reparacion => 'Reparación',
      TipoEvento.sustitucion => 'Sustitución',
      TipoEvento.reforma => 'Reforma',
      TipoEvento.nota => 'Nota',
    };
