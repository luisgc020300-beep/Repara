// lib/screens/pro/inicio_pro_tab.dart
//
// Dashboard profesional (ampliación funcional REPARA Pro, Fase 1 -- CEO,
// noviembre 2026): deja de ser solo "invitaciones pendientes" para
// convertirse en un centro de control real -- KPIs con jerarquía visual,
// "Necesita tu atención" (lo accionable de verdad), actividad reciente y
// accesos rápidos. Todo calculado a partir de datos que ya existen (ver
// trabajo_pro_agregado.dart) -- sin tocar Cloud Functions, reglas ni
// modelos en esta fase.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:repara_core/historial_evento.dart';
import 'package:repara_core/invitacion.dart';
import 'package:repara_core/profesional.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/analytics_service.dart';
import '../../services/historial_service.dart';
import '../../services/invitacion_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/boton_notificaciones.dart';
import '../../widgets/ios_list.dart';
import 'registro_pro_detail_screen.dart';
import 'trabajo_pro_agregado.dart';

const _mensajeInvitarCliente =
    'Llevo el mantenimiento de tus trabajos con Repara -- así queda todo el historial, '
    'presupuestos y fotos organizados en un solo sitio, no perdido entre WhatsApps. '
    'Créate una cuenta gratis y así te puedo mandar presupuestos y avisarte de cambios directamente ahí.';

class InicioProTab extends StatelessWidget {
  const InicioProTab({super.key});

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
              'MODO PROFESIONAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            Text(
              'Repara Pro',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 26,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: const [
          BotonNotificaciones(modoPro: true),
          BotonAjustes(modoPro: true),
        ],
      ),
      body: TrabajosProAgregadosBuilder(
        builder: (context, trabajos, cargando) => ListView(
          padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 24),
          children: [
            _KpisHero(trabajos: trabajos),
            const SizedBox(height: ReparaSpace.s5),
            Text(
              'Invitaciones pendientes',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Invitacion>>(
              stream: InvitacionService.streamPendientesParaMi(),
              builder: (context, snapshot) {
                final invitaciones = snapshot.data ?? [];
                if (invitaciones.isEmpty) {
                  return const EmptyHint(
                    message: 'No tienes invitaciones nuevas.',
                    icon: Icons.mail_outline,
                  );
                }
                return Column(
                  children: invitaciones
                      .map((i) => _InvitacionCard(invitacion: i))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: ReparaSpace.s5),
            Text(
              'Necesita tu atención',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _NecesitaAtencion(trabajos: trabajos, cargando: cargando),
            const SizedBox(height: ReparaSpace.s5),
            Text(
              'Actividad reciente',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _ActividadReciente(trabajos: trabajos),
            const SizedBox(height: ReparaSpace.s5),
            IosSection(
              header: 'Accesos rápidos',
              rows: [
                IosRow(
                  icon: Icons.person_add_alt_outlined,
                  iconColor: context.colors.brand,
                  title: 'Invita a un cliente a Repara',
                  subtitle:
                      'Para que puedas mandarle presupuestos y avisos desde aquí',
                  trailing: Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: context.colors.inkMuted,
                  ),
                  showChevron: false,
                  // sharePositionOrigin obligatorio en iOS -- ver nota en
                  // contacto_acciones.dart.
                  onTap: () => Share.share(
                    _mensajeInvitarCliente,
                    sharePositionOrigin:
                        Offset.zero & MediaQuery.of(context).size,
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

/// Dos tarjetas grandes con lo más accionable (CEO: "no muestres todos los
/// indicadores con el mismo protagonismo"), seguidas de cifras más
/// pequeñas para el resto -- jerarquía visual explícita en vez de una
/// rejilla uniforme de estadísticas.
class _KpisHero extends StatelessWidget {
  const _KpisHero({required this.trabajos});

  final List<TrabajoProAgregado> trabajos;

  @override
  Widget build(BuildContext context) {
    final presupuestosEsperando = trabajos
        .where((t) => t.presupuestoEsperandoRespuesta)
        .length;
    final pendienteCobro = trabajos.fold<double>(
      0,
      (acc, t) => acc + (t.saldoPendiente ?? 0),
    );
    final activos = trabajos
        .where(
          (t) =>
              t.columna != ColumnaTableroPro.terminado &&
              t.columna != ColumnaTableroPro.archivado,
        )
        .length;
    final porEmpezar = trabajos
        .where((t) => t.columna == ColumnaTableroPro.aprobadoPorEmpezar)
        .length;
    final enCurso = trabajos
        .where((t) => t.columna == ColumnaTableroPro.enCurso)
        .length;
    final ahora = DateTime.now();
    final cobradoEsteMes = trabajos.fold<double>(
      0,
      (acc, t) =>
          acc +
          t.pagos
              .where(
                (p) =>
                    p.fecha.year == ahora.year && p.fecha.month == ahora.month,
              )
              .fold<double>(0, (a, p) => a + p.importe),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TarjetaHero(
                icon: Icons.hourglass_top_outlined,
                valor: '$presupuestosEsperando',
                etiqueta: presupuestosEsperando == 1
                    ? 'presupuesto esperando respuesta'
                    : 'presupuestos esperando respuesta',
              ),
            ),
            const SizedBox(width: ReparaSpace.s3),
            Expanded(
              child: _TarjetaHero(
                icon: Icons.payments_outlined,
                valor: '${pendienteCobro.toStringAsFixed(0)} €',
                etiqueta: 'pendiente de cobro',
                destacado: pendienteCobro > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: ReparaSpace.s3),
        Row(
          children: [
            Expanded(
              child: _TarjetaMini(valor: '$activos', etiqueta: 'activos'),
            ),
            const SizedBox(width: ReparaSpace.s2),
            Expanded(
              child: _TarjetaMini(
                valor: '$porEmpezar',
                etiqueta: 'por empezar',
              ),
            ),
            const SizedBox(width: ReparaSpace.s2),
            Expanded(
              child: _TarjetaMini(valor: '$enCurso', etiqueta: 'en curso'),
            ),
            const SizedBox(width: ReparaSpace.s2),
            Expanded(
              child: _TarjetaMini(
                valor: '${cobradoEsteMes.toStringAsFixed(0)} €',
                etiqueta: 'cobrado este mes',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaHero extends StatelessWidget {
  const _TarjetaHero({
    required this.icon,
    required this.valor,
    required this.etiqueta,
    this.destacado = false,
  });

  final IconData icon;
  final String valor;
  final String etiqueta;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final color = destacado ? context.colors.warningText : context.colors.brand;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: ReparaSpace.s2),
            Text(
              valor,
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontSize: 24, color: color),
            ),
            const SizedBox(height: 2),
            Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TarjetaMini extends StatelessWidget {
  const _TarjetaMini({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: ReparaSpace.s3,
          horizontal: ReparaSpace.s2,
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reúne lo que de verdad requiere una acción del profesional -- sin
/// duplicar avisos: cada trabajo aparece como mucho una vez, con el motivo
/// más urgente (ver el orden de comprobación abajo).
class _NecesitaAtencion extends StatelessWidget {
  const _NecesitaAtencion({required this.trabajos, required this.cargando});

  final List<TrabajoProAgregado> trabajos;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    if (cargando) return const SizedBox.shrink();

    final filas = <IosRow>[];
    for (final t in trabajos) {
      final String? motivo;
      final IconData icono;
      final Color color;
      if (t.presupuestoEsperandoRespuesta) {
        motivo = 'Presupuesto esperando respuesta del cliente';
        icono = Icons.hourglass_top_outlined;
        color = context.colors.brand;
      } else if (t.columna == ColumnaTableroPro.aprobadoPorEmpezar) {
        motivo = 'Aprobado -- todavía sin empezar';
        icono = Icons.play_circle_outline;
        color = context.colors.brand;
      } else if (t.columna == ColumnaTableroPro.pendienteConfirmacion) {
        motivo = 'Esperando que el propietario confirme el final';
        icono = Icons.fact_check_outlined;
        color = context.colors.warningText;
      } else if (t.columna == ColumnaTableroPro.pendienteCobro) {
        final saldo = t.saldoPendiente ?? 0;
        motivo = 'Pendiente de cobro -- ${saldo.toStringAsFixed(2)} €';
        icono = Icons.payments_outlined;
        color = context.colors.warningText;
      } else {
        motivo = null;
        icono = Icons.circle;
        color = context.colors.inkMuted;
      }
      if (motivo == null) continue;
      filas.add(
        IosRow(
          icon: icono,
          iconColor: color,
          title: t.ref.registroTitulo,
          subtitle: '${t.ref.casaNombre} · $motivo',
          imageUrl: t.ref.fotoUrl,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RegistroProDetailScreen(
                casaId: t.ref.casaId,
                elementoId: t.ref.elementoId,
                registroId: t.ref.registroId,
              ),
            ),
          ),
        ),
      );
    }

    if (filas.isEmpty) {
      return const EmptyHint(
        message: 'Nada pendiente de tu atención ahora mismo.',
        icon: Icons.check_circle_outline,
      );
    }
    return IosSection(rows: filas);
  }
}

class _EventoActividad {
  const _EventoActividad({
    required this.titulo,
    required this.subtitulo,
    required this.timestamp,
    required this.icon,
  });

  final String titulo;
  final String subtitulo;
  final DateTime timestamp;
  final IconData icon;
}

/// Historial real (no inventado): combina el log append-only de cada
/// trabajo (HistorialService, ya existente) con las invitaciones aceptadas
/// recientes. Fan-out propio, igual que TrabajosProAgregadosController,
/// pero solo mientras este widget está visible -- no merece vivir en el
/// controlador compartido porque Trabajos/Clientes no lo necesitan.
class _ActividadReciente extends StatefulWidget {
  const _ActividadReciente({required this.trabajos});

  final List<TrabajoProAgregado> trabajos;

  @override
  State<_ActividadReciente> createState() => _ActividadRecienteState();
}

class _ActividadRecienteState extends State<_ActividadReciente> {
  final Map<String, StreamSubscription<List<HistorialEvento>>> _subs = {};
  final Map<String, List<HistorialEvento>> _eventosPorTrabajo = {};
  final Map<String, RegistroProRef> _refsPorTrabajo = {};
  StreamSubscription<List<Invitacion>>? _invitacionesSub;
  List<Invitacion> _invitacionesAceptadas = const [];

  @override
  void initState() {
    super.initState();
    _invitacionesSub = InvitacionService.streamAceptadasRecientes().listen((
      lista,
    ) {
      if (!mounted) return;
      setState(() => _invitacionesAceptadas = lista);
    });
    _sincronizar();
  }

  @override
  void didUpdateWidget(covariant _ActividadReciente oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sincronizar();
  }

  void _sincronizar() {
    final idsActuales = widget.trabajos.map((t) => t.ref.registroId).toSet();
    for (final id in _subs.keys.toList()) {
      if (!idsActuales.contains(id)) {
        _subs.remove(id)?.cancel();
        _eventosPorTrabajo.remove(id);
        _refsPorTrabajo.remove(id);
      }
    }
    for (final t in widget.trabajos) {
      _refsPorTrabajo[t.ref.registroId] = t.ref;
      _subs.putIfAbsent(t.ref.registroId, () {
        return HistorialService.streamHistorial(
          t.ref.casaId,
          t.ref.elementoId,
          t.ref.registroId,
        ).listen((lista) {
          if (!mounted) return;
          setState(() => _eventosPorTrabajo[t.ref.registroId] = lista);
        });
      });
    }
  }

  @override
  void dispose() {
    _invitacionesSub?.cancel();
    for (final s in _subs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventos = <_EventoActividad>[];
    _eventosPorTrabajo.forEach((registroId, lista) {
      final ref = _refsPorTrabajo[registroId];
      if (ref == null) return;
      for (final h in lista) {
        final cuando = h.timestamp;
        if (cuando == null) continue;
        eventos.add(
          _EventoActividad(
            titulo: _tituloHistorial(h),
            subtitulo: ref.registroTitulo,
            timestamp: cuando,
            icon: _iconoHistorial(h.entidad),
          ),
        );
      }
    });
    for (final inv in _invitacionesAceptadas) {
      final cuando = inv.createdAt;
      if (cuando == null) continue;
      eventos.add(
        _EventoActividad(
          titulo: 'Invitación aceptada',
          subtitulo: '${inv.registroTitulo} · ${inv.casaNombre}',
          timestamp: cuando,
          icon: Icons.handshake_outlined,
        ),
      );
    }
    eventos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recientes = eventos.take(8).toList();

    if (recientes.isEmpty) {
      return const EmptyHint(
        message: 'Todavía no hay actividad registrada.',
        icon: Icons.history_outlined,
      );
    }
    return IosSection(
      rows: recientes
          .map(
            (e) => IosRow(
              icon: e.icon,
              iconColor: context.colors.brand,
              title: e.titulo,
              subtitle:
                  '${e.subtitulo} · ${DateFormat('d MMM', 'es_ES').format(e.timestamp)}',
              showChevron: false,
            ),
          )
          .toList(),
    );
  }
}

String _tituloHistorial(HistorialEvento h) {
  final importe = h.importe != null
      ? ' (${h.importe!.toStringAsFixed(2)} €)'
      : '';
  return switch (h.entidad) {
    EntidadHistorial.presupuesto => 'Presupuesto ${h.accion}$importe',
    EntidadHistorial.cambioAlcance => 'Cambio de alcance ${h.accion}$importe',
    EntidadHistorial.pago => 'Pago ${h.accion}$importe',
    EntidadHistorial.registro => switch (h.accion) {
      'confirmado' => 'Trabajo confirmado',
      'pendienteConfirmacion' => 'Marcado como terminado',
      'finalizacionRechazada' => 'Finalización rechazada',
      'elementoArchivado' => 'Elemento archivado',
      'elementoRestaurado' => 'Elemento restaurado',
      _ => 'Trabajo actualizado',
    },
    EntidadHistorial.invitacion =>
      h.accion == 'aceptada' ? 'Invitación aceptada' : 'Invitación rechazada',
    EntidadHistorial.documento => 'Documento añadido',
    EntidadHistorial.cita => switch (h.accion) {
      'modificada' => 'Cita modificada',
      'cancelada' => 'Cita cancelada',
      _ => 'Cita programada',
    },
    EntidadHistorial.desconocida => h.accion,
  };
}

IconData _iconoHistorial(EntidadHistorial e) => switch (e) {
  EntidadHistorial.presupuesto => Icons.request_quote_outlined,
  EntidadHistorial.cambioAlcance => Icons.swap_horiz,
  EntidadHistorial.pago => Icons.payments_outlined,
  EntidadHistorial.registro => Icons.task_alt,
  EntidadHistorial.invitacion => Icons.person_add_alt_outlined,
  EntidadHistorial.documento => Icons.description_outlined,
  EntidadHistorial.cita => Icons.event_outlined,
  EntidadHistorial.desconocida => Icons.info_outline,
};

class _InvitacionCard extends StatefulWidget {
  const _InvitacionCard({required this.invitacion});

  final Invitacion invitacion;

  @override
  State<_InvitacionCard> createState() => _InvitacionCardState();
}

class _InvitacionCardState extends State<_InvitacionCard> {
  bool _respondiendo = false;

  Future<void> _responder(bool aceptar) async {
    setState(() => _respondiendo = true);
    try {
      await InvitacionService.responder(widget.invitacion.id, aceptar: aceptar);
      if (aceptar) unawaited(AnalyticsService.professionalInvitationAccepted());
    } catch (e, st) {
      if (mounted) {
        AppError.show(
          context,
          'No se pudo responder a la invitación.',
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
              widget.invitacion.registroTitulo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ReparaSpace.s1),
            Text(
              'en ${widget.invitacion.casaNombre}',
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
