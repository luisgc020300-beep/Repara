// lib/screens/historial_tab.dart
//
// "La historia de tu casa" (sección 12 del spec) -- timeline completa con
// filtro por tipo de evento.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/evento.dart';
import '../services/evento_service.dart';
import '../theme/design_tokens.dart';

class HistorialTab extends StatefulWidget {
  const HistorialTab({required this.casa, super.key});

  final Casa casa;

  @override
  State<HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends State<HistorialTab> {
  TipoEvento? _filtro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: Column(
        children: [
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
                    child: Text('Todavía no hay nada que mostrar aquí.', style: TextStyle(color: context.colors.inkMuted)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: eventos.length,
                  itemBuilder: (context, i) {
                    final e = eventos[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            DateFormat('d MMMM yyyy', 'es_ES').format(e.fecha),
                            if (e.profesionalNombre != null) e.profesionalNombre!,
                          ].join(' · '),
                        ),
                        trailing: e.coste != null ? Text('${e.coste!.toStringAsFixed(0)} €') : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
