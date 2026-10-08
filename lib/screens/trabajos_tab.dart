// lib/screens/trabajos_tab.dart
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/trabajo.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/ios_list.dart';
import 'nuevo_trabajo_screen.dart';
import 'trabajo_detail_screen.dart';

class TrabajosTab extends StatelessWidget {
  const TrabajosTab({required this.casa, super.key});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos'), actions: [BotonAjustes(casa: casa)]),
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
                  'Aquí gestionas lo que tienes en marcha ahora: una avería, un presupuesto, un pago.\nCuando lo termines, pasará solo al historial de Inicio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.inkMuted),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              IosSection(
                rows: trabajos
                    .map((t) => IosRow(
                          icon: Icons.build_outlined,
                          iconColor: _colorEstado(context, t.estado),
                          title: t.titulo,
                          subtitle: _nombreEstado(t.estado),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TrabajoDetailScreen(casa: casa, trabajoId: t.id)),
                          ),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

Color _colorEstado(BuildContext context, EstadoTrabajo estado) => switch (estado) {
      EstadoTrabajo.nuevo => context.colors.inkMuted,
      EstadoTrabajo.presupuestado => context.colors.warning,
      EstadoTrabajo.enCurso => context.colors.brand,
      EstadoTrabajo.pendienteConfirmacion => context.colors.warning,
      EstadoTrabajo.terminado => context.colors.success,
      EstadoTrabajo.archivado => context.colors.inkMuted,
    };

String _nombreEstado(EstadoTrabajo e) => switch (e) {
      EstadoTrabajo.nuevo => 'Nuevo',
      EstadoTrabajo.presupuestado => 'Presupuestado',
      EstadoTrabajo.enCurso => 'En curso',
      EstadoTrabajo.pendienteConfirmacion => 'Pendiente de confirmación',
      EstadoTrabajo.terminado => 'Terminado',
      EstadoTrabajo.archivado => 'Archivado',
    };
