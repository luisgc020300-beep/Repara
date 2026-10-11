// lib/screens/home_tab.dart
//
// Inicio: registro de Elementos de la casa (octubre 2026, fusión Elemento/
// Trabajo/Evento) -- cada elemento es la unidad que se ve aquí, con su
// propio historial de Registros dentro de su ficha. Arriba, tres accesos
// directos (garantías, mantenimiento, trabajos pendientes) que antes vivían
// en la pestaña Casa -- tienen más sentido en Inicio, que es donde se mira
// a diario (CEO, octubre 2026); debajo, el listado filtrable por ubicación.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import '../services/elemento_service.dart';
import '../services/habitacion_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/boton_notificaciones.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';
import 'garantias_proximas_screen.dart';
import 'menu_anadir.dart';
import 'revisiones_pendientes_screen.dart';
import 'trabajos_pendientes_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({required this.casa, super.key});

  final Casa casa;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _habitacionFiltro;
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.casa.nombre), actions: [const BotonNotificaciones(modoPro: false), BotonAjustes(casa: widget.casa)]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarMenuAnadir(context, casa: widget.casa),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: IosSection(
              rows: [
                IosRow(
                  icon: Icons.shield_outlined,
                  iconColor: context.colors.warning,
                  title: 'Garantías',
                  onTap: () async {
                    final elementos = await ElementoService.conGarantia(widget.casa.id);
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => GarantiasProximasScreen(casa: widget.casa, elementos: elementos, titulo: 'Todas las garantías')));
                    }
                  },
                ),
                IosRow(
                  icon: Icons.build_circle_outlined,
                  iconColor: context.colors.brand,
                  title: 'Mantenimiento',
                  onTap: () async {
                    final elementos = await ElementoService.conMantenimientoConfigurado(widget.casa.id);
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RevisionesPendientesScreen(casa: widget.casa, elementos: elementos, titulo: 'Todo el mantenimiento')));
                    }
                  },
                ),
                IosRow(
                  icon: Icons.hourglass_top_outlined,
                  iconColor: context.colors.brand,
                  title: 'Trabajos pendientes',
                  onTap: () async {
                    final items = await RegistroService.elementosConTrabajoPendiente(widget.casa.id);
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TrabajosPendientesScreen(casa: widget.casa, items: items)));
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar elemento',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
            ),
          ),
          StreamBuilder<List<Habitacion>>(
            stream: HabitacionService.streamHabitaciones(widget.casa.id),
            builder: (context, snapshot) {
              final habitaciones = snapshot.data ?? const [];
              if (habitaciones.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todo'),
                        selected: _habitacionFiltro == null,
                        onSelected: (_) => setState(() => _habitacionFiltro = null),
                      ),
                      const SizedBox(width: 8),
                      ...habitaciones.map((h) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(h.nombre),
                              selected: _habitacionFiltro == h.id,
                              onSelected: (_) => setState(() => _habitacionFiltro = h.id),
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<Elemento>>(
              stream: ElementoService.streamElementos(widget.casa.id, habitacionId: _habitacionFiltro),
              builder: (context, snapshot) {
                var elementos = snapshot.data ?? [];
                if (_busqueda.isNotEmpty) {
                  elementos = elementos.where((e) => e.nombre.toLowerCase().contains(_busqueda)).toList();
                }
                if (elementos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Todavía no hay ningún elemento aquí.\nToca "Añadir" para crear el primero.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.inkMuted),
                      ),
                    ),
                  );
                }
                return StreamBuilder<List<Habitacion>>(
                  stream: HabitacionService.streamHabitaciones(widget.casa.id),
                  builder: (context, habSnapshot) {
                    final nombrePorHabitacion = {for (final h in habSnapshot.data ?? const <Habitacion>[]) h.id: h.nombre};
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        IosSection(
                          rows: elementos
                              .map((e) => _ElementoTile(casa: widget.casa, elemento: e, ubicacion: nombrePorHabitacion[e.habitacionId]))
                              .toList(),
                        ),
                      ],
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

class _ElementoTile extends StatelessWidget {
  const _ElementoTile({required this.casa, required this.elemento, this.ubicacion});

  final Casa casa;
  final Elemento elemento;
  final String? ubicacion;

  @override
  Widget build(BuildContext context) {
    return IosRow(
      icon: Icons.category_outlined,
      iconColor: elemento.garantiaProximaAVencer ? context.colors.warning : context.colors.brand,
      title: elemento.nombre,
      subtitle: [
        ?ubicacion,
        if (elemento.profesionalNombre != null) elemento.profesionalNombre!,
        if (elemento.fechaInstalacion != null) DateFormat('d MMM yyyy', 'es_ES').format(elemento.fechaInstalacion!),
      ].join(' · '),
      trailing: elemento.coste != null ? Text('${elemento.coste!.toStringAsFixed(0)} €') : null,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: elemento.id))),
    );
  }
}
