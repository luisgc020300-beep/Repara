// lib/screens/home_tab.dart
//
// Inicio: registro de Elementos de la casa (octubre 2026, fusión Elemento/
// Trabajo/Evento) -- cada elemento es la unidad que se ve aquí, con su
// propio historial de Registros dentro de su ficha. Arriba, avisos de
// garantías/revisiones próximas y un banner de registros en curso con un
// profesional; debajo, el listado filtrable por ubicación.
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
import 'registro_detail_screen.dart';
import 'revisiones_pendientes_screen.dart';

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
          _AvisosCard(casa: widget.casa),
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

/// Las tres señales de "esto necesita tu atención" (garantías, revisiones,
/// registros en curso con un profesional) vivían como tres tarjetas
/// apiladas y empujaban la lista fuera de la pantalla en cuanto había más
/// de una activa a la vez (feedback del CEO, octubre 2026). Ahora son una
/// sola tarjeta plegada por defecto -- una línea si no hay nada que ver,
/// una línea con el recuento si lo hay, y el detalle de cada una solo al
/// tocarla.
class _AvisosCard extends StatelessWidget {
  const _AvisosCard({required this.casa});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Elemento>>>(
      future: Future.wait([
        ElementoService.conGarantiaProximaAVencer(casa.id),
        ElementoService.conRevisionPendiente(casa.id),
      ]),
      builder: (context, snapshot) {
        final garantias = snapshot.data?[0] ?? const <Elemento>[];
        final revisiones = snapshot.data?[1] ?? const <Elemento>[];
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: RegistroService.streamPendientes(casa.id),
          builder: (context, pendSnapshot) {
            final pendientes = pendSnapshot.data ?? const [];
            final numAvisos = (garantias.isNotEmpty ? 1 : 0) + (revisiones.isNotEmpty ? 1 : 0) + (pendientes.isNotEmpty ? 1 : 0);
            if (numAvisos == 0) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(Icons.notifications_active_outlined, color: context.colors.warning),
                    title: Text(
                      numAvisos == 1 ? 'Tienes 1 aviso' : 'Tienes $numAvisos avisos',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    children: [
                      if (garantias.isNotEmpty)
                        _filaAviso(
                          context,
                          icon: Icons.shield_outlined,
                          iconColor: context.colors.warning,
                          texto: garantias.length == 1
                              ? 'La garantía de "${garantias.first.nombre}" termina pronto.'
                              : '${garantias.length} garantías están a punto de terminar.',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => GarantiasProximasScreen(casa: casa, elementos: garantias)),
                          ),
                        ),
                      if (revisiones.isNotEmpty)
                        _filaAviso(
                          context,
                          icon: Icons.build_circle_outlined,
                          iconColor: context.colors.brand,
                          texto: revisiones.length == 1
                              ? 'Toca revisar "${revisiones.first.nombre}".'
                              : '${revisiones.length} elementos tienen una revisión pendiente.',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RevisionesPendientesScreen(casa: casa, elementos: revisiones)),
                          ),
                        ),
                      if (pendientes.isNotEmpty)
                        _filaAviso(
                          context,
                          icon: Icons.hourglass_top_outlined,
                          iconColor: context.colors.brand,
                          texto: pendientes.length == 1
                              ? '1 registro en curso con un profesional.'
                              : '${pendientes.length} registros en curso con un profesional.',
                          // Con más de un pendiente no hay un único registro al
                          // que navegar -- se despliega la lista en vez de
                          // saltar directo, igual que hacía el banner suelto.
                          children: pendientes.length == 1
                              ? null
                              : pendientes
                                  .map((p) => IosRow(
                                        icon: Icons.build_outlined,
                                        iconColor: context.colors.brand,
                                        title: p['registroTitulo'] as String? ?? '',
                                        subtitle: p['elementoNombre'] as String? ?? '',
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RegistroDetailScreen(
                                              casa: casa,
                                              elementoId: p['elementoId'] as String? ?? '',
                                              registroId: p['registroId'] as String? ?? '',
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                          onTap: pendientes.length == 1
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RegistroDetailScreen(
                                        casa: casa,
                                        elementoId: pendientes.first['elementoId'] as String? ?? '',
                                        registroId: pendientes.first['registroId'] as String? ?? '',
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filaAviso(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String texto,
    VoidCallback? onTap,
    List<Widget>? children,
  }) {
    final divisor = Divider(height: 1, indent: 56, color: context.colors.inkMuted.withValues(alpha: 0.14));
    if (children != null) {
      // Sub-lista desplegable dentro de la propia fila (p.ej. varios
      // registros en curso) -- mismo ExpansionTile anidado que ya usaba el
      // banner de pendientes suelto.
      return Column(
        children: [
          divisor,
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(icon, color: iconColor),
              title: Text(texto),
              children: children,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        divisor,
        IosRow(icon: icon, iconColor: iconColor, title: texto, onTap: onTap),
      ],
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
