// lib/screens/home_tab.dart
//
// Inicio: registro de Elementos de la casa (octubre 2026, fusión Elemento/
// Trabajo/Evento) -- cada elemento es la unidad que se ve aquí, con su
// propio historial de Registros dentro de su ficha. Arriba, tres accesos
// directos (garantías, mantenimiento, trabajos pendientes) que antes vivían
// en la pestaña Casa -- tienen más sentido en Inicio, que es donde se mira
// a diario (CEO, octubre 2026); debajo, el listado filtrable por ubicación.
import 'package:cached_network_image/cached_network_image.dart';
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

// Saludo según la hora del dispositivo -- sin dato nuevo, nada que no supiera
// ya el propio teléfono; da a Inicio el tono de "bienvenida" que no tiene
// sentido repetir en el resto de fichas (CEO, octubre 2026: "personalidad
// propia, pero que se reconozca como la misma app").
String _saludo() {
  final hora = DateTime.now().hour;
  if (hora < 6) return 'Buenas noches';
  if (hora < 13) return 'Buenos días';
  if (hora < 20) return 'Buenas tardes';
  return 'Buenas noches';
}

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
            Text(
              _saludo(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: context.colors.inkMuted,
              ),
            ),
            Text(
              widget.casa.nombre,
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontSize: 26),
            ),
          ],
        ),
        actions: [
          const BotonNotificaciones(modoPro: false),
          BotonAjustes(casa: widget.casa),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarMenuAnadir(context, casa: widget.casa),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
      // Un único ListView, no un Column con el encabezado fijo arriba y el
      // listado aparte en un Expanded -- antes el resumen, la búsqueda y los
      // filtros nunca se iban de la pantalla por mucho que hubiera scroll,
      // quitándole sitio permanente a los elementos (CEO, octubre 2026: con
      // muchos elementos, la parte de arriba debe desaparecer progresivamente
      // al hacer scroll). Ahora todo vive en el mismo scroll: cabecera y
      // elementos suben juntos, igual que el resto de listas de la app.
      body: StreamBuilder<List<Habitacion>>(
        stream: HabitacionService.streamHabitaciones(widget.casa.id),
        builder: (context, habSnapshot) {
          final habitaciones = habSnapshot.data ?? const <Habitacion>[];
          final nombrePorHabitacion = {
            for (final h in habitaciones) h.id: h.nombre,
          };
          return StreamBuilder<List<Elemento>>(
            stream: ElementoService.streamElementos(
              widget.casa.id,
              habitacionId: _habitacionFiltro,
            ),
            builder: (context, snapshot) {
              var elementos = snapshot.data ?? [];
              if (_busqueda.isNotEmpty) {
                elementos = elementos
                    .where((e) => e.nombre.toLowerCase().contains(_busqueda))
                    .toList();
              }
              return ListView(
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
                      onChanged: (v) =>
                          setState(() => _busqueda = v.trim().toLowerCase()),
                    ),
                  ),
                  if (habitaciones.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todo'),
                              selected: _habitacionFiltro == null,
                              onSelected: (_) =>
                                  setState(() => _habitacionFiltro = null),
                            ),
                            const SizedBox(width: 8),
                            ...habitaciones.map(
                              (h) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(h.nombre),
                                  selected: _habitacionFiltro == h.id,
                                  onSelected: (_) =>
                                      setState(() => _habitacionFiltro = h.id),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (elementos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
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
                              Icons.inventory_2_outlined,
                              size: 32,
                              color: context.colors.brand,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Todavía no hay ningún elemento aquí.\nToca "Añadir" para crear el primero.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: ReparaSpace.s2,
                            ),
                            child: Text(
                              'Tus elementos',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Un único contenedor con filas internas, no una
                          // Card por elemento (CEO: "evita acumular
                          // tarjetas") -- mismo patrón que Historial/
                          // Documentos en registro_detail_screen.dart y
                          // elemento_detail_screen.dart.
                          IosSection(
                            rows: elementos
                                .map(
                                  (e) => _ElementoRow(
                                    casa: widget.casa,
                                    elemento: e,
                                    ubicacion:
                                        nombrePorHabitacion[e.habitacionId],
                                  ),
                                )
                                .toList(),
                          ),
                        ],
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

enum _TipoAviso { garantia, revision }

/// Un único aviso puntual a mostrar -- nunca más de uno, para no convertir
/// Inicio en una lista de alertas (CEO: "destacar lo que de verdad necesita
/// atención, sin convertir todo en alerta").
class _Aviso {
  const _Aviso({
    required this.tipo,
    required this.elemento,
    required this.dias,
  });
  final _TipoAviso tipo;
  final Elemento elemento;
  final int dias;
}

/// Elige el aviso más urgente entre garantías y revisiones -- ninguna de las
/// dos listas llega ordenada desde ElementoService (son solo un `where`, sin
/// orderBy), así que se ordena aquí mismo, en memoria, sin ninguna consulta
/// nueva. "Más urgente" = menos días quedan (o más días de retraso si ya
/// pasó la fecha).
_Aviso? _avisoMasUrgente(List<Elemento> garantias, List<Elemento> revisiones) {
  final ahora = DateTime.now();
  _Aviso? mejor;
  for (final e in garantias) {
    final dias = e.garantiaHasta!.difference(ahora).inDays;
    if (mejor == null || dias < mejor.dias) {
      mejor = _Aviso(tipo: _TipoAviso.garantia, elemento: e, dias: dias);
    }
  }
  for (final e in revisiones) {
    final dias = e.proximoMantenimiento!.difference(ahora).inDays;
    if (mejor == null || dias < mejor.dias) {
      mejor = _Aviso(tipo: _TipoAviso.revision, elemento: e, dias: dias);
    }
  }
  return mejor;
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
          RegistroService.registrosConTrabajoPendiente(casa.id),
        ]),
        builder: (context, snapshot) {
          final garantias = (snapshot.data?[0] as List<Elemento>?) ?? const [];
          final revisiones = (snapshot.data?[1] as List<Elemento>?) ?? const [];
          final pendientes =
              (snapshot.data?[2]
                  as List<
                    ({
                      Elemento elemento,
                      String registroId,
                      String registroTitulo,
                      DateTime fecha,
                      String? fotoUrl,
                    })
                  >?) ??
              const [];
          final todoEnOrden = garantias.isEmpty && revisiones.isEmpty;
          final avisoMasUrgente = _avisoMasUrgente(garantias, revisiones);

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
                            decoration: BoxDecoration(
                              color: context.colors.brandTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              todoEnOrden
                                  ? Icons.home_outlined
                                  : Icons.home_repair_service_outlined,
                              color: context.colors.brand,
                            ),
                          ),
                          const SizedBox(width: ReparaSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  todoEnOrden
                                      ? 'Todo en orden'
                                      : 'Hay cosas que revisar',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
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
                                final elementos =
                                    await ElementoService.conGarantia(casa.id);
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GarantiasProximasScreen(
                                        casa: casa,
                                        elementos: elementos,
                                        titulo: 'Todas las garantías',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: context.colors.border,
                          ),
                          Expanded(
                            child: _MetricTile(
                              icon: Icons.build_circle_outlined,
                              iconColor: context.colors.brand,
                              numero: revisiones.length,
                              numeroColor: context.colors.brand,
                              etiqueta: 'Revisión',
                              onTap: () async {
                                final elementos =
                                    await ElementoService.conMantenimientoConfigurado(
                                      casa.id,
                                    );
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RevisionesPendientesScreen(
                                            casa: casa,
                                            elementos: elementos,
                                            titulo: 'Todo el mantenimiento',
                                          ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: context.colors.border,
                          ),
                          Expanded(
                            child: _MetricTile(
                              icon: Icons.hourglass_top_outlined,
                              iconColor: context.colors.brand,
                              numero: pendientes.length,
                              numeroColor: context.colors.brand,
                              etiqueta: 'En curso',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TrabajosPendientesScreen(
                                    casa: casa,
                                    items: pendientes,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (avisoMasUrgente != null) ...[
                const SizedBox(height: ReparaSpace.s3),
                _BannerAviso(casa: casa, aviso: avisoMasUrgente),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Aviso puntual para lo más urgente de la casa -- garantía o revisión,
/// cualquiera que esté más cerca (o más atrasada). Solo aparece si hay algo
/// real que avisar (_avisoMasUrgente ya filtra por la ventana de aviso),
/// nunca se muestra vacío ni con un mensaje genérico.
class _BannerAviso extends StatelessWidget {
  const _BannerAviso({required this.casa, required this.aviso});

  final Casa casa;
  final _Aviso aviso;

  @override
  Widget build(BuildContext context) {
    final elemento = aviso.elemento;
    final dias = aviso.dias;
    final (icono, mensaje) = switch (aviso.tipo) {
      _TipoAviso.garantia => (
        Icons.verified_outlined,
        dias <= 0
            ? 'La garantía de "${elemento.nombre}" ya ha caducado.'
            : 'La garantía de "${elemento.nombre}" termina en $dias días.',
      ),
      _TipoAviso.revision => (
        Icons.build_circle_outlined,
        dias <= 0
            ? 'La revisión de "${elemento.nombre}" está atrasada.'
            : 'Toca revisar "${elemento.nombre}" en $dias días.',
      ),
    };
    return Material(
      color: context.colors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ReparaRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(ReparaRadius.sm),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ElementoDetailScreen(casa: casa, elementoId: elemento.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ReparaSpace.s3),
          child: Row(
            children: [
              Icon(icono, size: 20, color: context.colors.warningText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensaje,
                  style: TextStyle(
                    color: context.colors.warningText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colors.warningText,
                size: 18,
              ),
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
                Text(
                  '$numero',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 25,
                    color: numeroColor,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  etiqueta.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de un elemento dentro del listado agrupado -- sin Card ni borde
/// propios (antes cada elemento era su propia tarjeta suelta); vive dentro
/// de un IosSection, que ya pone el contenedor único y los divisores. El
/// aviso (ámbar) cubre tanto garantía como revisión próximas, igual que el
/// banner de arriba -- antes solo se destacaba la garantía.
class _ElementoRow extends StatelessWidget {
  const _ElementoRow({
    required this.casa,
    required this.elemento,
    this.ubicacion,
  });

  final Casa casa;
  final Elemento elemento;
  final String? ubicacion;

  @override
  Widget build(BuildContext context) {
    final avisado =
        elemento.garantiaProximaAVencer || elemento.revisionPendiente;
    final subtitulo = [
      ?ubicacion,
      if (elemento.garantiaProximaAVencer)
        'garantía termina pronto'
      else if (elemento.revisionPendiente)
        'revisión pendiente'
      else if (elemento.profesionalNombre != null)
        elemento.profesionalNombre!,
      if (elemento.fechaInstalacion != null)
        DateFormat('d MMM yyyy', 'es_ES').format(elemento.fechaInstalacion!),
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ElementoDetailScreen(casa: casa, elementoId: elemento.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: avisado
                      ? context.colors.warning.withValues(alpha: 0.12)
                      : context.colors.brandTint,
                  borderRadius: BorderRadius.circular(ReparaRadius.sm),
                ),
                child: elemento.fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: elemento.fotoUrl!,
                        fit: BoxFit.cover,
                        // Decodificar a ~3x el tamaño real -- ver nota en
                        // ios_list.dart.
                        memCacheWidth: 140,
                        // Igual que en ios_list.dart: mientras carga (o si
                        // la URL está rota) no debe dejar un hueco en
                        // blanco, cae al mismo icono que el estado sin
                        // foto.
                        placeholder: (context, url) => Icon(
                          Icons.category_outlined,
                          size: 21,
                          color: avisado
                              ? context.colors.warning
                              : context.colors.brand,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.category_outlined,
                          size: 21,
                          color: avisado
                              ? context.colors.warning
                              : context.colors.brand,
                        ),
                      )
                    : Icon(
                        Icons.category_outlined,
                        size: 21,
                        color: avisado
                            ? context.colors.warning
                            : context.colors.brand,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elemento.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (subtitulo.isNotEmpty)
                      Text(
                        subtitulo,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: avisado
                              ? context.colors.warningText
                              : context.colors.inkMuted,
                          fontWeight: avisado
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (elemento.coste != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${elemento.coste!.toStringAsFixed(0)} €',
                  style: ReparaText.amount(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
