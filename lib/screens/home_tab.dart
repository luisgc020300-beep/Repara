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
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('TU CASA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.colors.inkMuted)),
            Text(widget.casa.nombre, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26)),
          ],
        ),
        actions: [const BotonNotificaciones(modoPro: false), BotonAjustes(casa: widget.casa)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarMenuAnadir(context, casa: widget.casa),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
      body: Column(
        children: [
          _ResumenCasa(casa: widget.casa),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                            child: Icon(Icons.inventory_2_outlined, size: 32, color: context.colors.brand),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Todavía no hay ningún elemento aquí.\nToca "Añadir" para crear el primero.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.colors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return StreamBuilder<List<Habitacion>>(
                  stream: HabitacionService.streamHabitaciones(widget.casa.id),
                  builder: (context, habSnapshot) {
                    final nombrePorHabitacion = {for (final h in habSnapshot.data ?? const <Habitacion>[]) h.id: h.nombre};
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: ReparaSpace.s2),
                          child: Text('Tus elementos', style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        ...elementos.map((e) => _ElementoTile(casa: widget.casa, elemento: e, ubicacion: nombrePorHabitacion[e.habitacionId])),
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

/// Resumen de Inicio (añadido al adaptar el rediseño "REPARA Professional"
/// al código real): antes solo estaban las 3 tiles de acceso rápido -- el
/// maquetado de referencia abre con una tarjeta de estado general y, si
/// hace falta, un aviso puntual debajo de las tiles. Nunca se inventa el
/// mensaje "todo en orden" cuando no es cierto: ambas piezas salen de los
/// mismos datos reales que ya alimentaban las tiles, en una sola consulta.
class _ResumenCasa extends StatelessWidget {
  const _ResumenCasa({required this.casa});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, ReparaSpace.s4),
      child: FutureBuilder(
        future: Future.wait([
          ElementoService.conGarantiaProximaAVencer(casa.id),
          ElementoService.conRevisionPendiente(casa.id),
          RegistroService.elementosConTrabajoPendiente(casa.id),
        ]),
        builder: (context, snapshot) {
          final garantias = (snapshot.data?[0] as List<Elemento>?) ?? const [];
          final revisiones = (snapshot.data?[1] as List<Elemento>?) ?? const [];
          final pendientes = (snapshot.data?[2] as List<({Elemento elemento, String registroTitulo, DateTime fecha})>?) ?? const [];
          final todoEnOrden = garantias.isEmpty && revisiones.isEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Una sola tarjeta para estado + métricas -- antes eran 4
              // tarjetas sueltas (estado + 3 tiles) apiladas con huecos entre
              // ellas, que se leían como piezas independientes en vez de un
              // resumen único (briefing "REPARA Professional": "deben
              // percibirse como una unidad coherente").
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ReparaSpace.s4),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: context.colors.brandTint, shape: BoxShape.circle),
                            child: Icon(
                              todoEnOrden ? Icons.home_outlined : Icons.home_repair_service_outlined,
                              color: context.colors.brand,
                            ),
                          ),
                          const SizedBox(width: ReparaSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  todoEnOrden ? 'Todo en orden' : 'Hay cosas que revisar',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  todoEnOrden
                                      ? 'Tu vivienda, organizada.'
                                      : 'Garantías o revisiones que necesitan tu atención.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: context.colors.border),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              icon: Icons.shield_outlined,
                              iconColor: context.colors.warning,
                              numero: garantias.length,
                              numeroColor: context.colors.warningText,
                              etiqueta: 'Garantías',
                              onTap: () async {
                                final elementos = await ElementoService.conGarantia(casa.id);
                                if (context.mounted) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => GarantiasProximasScreen(casa: casa, elementos: elementos, titulo: 'Todas las garantías')));
                                }
                              },
                            ),
                          ),
                          VerticalDivider(width: 1, thickness: 1, color: context.colors.border),
                          Expanded(
                            child: _MetricTile(
                              icon: Icons.build_circle_outlined,
                              iconColor: context.colors.brand,
                              numero: revisiones.length,
                              numeroColor: context.colors.brand,
                              etiqueta: 'Revisión',
                              onTap: () async {
                                final elementos = await ElementoService.conMantenimientoConfigurado(casa.id);
                                if (context.mounted) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => RevisionesPendientesScreen(casa: casa, elementos: elementos, titulo: 'Todo el mantenimiento')));
                                }
                              },
                            ),
                          ),
                          VerticalDivider(width: 1, thickness: 1, color: context.colors.border),
                          Expanded(
                            child: _MetricTile(
                              icon: Icons.hourglass_top_outlined,
                              iconColor: context.colors.brand,
                              numero: pendientes.length,
                              numeroColor: context.colors.brand,
                              etiqueta: 'En curso',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrabajosPendientesScreen(casa: casa, items: pendientes))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (garantias.isNotEmpty) ...[
                const SizedBox(height: ReparaSpace.s3),
                _BannerGarantia(casa: casa, elemento: garantias.first),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Aviso puntual para la garantía más próxima a vencer -- solo aparece si
/// hay alguna (conGarantiaProximaAVencer ya filtra por la ventana de
/// aviso), nunca se muestra vacío ni con un mensaje genérico.
class _BannerGarantia extends StatelessWidget {
  const _BannerGarantia({required this.casa, required this.elemento});

  final Casa casa;
  final Elemento elemento;

  @override
  Widget build(BuildContext context) {
    final dias = elemento.garantiaHasta!.difference(DateTime.now()).inDays;
    return Material(
      color: context.colors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ReparaRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(ReparaRadius.sm),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: elemento.id))),
        child: Padding(
          padding: const EdgeInsets.all(ReparaSpace.s3),
          child: Row(
            children: [
              Icon(Icons.verified_outlined, size: 20, color: context.colors.warningText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dias <= 0
                      ? 'La garantía de "${elemento.nombre}" ya ha caducado.'
                      : 'La garantía de "${elemento.nombre}" termina en $dias días.',
                  style: TextStyle(color: context.colors.warningText, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, color: context.colors.warningText, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un tercio de la fila de métricas dentro de la tarjeta única de resumen --
/// sin Card ni borde propios (antes cada una era su propia tarjeta); el
/// InkWell ocupa toda la altura de la fila gracias al IntrinsicHeight del
/// padre, así el área tocable sigue siendo tan grande como antes.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.numero,
    required this.numeroColor,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final int numero;
  final Color numeroColor;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: '$etiqueta: $numero',
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: iconColor),
                const SizedBox(height: 6),
                Text('$numero', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 25, color: numeroColor, height: 1)),
                const SizedBox(height: 6),
                Text(
                  etiqueta.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10.5, letterSpacing: 0.4, color: context.colors.inkMuted),
                ),
              ],
            ),
          ),
        ),
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
    final avisado = elemento.garantiaProximaAVencer;
    final subtitulo = [
      ?ubicacion,
      if (avisado) 'garantía termina pronto' else if (elemento.profesionalNombre != null) elemento.profesionalNombre!,
      if (elemento.fechaInstalacion != null) DateFormat('d MMM yyyy', 'es_ES').format(elemento.fechaInstalacion!),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(ReparaRadius.md),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: elemento.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: avisado ? context.colors.warning.withValues(alpha: 0.12) : context.colors.brandTint,
                  borderRadius: BorderRadius.circular(ReparaRadius.sm),
                ),
                child: elemento.fotoUrl != null
                    ? Image.network(elemento.fotoUrl!, fit: BoxFit.cover)
                    : Icon(Icons.category_outlined, size: 20, color: avisado ? context.colors.warning : context.colors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(elemento.nombre, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitulo.isNotEmpty)
                      Text(
                        subtitulo,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: avisado ? context.colors.warningText : context.colors.inkMuted,
                              fontWeight: avisado ? FontWeight.w600 : FontWeight.w500,
                            ),
                      ),
                  ],
                ),
              ),
              if (elemento.coste != null) Text('${elemento.coste!.toStringAsFixed(0)} €', style: ReparaText.amount(context)),
            ],
          ),
        ),
      ),
    );
  }
}
