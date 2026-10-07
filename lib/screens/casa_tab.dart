// lib/screens/casa_tab.dart
//
// Representación de la vivienda por habitaciones (sección 10 del spec):
// sin plano 3D en v1, una estructura simple y clicable.
import 'package:flutter/material.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import '../services/elemento_service.dart';
import '../services/habitacion_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';
import 'garantias_proximas_screen.dart';
import 'nuevo_elemento_screen.dart';
import 'revisiones_pendientes_screen.dart';

class CasaTab extends StatelessWidget {
  const CasaTab({required this.casa, super.key});

  final Casa casa;

  Future<void> _nuevaHabitacion(BuildContext context, int orden) async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva habitación'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'p.ej. Cocina')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Crear')),
        ],
      ),
    );
    if (nombre == null) return;
    if (nombre.isEmpty) {
      if (context.mounted) AppError.show(context, 'Escribe un nombre para la habitación.');
      return;
    }
    try {
      await HabitacionService.crear(casa.id, nombre, orden: orden);
    } catch (e) {
      if (context.mounted) AppError.show(context, 'No se pudo crear la habitación.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu casa'), actions: [BotonAjustes(casa: casa)]),
      body: StreamBuilder<List<Habitacion>>(
        stream: HabitacionService.streamHabitaciones(casa.id),
        builder: (context, snapshot) {
          final habitaciones = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              IosSection(
                rows: [
                  IosRow(
                    icon: Icons.shield_outlined,
                    iconColor: context.colors.warning,
                    title: 'Garantías',
                    onTap: () async {
                      final elementos = await ElementoService.conGarantia(casa.id);
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GarantiasProximasScreen(casa: casa, elementos: elementos, titulo: 'Todas las garantías')));
                      }
                    },
                  ),
                  IosRow(
                    icon: Icons.build_circle_outlined,
                    iconColor: context.colors.brand,
                    title: 'Mantenimiento',
                    onTap: () async {
                      final elementos = await ElementoService.conMantenimientoConfigurado(casa.id);
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RevisionesPendientesScreen(casa: casa, elementos: elementos, titulo: 'Todo el mantenimiento')));
                      }
                    },
                  ),
                ],
              ),
              if (habitaciones.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 32, color: context.colors.inkMuted),
                        const SizedBox(height: 10),
                        Text(
                          'Todavía no has añadido ninguna habitación.\nEmpieza por el salón, la cocina o el baño.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...habitaciones.map((h) => _HabitacionCard(casa: casa, habitacion: h)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _nuevaHabitacion(context, habitaciones.length),
                icon: const Icon(Icons.add),
                label: const Text('Añadir habitación'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HabitacionCard extends StatelessWidget {
  const _HabitacionCard({required this.casa, required this.habitacion});

  final Casa casa;
  final Habitacion habitacion;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.meeting_room_outlined, color: context.colors.brand),
          title: Text(habitacion.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            StreamBuilder<List<Elemento>>(
              stream: ElementoService.streamElementos(casa.id, habitacionId: habitacion.id),
              builder: (context, snapshot) {
                final elementos = snapshot.data ?? [];
                return Column(
                  children: [
                    for (var i = 0; i < elementos.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 56, color: context.colors.inkMuted.withValues(alpha: 0.14)),
                      IosRow(
                        icon: Icons.category_outlined,
                        iconColor: Colors.blueGrey,
                        title: elementos[i].nombre,
                        subtitle: elementos[i].marca != null ? '${elementos[i].marca} ${elementos[i].modelo ?? ''}'.trim() : null,
                        trailing: elementos[i].garantiaProximaAVencer
                            ? Icon(Icons.shield_outlined, color: context.colors.warning, size: 20)
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: elementos[i].id)),
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NuevoElementoScreen(casa: casa, habitacionId: habitacion.id),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Añadir elemento'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
