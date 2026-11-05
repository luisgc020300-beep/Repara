// lib/screens/home_tab.dart
//
// Inicio: registro de Elementos de la casa (octubre 2026, fusión Elemento/
// Trabajo/Evento) -- cada elemento es la unidad que se ve aquí, con su
// propio historial de Registros dentro de su ficha. Arriba, tres accesos
// directos (garantías, mantenimiento, trabajos pendientes) que antes vivían
// en la pestaña Casa -- tienen más sentido en Inicio, que es donde se mira
// a diario (CEO, octubre 2026); debajo, el listado filtrable por ubicación.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import '../models/invitacion_hogar.dart';
import '../services/elemento_service.dart';
import '../services/habitacion_service.dart';
import '../services/invitacion_hogar_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/boton_ajustes.dart';
import '../widgets/boton_notificaciones.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';
import 'garantias_proximas_screen.dart';
import 'menu_anadir.dart';
import 'registro_detail_screen.dart' show RegistroDetailScreen;
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

// Nunca un nombre inventado -- memberProfiles lo rellena el servidor al
// crear/unirse a la casa (ver functions/index.js), así que si no hay nadie
// autenticado o su perfil no está (todavía) en memberProfiles, el saludo se
// queda sin nombre en vez de simular uno. try/catch porque acceder a
// FirebaseAuth.instance sin una app de Firebase inicializada (los widget
// tests no la inicializan, solo FakeFirebaseFirestore) lanza -- mismo límite
// de sistema que ya protegen con debugUidOverride los servicios con sesión.
String? _nombreUsuarioActual(Casa casa) {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null ? casa.memberProfiles[uid]?.displayName : null;
  } catch (_) {
    return null;
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({required this.casa, this.refreshTick, super.key});

  final Casa casa;
  // Se incrementa cada vez que se vuelve a esta pestaña (ver
  // casa_shell_screen.dart) -- _ResumenCasa lo escucha para relanzar su
  // Future.wait, que si no se queda obsoleto mientras HomeTab sigue
  // montado por _KeepAlivePage. Opcional (null en los sitios que no lo
  // necesitan, p.ej. tests) -- sin él, _ResumenCasa simplemente no se
  // refresca más que al construirse la primera vez.
  final ValueListenable<int>? refreshTick;

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
    // Sin Scaffold.appBar (CEO, noviembre 2026: "⌂ REPARA" debe vivir sobre
    // el mismo bloque navy que el saludo, pegado a la barra de estado, no en
    // una barra separada encima) -- AnnotatedRegion fuerza los iconos de la
    // barra de estado (hora, batería, señal) a blanco, ya que se pintan
    // sobre el degradado oscuro de _CabeceraNavy en vez de sobre el fondo
    // claro/oscuro normal del tema.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
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
                  padding: EdgeInsets.zero,
                  children: [
                    _CabeceraNavy(casa: widget.casa),
                    _SolicitudesProfesionales(casa: widget.casa),
                    _ResumenCasa(
                      casa: widget.casa,
                      refreshTick: widget.refreshTick,
                    ),
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
                                    onSelected: (_) => setState(
                                      () => _habitacionFiltro = h.id,
                                    ),
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
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
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
      ),
    );
  }
}

/// "Solicitudes de profesionales" (Fase 2, noviembre 2026): un profesional
/// quiere vincular un trabajo privado suyo a esta cuenta. Espejo de
/// "Invitaciones pendientes" en inicio_pro_tab.dart, pero solo se muestra
/// si hay alguna -- a diferencia de Inicio Pro, aquí no tiene sentido un
/// bloque permanente de "no tienes solicitudes" (CEO: "destacar lo que de
/// verdad necesita atención"). Al aceptar, se usa SIEMPRE la casa que se
/// está viendo (widget.casa) -- si el propietario tiene más de una casa y
/// quiere este trabajo en otra, tiene que cambiar de casa primero.
class _SolicitudesProfesionales extends StatelessWidget {
  const _SolicitudesProfesionales({required this.casa});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InvitacionHogar>>(
      stream: InvitacionHogarService.streamPendientesParaMi(),
      builder: (context, snapshot) {
        final solicitudes = snapshot.data ?? const [];
        if (solicitudes.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitudes de profesionales',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              ...solicitudes.map(
                (s) => _SolicitudProfesionalCard(solicitud: s, casa: casa),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SolicitudProfesionalCard extends StatefulWidget {
  const _SolicitudProfesionalCard({required this.solicitud, required this.casa});

  final InvitacionHogar solicitud;
  final Casa casa;

  @override
  State<_SolicitudProfesionalCard> createState() =>
      _SolicitudProfesionalCardState();
}

class _SolicitudProfesionalCardState
    extends State<_SolicitudProfesionalCard> {
  bool _respondiendo = false;

  Future<void> _responder(bool aceptar) async {
    setState(() => _respondiendo = true);
    try {
      final vinculo = await InvitacionHogarService.responder(
        widget.solicitud.id,
        aceptar: aceptar,
        casaId: aceptar ? widget.casa.id : null,
      );
      if (aceptar && vinculo != null && mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => RegistroDetailScreen(
              casa: widget.casa,
              elementoId: vinculo.elementoId,
              registroId: vinculo.registroId,
            ),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo responder a la solicitud.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _respondiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: ReparaSpace.s2),
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.solicitud.titulo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ReparaSpace.s1),
            Text(
              widget.solicitud.profesionalNombre != null
                  ? 'de ${widget.solicitud.profesionalNombre} -- se guardará en "${widget.casa.nombre}"'
                  : 'se guardará en "${widget.casa.nombre}"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ReparaSpace.s3),
            _respondiendo
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _responder(false),
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: ReparaSpace.s2),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _responder(true),
                          child: const Text('Aceptar'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
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
  const _ResumenCasa({required this.casa, this.refreshTick});

  final Casa casa;
  final ValueListenable<int>? refreshTick;

  @override
  Widget build(BuildContext context) {
    final tick = refreshTick;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, ReparaSpace.s4),
      child: tick == null
          ? _futureBuilder(context)
          : ValueListenableBuilder<int>(
              valueListenable: tick,
              builder: (context, value, child) => _futureBuilder(context),
            ),
    );
  }

  // Future.wait nuevo en cada reconstrucción -- volver a Inicio incrementa
  // refreshTick, lo que reconstruye este FutureBuilder con una lectura
  // fresca en vez de quedarse con la de la primera vez que se montó
  // HomeTab (ver nota de _homeRefreshTick en casa_shell_screen.dart).
  Widget _futureBuilder(BuildContext context) {
    return FutureBuilder(
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
        final avisoMasUrgente = _avisoMasUrgente(garantias, revisiones);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.shield_outlined,
                    iconColor: context.colors.warning,
                    numero: garantias.length,
                    etiqueta: 'Garantías',
                    destacado: garantias.isNotEmpty,
                    onTap: () async {
                      final elementos = await ElementoService.conGarantia(
                        casa.id,
                      );
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
                const SizedBox(width: ReparaSpace.s2),
                Expanded(
                  child: _StatCard(
                    icon: Icons.build_circle_outlined,
                    iconColor: context.colors.brand,
                    numero: revisiones.length,
                    etiqueta: 'Revisión',
                    destacado: revisiones.isNotEmpty,
                    onTap: () async {
                      final elementos =
                          await ElementoService.conMantenimientoConfigurado(
                            casa.id,
                          );
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RevisionesPendientesScreen(
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
                const SizedBox(width: ReparaSpace.s2),
                Expanded(
                  child: _StatCard(
                    icon: Icons.hourglass_top_outlined,
                    iconColor: context.colors.brand,
                    numero: pendientes.length,
                    etiqueta: 'En curso',
                    destacado: pendientes.isNotEmpty,
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
            if (avisoMasUrgente != null) ...[
              const SizedBox(height: ReparaSpace.s3),
              _BannerAviso(casa: casa, aviso: avisoMasUrgente),
            ],
          ],
        );
      },
    );
  }
}

/// Banner de bienvenida (rediseño visual, noviembre 2026) -- sustituye a la
/// tarjeta "Todo en orden"/"Hay cosas que revisar": un solo bloque navy desde
/// la barra de estado (CEO, noviembre 2026: "el icono y REPARA deben vivir
/// sobre el mismo fondo azul marino que el saludo, no en una barra blanca
/// aparte") -- SafeArea solo inset-ea el contenido, el Container de fondo
/// sigue pintando detrás de la barra de estado. Marca + notificaciones +
/// ajustes arriba, saludo por hora del día (_saludo(), antes en el AppBar)
/// más el nombre real del usuario (de memberProfiles, que el servidor ya
/// rellena al crear/unirse a la casa -- nunca un nombre inventado) y el
/// nombre real de la casa debajo. Sin foto de fondo: Casa no tiene ningún
/// campo de foto de vivienda, así que en vez de simular una se usa el mismo
/// degradado de marca que antes solo llevaba la tarjeta de saludo.
class _CabeceraNavy extends StatelessWidget {
  const _CabeceraNavy({required this.casa});

  final Casa casa;

  @override
  Widget build(BuildContext context) {
    final saludo = _saludo();
    final nombreUsuario = _nombreUsuarioActual(casa);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.brandStrong, context.colors.brand],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(ReparaRadius.lg),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'REPARA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconTheme.merge(
                    data: const IconThemeData(color: Colors.white),
                    child: BotonNotificaciones(modoPro: false, casa: casa),
                  ),
                  IconTheme.merge(
                    data: const IconThemeData(color: Colors.white),
                    child: BotonAjustes(casa: casa),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                nombreUsuario != null && nombreUsuario.isNotEmpty
                    ? '$saludo, $nombreUsuario'
                    : saludo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                casa.nombre,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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

/// Tarjeta propia por métrica (rediseño visual, noviembre 2026) -- antes las
/// tres vivían como tercios de una única Card con divisores internos; ahora
/// cada una es su propia tarjeta redondeada, con fondo tenue cuando
/// [destacado] (hay algo real que mirar) para que destaque sin inventar un
/// color nuevo -- reutiliza el mismo [iconColor] semántico que ya tenía cada
/// métrica, solo como fondo en vez de solo como icono.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.numero,
    required this.etiqueta,
    required this.destacado,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final int numero;
  final String etiqueta;
  final bool destacado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: destacado ? iconColor.withValues(alpha: 0.08) : null,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: '$etiqueta: $numero',
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '$numero',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 22, height: 1),
                ),
                const SizedBox(height: 4),
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
