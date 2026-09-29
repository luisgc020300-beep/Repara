// lib/screens/trabajos_tab.dart
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/trabajo.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';
import 'nuevo_trabajo_screen.dart';
import 'trabajo_detail_screen.dart';

class TrabajosTab extends StatelessWidget {
  const TrabajosTab({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NuevoTrabajoScreen(casa: casa))),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo trabajo'),
      ),
      body: StreamBuilder<List<Trabajo>>(
        stream: TrabajoService.streamTrabajos(casa.id),
        builder: (context, snapshot) {
          final trabajos = snapshot.data ?? [];
          if (trabajos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No has registrado ningún trabajo todavía.\nUna avería, una reparación o una reforma -- lo que sea, queda aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.inkMuted),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trabajos.length,
            itemBuilder: (context, i) {
              final t = trabajos[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_nombreEstado(t.estado)),
                  trailing: _EstadoBadge(estado: t.estado),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TrabajoDetailScreen(casa: casa, trabajoId: t.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final EstadoTrabajo estado;

  Color _color(BuildContext context) => switch (estado) {
        EstadoTrabajo.nuevo => context.colors.inkMuted,
        EstadoTrabajo.presupuestado => context.colors.warning,
        EstadoTrabajo.enCurso => context.colors.brand,
        EstadoTrabajo.terminado => context.colors.success,
        EstadoTrabajo.archivado => context.colors.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _color(context).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(_nombreEstado(estado), style: TextStyle(color: _color(context), fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

String _nombreEstado(EstadoTrabajo e) => switch (e) {
      EstadoTrabajo.nuevo => 'Nuevo',
      EstadoTrabajo.presupuestado => 'Presupuestado',
      EstadoTrabajo.enCurso => 'En curso',
      EstadoTrabajo.terminado => 'Terminado',
      EstadoTrabajo.archivado => 'Archivado',
    };
