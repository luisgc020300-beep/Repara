// lib/screens/casa_tab.dart
//
// Representación de la vivienda por habitaciones (sección 10 del spec):
// sin plano 3D en v1, una estructura simple y clicable. Rediseño de
// fidelidad visual (octubre 2026), misma identidad "REPARA Professional"
// que registro_detail_screen.dart/elemento_detail_screen.dart/home_tab.dart:
// cabecera con el nombre real de la casa (antes decía "Tu casa" fijo, un
// residuo que nunca se actualizó) y un subtítulo de habitaciones/elementos
// reales; insignia de habitación que pasa a ámbar cuando algo dentro
// necesita atención (mismo criterio que el aviso y la fila de elemento de
// Inicio); estado vacío cuidado por habitación en vez de un hueco silencioso.
//
// Un único stream de elementos de toda la casa (sin filtrar por
// habitación), agrupado en memoria -- antes cada tarjeta de habitación
// abría su propia suscripción filtrada (N consultas para N habitaciones);
// aquí se reutiliza el mismo patrón de ElementoService.streamElementos()
// que ya usa HomeTab sin el filtro, y de paso permite mostrar el total real
// de elementos en la cabecera sin ninguna consulta nueva.
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
import 'elementos_archivados_screen.dart';
import 'nuevo_elemento_screen.dart';

class CasaTab extends StatelessWidget {
  const CasaTab({required this.casa, super.key});

  final Casa casa;

  Future<void> _nuevaHabitacion(BuildContext context, int orden) async {
    final nombre = await AppDialog.promptText(
      context,
      title: 'Nueva habitación',
      hint: 'p.ej. Cocina',
      confirmLabel: 'Crear',
    );
    if (nombre == null) return;
    if (nombre.isEmpty) {
      if (context.mounted) {
        AppError.show(context, 'Escribe un nombre para la habitación.');
      }
      return;
    }
    try {
      await HabitacionService.crear(casa.id, nombre, orden: orden);
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo crear la habitación.',
          error: e,
          stackTrace: st,
        );
      }
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
            Text(
              'VIVIENDA',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: context.colors.inkMuted,
              ),
            ),
            Text(
              casa.nombre,
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontSize: 26),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Elementos archivados',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ElementosArchivadosScreen(casa: casa),
              ),
            ),
          ),
          BotonAjustes(casa: casa),
        ],
      ),
      body: StreamBuilder<List<Habitacion>>(
        stream: HabitacionService.streamHabitaciones(casa.id),
        builder: (context, habSnapshot) {
          final habitaciones = habSnapshot.data ?? [];
          return StreamBuilder<List<Elemento>>(
            stream: ElementoService.streamElementos(casa.id),
            builder: (context, elemSnapshot) {
              final elementos = elemSnapshot.data ?? const <Elemento>[];
              final porHabitacion = <String, List<Elemento>>{};
              for (final e in elementos) {
                final hid = e.habitacionId;
                if (hid != null) (porHabitacion[hid] ??= []).add(e);
              }
              final subtituloCasa = habitaciones.isEmpty
                  ? null
                  : '${habitaciones.length} habitaci${habitaciones.length == 1 ? 'ón' : 'ones'} · '
                        '${elementos.length} elemento${elementos.length == 1 ? '' : 's'}';
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (habitaciones.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: context.colors.brandTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.meeting_room_outlined,
                              size: 32,
                              color: context.colors.brand,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Todavía no has añadido ninguna habitación.\nEmpieza por el salón, la cocina o el baño.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: ReparaSpace.s2,
                      ),
                      child: Text(
                        'Habitaciones',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (subtituloCasa != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          subtituloCasa,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 4),
                    ...habitaciones.map(
                      (h) => _HabitacionCard(
                        casa: casa,
                        habitacion: h,
                        elementos: porHabitacion[h.id] ?? const [],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _nuevaHabitacion(context, habitaciones.length),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir habitación'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HabitacionCard extends StatelessWidget {
  const _HabitacionCard({
    required this.casa,
    required this.habitacion,
    required this.elementos,
  });

  final Casa casa;
  final Habitacion habitacion;
  final List<Elemento> elementos;

  @override
  Widget build(BuildContext context) {
    final avisados = elementos
        .where((e) => e.garantiaProximaAVencer || e.revisionPendiente)
        .length;
    final subtitulo = elementos.isEmpty
        ? 'Sin elementos todavía'
        : '${elementos.length} elemento${elementos.length == 1 ? '' : 's'}${avisados > 0 ? ' · $avisados por revisar' : ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: avisados > 0
                  ? context.colors.warning.withValues(alpha: 0.12)
                  : context.colors.brandTint,
              borderRadius: BorderRadius.circular(ReparaRadius.sm),
            ),
            child: Icon(
              Icons.meeting_room_outlined,
              size: 19,
              color: avisados > 0
                  ? context.colors.warning
                  : context.colors.brand,
            ),
          ),
          title: Text(
            habitacion.nombre,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            subtitulo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: avisados > 0 ? context.colors.warningText : null,
              fontWeight: avisados > 0 ? FontWeight.w600 : null,
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            if (elementos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: EmptyHint(
                  message: 'Sin elementos todavía.',
                  icon: Icons.category_outlined,
                ),
              )
            else
              for (var i = 0; i < elementos.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: context.colors.inkMuted.withValues(alpha: 0.14),
                  ),
                _ElementoDeHabitacionRow(casa: casa, elemento: elementos[i]),
              ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NuevoElementoScreen(
                        casa: casa,
                        habitacionIdInicial: habitacion.id,
                      ),
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
  }
}

/// Fila de un elemento dentro de su habitación -- mismo criterio de aviso
/// (ámbar cuando la garantía está próxima o la revisión pendiente) que la
/// fila equivalente de Inicio, para que "algo necesita atención" se lea
/// igual en toda la app en vez de un badge de garantía aislado como antes.
class _ElementoDeHabitacionRow extends StatelessWidget {
  const _ElementoDeHabitacionRow({required this.casa, required this.elemento});

  final Casa casa;
  final Elemento elemento;

  @override
  Widget build(BuildContext context) {
    final avisado =
        elemento.garantiaProximaAVencer || elemento.revisionPendiente;
    final subtitulo = elemento.garantiaProximaAVencer
        ? 'garantía termina pronto'
        : elemento.revisionPendiente
        ? 'revisión pendiente'
        : (elemento.marca != null
              ? '${elemento.marca} ${elemento.modelo ?? ''}'.trim()
              : null);
    return IosRow(
      icon: Icons.category_outlined,
      iconColor: avisado ? context.colors.warning : context.colors.brand,
      imageUrl: elemento.fotoUrl,
      title: elemento.nombre,
      subtitle: subtitulo,
      subtitleColor: avisado ? context.colors.warningText : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ElementoDetailScreen(casa: casa, elementoId: elemento.id),
        ),
      ),
    );
  }
}
