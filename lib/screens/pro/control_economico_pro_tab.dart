// lib/screens/pro/control_economico_pro_tab.dart
//
// Control económico (ampliación funcional REPARA Pro, Fase 2 -- CEO,
// noviembre 2026): visión económica agregada de toda la actividad del
// profesional. NO es contabilidad fiscal ni sustituye a un programa de
// facturación -- solo responde "cuánto he acordado cobrar, cuánto he
// cobrado de verdad y cuánto me queda pendiente", separando con cuidado
// los conceptos (presupuestado ≠ acordado ≠ cobrado, un cambio de alcance
// aprobado no es un ingreso, un pago nunca se cuenta dos veces).
//
// Fórmula verificada línea a línea contra functions/index.js antes de
// construir esta pantalla (ver el plan de esta fase): registro.presupuesto
// YA incluye el presupuesto aceptado + los cambios de alcance aprobados
// (el servidor los suma con FieldValue.increment) -- por eso
// TrabajoProAgregado.montoDebido es la única fuente de "importe acordado",
// y cambiosAprobados/importePresupuestado aquí son solo para MOSTRAR el
// desglose, nunca para recalcular cuánto se debe.
//
// Absorbe también la vista "todos mis presupuestos agrupados por estado"
// que antes era su propia pestaña (presupuestos_pro_tab.dart, retirada al
// añadir esta pantalla y Clientes -- Ajustes del CEO sobre la navegación
// de 5 áreas, sin Agenda todavía).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/presupuesto.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/ios_list.dart';
import 'registro_pro_detail_screen.dart';
import 'trabajo_pro_agregado.dart';

enum _Periodo { esteMes, mesAnterior, ultimosTresMeses, esteAnio, todo }

String _nombrePeriodo(_Periodo p) => switch (p) {
  _Periodo.esteMes => 'Este mes',
  _Periodo.mesAnterior => 'Mes anterior',
  _Periodo.ultimosTresMeses => 'Últimos 3 meses',
  _Periodo.esteAnio => 'Este año',
  _Periodo.todo => 'Todo',
};

/// Rango [desde, hasta) del período -- null en cualquiera de los dos
/// extremos significa "sin límite" (caso de "Todo").
(DateTime?, DateTime?) _rangoPeriodo(_Periodo p, DateTime ahora) {
  final inicioMes = DateTime(ahora.year, ahora.month);
  return switch (p) {
    _Periodo.esteMes => (inicioMes, DateTime(ahora.year, ahora.month + 1)),
    _Periodo.mesAnterior => (DateTime(ahora.year, ahora.month - 1), inicioMes),
    _Periodo.ultimosTresMeses => (
      DateTime(ahora.year, ahora.month - 2),
      DateTime(ahora.year, ahora.month + 1),
    ),
    _Periodo.esteAnio => (DateTime(ahora.year), DateTime(ahora.year + 1)),
    _Periodo.todo => (null, null),
  };
}

const _ordenGruposPresupuesto = [
  EstadoPresupuesto.enviado,
  EstadoPresupuesto.borrador,
  EstadoPresupuesto.aceptado,
  EstadoPresupuesto.rechazado,
  EstadoPresupuesto.cancelado,
];

String _nombreGrupoPresupuesto(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.enviado => 'Esperando respuesta',
  EstadoPresupuesto.borrador => 'Borradores sin enviar',
  EstadoPresupuesto.aceptado => 'Aceptados',
  EstadoPresupuesto.rechazado => 'Rechazados',
  EstadoPresupuesto.cancelado => 'Cancelados',
};

IconData _iconoGrupoPresupuesto(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.enviado => Icons.hourglass_top_outlined,
  EstadoPresupuesto.borrador => Icons.edit_note_outlined,
  EstadoPresupuesto.aceptado => Icons.check_circle_outline,
  EstadoPresupuesto.rechazado => Icons.cancel_outlined,
  EstadoPresupuesto.cancelado => Icons.block_outlined,
};

class ControlEconomicoProTab extends StatefulWidget {
  const ControlEconomicoProTab({super.key});

  @override
  State<ControlEconomicoProTab> createState() => _ControlEconomicoProTabState();
}

class _ControlEconomicoProTabState extends State<ControlEconomicoProTab> {
  _Periodo _periodo = _Periodo.esteMes;

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
              'Económico',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 26,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: const [BotonAjustes(modoPro: true)],
      ),
      body: TrabajosProAgregadosBuilder(
        builder: (context, trabajos, cargando) {
          if (cargando) return const Center(child: CircularProgressIndicator());
          final activos = trabajos
              .where(
                (t) =>
                    t.columna != ColumnaTableroPro.archivado &&
                    t.registro != null,
              )
              .toList();
          final ahora = DateTime.now();
          final (desde, hasta) = _rangoPeriodo(_periodo, ahora);

          double cobradoEnPeriodo(TrabajoProAgregado t) => t.pagos
              .where(
                (p) =>
                    (desde == null || !p.fecha.isBefore(desde)) &&
                    (hasta == null || p.fecha.isBefore(hasta)),
              )
              .fold<double>(0, (acc, p) => acc + p.importe);

          final importeAcordado = activos.fold<double>(
            0,
            (acc, t) => acc + (t.montoDebido ?? 0),
          );
          final importePresupuestado = activos.fold<double>(
            0,
            (acc, t) => acc + t.importePresupuestado,
          );
          final cambiosAprobados = activos.fold<double>(
            0,
            (acc, t) => acc + t.cambiosAprobados,
          );
          final totalCobradoPeriodo = activos.fold<double>(
            0,
            (acc, t) => acc + cobradoEnPeriodo(t),
          );
          final pendienteCobro = activos.fold<double>(
            0,
            (acc, t) => acc + (t.saldoPendiente ?? 0),
          );
          final trabajosConSaldo = activos
              .where((t) => (t.saldoPendiente ?? 0) > 0)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, ReparaSpace.s4, 16, 24),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in _Periodo.values) ...[
                      ChoiceChip(
                        label: Text(_nombrePeriodo(p)),
                        selected: _periodo == p,
                        onSelected: (_) => setState(() => _periodo = p),
                      ),
                      const SizedBox(width: ReparaSpace.s2),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: ReparaSpace.s4),
              Row(
                children: [
                  Expanded(
                    child: _TarjetaKpi(
                      icon: Icons.handshake_outlined,
                      valor: '${importeAcordado.toStringAsFixed(0)} €',
                      etiqueta: 'importe acordado',
                    ),
                  ),
                  const SizedBox(width: ReparaSpace.s3),
                  Expanded(
                    child: _TarjetaKpi(
                      icon: Icons.payments_outlined,
                      valor: '${totalCobradoPeriodo.toStringAsFixed(0)} €',
                      etiqueta:
                          'cobrado (${_nombrePeriodo(_periodo).toLowerCase()})',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s3),
              Row(
                children: [
                  Expanded(
                    child: _TarjetaKpi(
                      icon: Icons.hourglass_bottom_outlined,
                      valor: '${pendienteCobro.toStringAsFixed(0)} €',
                      etiqueta: 'pendiente de cobro',
                      destacado: pendienteCobro > 0,
                    ),
                  ),
                  const SizedBox(width: ReparaSpace.s3),
                  Expanded(
                    child: _TarjetaKpi(
                      icon: Icons.warning_amber_outlined,
                      valor: '${trabajosConSaldo.length}',
                      etiqueta: 'trabajos con saldo pendiente',
                      destacado: trabajosConSaldo.isNotEmpty,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s5),
              Text(
                'Desglose',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              IosSection(
                rows: [
                  IosValueRow(
                    label: 'Presupuestado',
                    value: '${importePresupuestado.toStringAsFixed(2)} €',
                  ),
                  IosValueRow(
                    label: 'Cambios de alcance aprobados',
                    value: '${cambiosAprobados.toStringAsFixed(2)} €',
                  ),
                  IosValueRow(
                    label: 'Importe acordado',
                    value: '${importeAcordado.toStringAsFixed(2)} €',
                    destacado: true,
                  ),
                  IosValueRow(
                    label: 'Total cobrado',
                    value:
                        '${activos.fold<double>(0, (acc, t) => acc + t.totalPagado).toStringAsFixed(2)} €',
                  ),
                  IosValueRow(
                    label: 'Pendiente de cobro',
                    value: '${pendienteCobro.toStringAsFixed(2)} €',
                  ),
                ],
              ),
              const SizedBox(height: ReparaSpace.s5),
              Text(
                'Evolución de cobros (últimos 6 meses)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              _GraficoEvolucionCobros(activos: activos, ahora: ahora),
              const SizedBox(height: ReparaSpace.s5),
              Text(
                'Distribución de trabajos por estado',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              _DistribucionPorEstado(activos: activos),
              const SizedBox(height: ReparaSpace.s5),
              Text(
                'Trabajos con saldo pendiente',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (trabajosConSaldo.isEmpty)
                const EmptyHint(
                  message: 'Nada pendiente de cobro ahora mismo.',
                  icon: Icons.check_circle_outline,
                )
              else
                IosSection(
                  rows: trabajosConSaldo
                      .map(
                        (t) => IosRow(
                          icon: Icons.payments_outlined,
                          iconColor: context.colors.warningText,
                          imageUrl: t.ref.fotoUrl,
                          title: t.ref.registroTitulo,
                          subtitle: t.ref.casaNombre,
                          trailing: Text(
                            '${t.saldoPendiente!.toStringAsFixed(2)} €',
                            style: ReparaText.amount(context),
                          ),
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
                      )
                      .toList(),
                ),
              const SizedBox(height: ReparaSpace.s5),
              Text(
                'Presupuestos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              _PresupuestosPorEstado(
                activos: trabajos.where((t) => t.registro != null).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaKpi extends StatelessWidget {
  const _TarjetaKpi({
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
              ).textTheme.displayMedium?.copyWith(fontSize: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Barra mensual de cobros (suma real de Pago.importe por mes, nunca un
/// valor estimado) -- gráfico sencillo a propósito, sin ejes que puedan
/// inducir a conclusiones incorrectas con pocos datos.
class _GraficoEvolucionCobros extends StatelessWidget {
  const _GraficoEvolucionCobros({required this.activos, required this.ahora});

  final List<TrabajoProAgregado> activos;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final meses = List.generate(
      6,
      (i) => DateTime(ahora.year, ahora.month - 5 + i),
    );
    final totalesPorMes = meses.map((mes) {
      return activos.fold<double>(
        0,
        (acc, t) =>
            acc +
            t.pagos
                .where(
                  (p) => p.fecha.year == mes.year && p.fecha.month == mes.month,
                )
                .fold<double>(0, (a, p) => a + p.importe),
      );
    }).toList();
    final maxY = totalesPorMes.fold<double>(0, (a, b) => b > a ? b : a);

    if (maxY == 0) {
      return const EmptyHint(
        message: 'Sin cobros registrados todavía.',
        icon: Icons.bar_chart_outlined,
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReparaSpace.s2,
          ReparaSpace.s4,
          ReparaSpace.s4,
          ReparaSpace.s2,
        ),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= meses.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _nombreMesCorto(meses[i]),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < meses.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: totalesPorMes[i],
                        color: context.colors.brand,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _nombreMesCorto(DateTime d) => const [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
][d.month - 1];

/// Reparto por columna del tablero, como barras horizontales proporcionales
/// -- más legible que un circular con muchas franjas pequeñas cuando hay
/// pocos trabajos.
class _DistribucionPorEstado extends StatelessWidget {
  const _DistribucionPorEstado({required this.activos});

  final List<TrabajoProAgregado> activos;

  @override
  Widget build(BuildContext context) {
    if (activos.isEmpty) {
      return const EmptyHint(
        message: 'Sin trabajos activos todavía.',
        icon: Icons.donut_large_outlined,
      );
    }
    final porColumna = <ColumnaTableroPro, int>{};
    for (final t in activos) {
      porColumna[t.columna] = (porColumna[t.columna] ?? 0) + 1;
    }
    final maximo = porColumna.values.fold<int>(0, (a, b) => b > a ? b : a);
    final entradas = porColumna.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s4),
        child: Column(
          children: [
            for (final e in entradas)
              Padding(
                padding: const EdgeInsets.only(bottom: ReparaSpace.s2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        nombreColumnaTableroPro(e.key),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maximo == 0 ? 0 : e.value / maximo,
                          minHeight: 10,
                          backgroundColor: context.colors.surfaceMuted,
                          color: context.colors.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Text(
                      '${e.value}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresupuestoConTrabajo {
  const _PresupuestoConTrabajo({
    required this.presupuesto,
    required this.trabajo,
  });
  final Presupuesto presupuesto;
  final TrabajoProAgregado trabajo;
}

/// Absorbe la vista que antes era la pestaña "Presupuestos" -- mismo
/// agrupado por estado, misma fórmula de orden, ahora como sección dentro
/// de Control económico en vez de pantalla propia.
class _PresupuestosPorEstado extends StatelessWidget {
  const _PresupuestosPorEstado({required this.activos});

  final List<TrabajoProAgregado> activos;

  @override
  Widget build(BuildContext context) {
    final todos = <_PresupuestoConTrabajo>[];
    for (final t in activos) {
      for (final p in t.presupuestos) {
        todos.add(_PresupuestoConTrabajo(presupuesto: p, trabajo: t));
      }
    }
    if (todos.isEmpty) {
      return const EmptyHint(
        message: 'Todavía no has creado ningún presupuesto.',
        icon: Icons.request_quote_outlined,
      );
    }

    final grupos = <EstadoPresupuesto, List<_PresupuestoConTrabajo>>{
      for (final e in EstadoPresupuesto.values) e: [],
    };
    for (final item in todos) {
      grupos[item.presupuesto.estado]!.add(item);
    }

    return Column(
      children: [
        for (final estado in _ordenGruposPresupuesto)
          if (grupos[estado]!.isNotEmpty)
            IosSection(
              header:
                  '${_nombreGrupoPresupuesto(estado)} (${grupos[estado]!.length})',
              rows: grupos[estado]!
                  .map(
                    (item) => IosRow(
                      icon: _iconoGrupoPresupuesto(item.presupuesto.estado),
                      iconColor: context.colors.brand,
                      title: item.trabajo.ref.registroTitulo,
                      subtitle:
                          '${item.trabajo.ref.casaNombre} · Presupuesto nº${item.presupuesto.numero}${item.presupuesto.version > 1 ? ' (v${item.presupuesto.version})' : ''}',
                      trailing: Text(
                        '${item.presupuesto.total.toStringAsFixed(2)} €',
                        style: ReparaText.amount(context),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegistroProDetailScreen(
                            casaId: item.trabajo.ref.casaId,
                            elementoId: item.trabajo.ref.elementoId,
                            registroId: item.trabajo.ref.registroId,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
      ],
    );
  }
}
