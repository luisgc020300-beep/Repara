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
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';
import 'nuevo_elemento_screen.dart';

class CasaTab extends StatelessWidget {
  const CasaTab({required this.casa, super.key});

  final Casa casa;

  Future<void> _nuevaHabitacion(BuildContext context, int orden) async {
    final nombre = await AppDialog.promptText(context, title: 'Nueva habitación', hint: 'p.ej. Cocina', confirmLabel: 'Crear');
    if (nombre == null) return;
    if (nombre.isEmpty) {
      if (context.mounted) AppError.show(context, 'Escribe un nombre para la habitación.');
      return;
    }
    try {
      await HabitacionService.crear(casa.id, nombre, orden: orden);
    } catch (e, st) {
      if (context.mounted) AppError.show(context, 'No se pudo crear la habitación.', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('VIVIENDA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.colors.inkMuted)),
            Text('Tu casa', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26)),
          ],
        ),
        actions: [BotonAjustes(casa: casa)],
      ),
      body: StreamBuilder<List<Habitacion>>(
        stream: HabitacionService.streamHabitaciones(casa.id),
        builder: (context, snapshot) {
          final habitaciones = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (habitaciones.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                        child: Icon(Icons.meeting_room_outlined, size: 32, color: context.colors.brand),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Todavía no has añadido ninguna habitación.\nEmpieza por el salón, la cocina o el baño.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.inkMuted),
                      ),
                    ],
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
    return StreamBuilder<List<Elemento>>(
      stream: ElementoService.streamElementos(casa.id, habitacionId: habitacion.id),
      builder: (context, snapshot) {
        final elementos = snapshot.data ?? [];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: context.colors.brandTint, borderRadius: BorderRadius.circular(ReparaRadius.sm)),
                child: Icon(Icons.meeting_room_outlined, size: 19, color: context.colors.brand),
              ),
              title: Text(habitacion.nombre, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                elementos.isEmpty ? 'Sin elementos todavía' : '${elementos.length} elemento${elementos.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                for (var i = 0; i < elementos.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 56, color: context.colors.inkMuted.withValues(alpha: 0.14)),
                  IosRow(
                    icon: Icons.category_outlined,
                    iconColor: context.colors.brand,
                    imageUrl: elementos[i].fotoUrl,
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
                          builder: (_) => NuevoElementoScreen(casa: casa, habitacionIdInicial: habitacion.id),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Añadir elemento'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
