// lib/screens/pro/trabajos_pro_tab.dart
//
// "Por trabajo" (lista), "Tablero" (columnas por fase) o "Por cliente"
// (agrupado por casa) con el mismo selector. Ampliación funcional REPARA
// Pro, Fase 1 (CEO, noviembre 2026): se añade el Tablero y los filtros
// sobre la base ya existente -- Lista y Por cliente mantienen su
// comportamiento de siempre, solo cambia de dónde sacan los datos (ahora
// vía TrabajosProAgregadosBuilder, que ya trae estado/saldo resueltos en
// vez de que cada vista tuviera que calcularlo por su cuenta).
//
// Rediseño de fidelidad visual (octubre 2026): la vista "Por cliente"
// (_ListaPorCliente) sigue usando Card+ExpansionTile -- igual que
// casa_tab.dart con _HabitacionCard -- tokenizada y alineada con esa misma
// referencia: margen, radio del icono, indentado y color del divisor
// idénticos.
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/app_error.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/ios_list.dart';
import 'registro_pro_detail_screen.dart';
import 'trabajo_pro_agregado.dart';

enum _VistaTrabajosPro { porTrabajo, tablero, porCliente }

enum _FiltroEstadoPro { todos, activos, finalizados, cobroPendiente }

String _nombreFiltro(_FiltroEstadoPro f) => switch (f) {
  _FiltroEstadoPro.todos => 'Todos',
  _FiltroEstadoPro.activos => 'Activos',
  _FiltroEstadoPro.finalizados => 'Finalizados',
  _FiltroEstadoPro.cobroPendiente => 'Cobro pendiente',
};

bool _pasaFiltro(TrabajoProAgregado t, _FiltroEstadoPro f) => switch (f) {
  _FiltroEstadoPro.todos => true,
  _FiltroEstadoPro.activos =>
    t.columna != ColumnaTableroPro.terminado &&
        t.columna != ColumnaTableroPro.archivado,
  _FiltroEstadoPro.finalizados => t.columna == ColumnaTableroPro.terminado,
  _FiltroEstadoPro.cobroPendiente =>
    t.columna == ColumnaTableroPro.pendienteCobro,
};

/// Columnas activas del tablero, en el orden en que avanza un trabajo.
/// `archivado` se deja fuera a propósito -- no tiene sitio en un tablero de
/// trabajo activo (igual que el resto de listas de la app lo ocultan por
/// defecto).
const _columnasTablero = [
  ColumnaTableroPro.sinPresupuestar,
  ColumnaTableroPro.presupuestoEnviado,
  ColumnaTableroPro.aprobadoPorEmpezar,
  ColumnaTableroPro.enCurso,
  ColumnaTableroPro.pendienteConfirmacion,
  ColumnaTableroPro.pendienteCobro,
  ColumnaTableroPro.terminado,
];

class TrabajosProTab extends StatefulWidget {
  const TrabajosProTab({super.key});

  @override
  State<TrabajosProTab> createState() => _TrabajosProTabState();
}

class _TrabajosProTabState extends State<TrabajosProTab> {
  _VistaTrabajosPro _vista = _VistaTrabajosPro.porTrabajo;
  _FiltroEstadoPro _filtro = _FiltroEstadoPro.activos;
  ColumnaTableroPro _columnaSeleccionada = ColumnaTableroPro.sinPresupuestar;

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
              'Trabajos',
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
        builder: (context, todos, cargando) {
          if (!cargando && todos.isEmpty) return const _EstadoVacio();

          final filtrados = _vista == _VistaTrabajosPro.porCliente
              ? todos
              : todos.where((t) => _pasaFiltro(t, _filtro)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ReparaSpace.s4,
                  ReparaSpace.s3,
                  ReparaSpace.s4,
                  ReparaSpace.s1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Lista'),
                        selected: _vista == _VistaTrabajosPro.porTrabajo,
                        onSelected: (_) => setState(
                          () => _vista = _VistaTrabajosPro.porTrabajo,
                        ),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Tablero'),
                        selected: _vista == _VistaTrabajosPro.tablero,
                        onSelected: (_) =>
                            setState(() => _vista = _VistaTrabajosPro.tablero),
                      ),
                    ),
                    const SizedBox(width: ReparaSpace.s2),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Por cliente'),
                        selected: _vista == _VistaTrabajosPro.porCliente,
                        onSelected: (_) => setState(
                          () => _vista = _VistaTrabajosPro.porCliente,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_vista != _VistaTrabajosPro.porCliente)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ReparaSpace.s4,
                    0,
                    ReparaSpace.s4,
                    ReparaSpace.s2,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in _FiltroEstadoPro.values) ...[
                          ChoiceChip(
                            label: Text(_nombreFiltro(f)),
                            selected: _filtro == f,
                            onSelected: (_) => setState(() => _filtro = f),
                          ),
                          const SizedBox(width: ReparaSpace.s2),
                        ],
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: switch (_vista) {
                  _VistaTrabajosPro.porTrabajo => _ListaPorTrabajo(
                    trabajos: filtrados,
                  ),
                  _VistaTrabajosPro.tablero => _Tablero(
                    trabajos: filtrados,
                    columnaSeleccionada: _columnaSeleccionada,
                    onColumnaSeleccionada: (c) =>
                        setState(() => _columnaSeleccionada = c),
                  ),
                  _VistaTrabajosPro.porCliente => _ListaPorCliente(
                    trabajos: todos,
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ReparaSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.colors.brandTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_outlined,
                size: 32,
                color: context.colors.brand,
              ),
            ),
            const SizedBox(height: ReparaSpace.s4),
            Text(
              'Aquí gestionas cada trabajo entero (presupuesto, cambios, pagos, documentos) en cuanto aceptes una invitación.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

void _abrirTrabajo(BuildContext context, TrabajoProAgregado t) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RegistroProDetailScreen(
        casaId: t.ref.casaId,
        elementoId: t.ref.elementoId,
        registroId: t.ref.registroId,
      ),
    ),
  );
}

class _ListaPorTrabajo extends StatelessWidget {
  const _ListaPorTrabajo({required this.trabajos});

  final List<TrabajoProAgregado> trabajos;

  @override
  Widget build(BuildContext context) {
    if (trabajos.isEmpty) {
      return const EmptyHint(
        message: 'Ningún trabajo con este filtro.',
        icon: Icons.filter_alt_off_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ReparaSpace.s4,
        0,
        ReparaSpace.s4,
        ReparaSpace.s4,
      ),
      children: [
        IosSection(
          rows: trabajos
              .map(
                (t) => IosRow(
                  icon: Icons.build_outlined,
                  iconColor: context.colors.brand,
                  imageUrl: t.ref.fotoUrl,
                  title: t.ref.registroTitulo,
                  subtitle:
                      '${t.ref.casaNombre} · ${nombreColumnaTableroPro(t.columna)}',
                  onTap: () => _abrirTrabajo(context, t),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Tablero por fases -- en vez de columnas horizontales con scroll infinito
/// (incómodo en móvil), un selector de fase + la lista de esa fase sola,
/// tal como decidió el plan de esta ampliación.
class _Tablero extends StatelessWidget {
  const _Tablero({
    required this.trabajos,
    required this.columnaSeleccionada,
    required this.onColumnaSeleccionada,
  });

  final List<TrabajoProAgregado> trabajos;
  final ColumnaTableroPro columnaSeleccionada;
  final ValueChanged<ColumnaTableroPro> onColumnaSeleccionada;

  @override
  Widget build(BuildContext context) {
    final porColumna = <ColumnaTableroPro, List<TrabajoProAgregado>>{
      for (final c in _columnasTablero) c: [],
    };
    for (final t in trabajos) {
      if (t.columna == ColumnaTableroPro.archivado) continue;
      porColumna[t.columna]?.add(t);
    }

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: ReparaSpace.s4),
            children: [
              for (final c in _columnasTablero) ...[
                ChoiceChip(
                  label: Text(
                    '${nombreColumnaTableroPro(c)} (${porColumna[c]?.length ?? 0})',
                  ),
                  selected: columnaSeleccionada == c,
                  onSelected: (_) => onColumnaSeleccionada(c),
                ),
                const SizedBox(width: ReparaSpace.s2),
              ],
            ],
          ),
        ),
        const SizedBox(height: ReparaSpace.s2),
        Expanded(
          child: Builder(
            builder: (context) {
              final lista = porColumna[columnaSeleccionada] ?? [];
              if (lista.isEmpty) {
                return const EmptyHint(
                  message: 'Nada en esta fase ahora mismo.',
                  icon: Icons.inbox_outlined,
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  ReparaSpace.s4,
                  0,
                  ReparaSpace.s4,
                  ReparaSpace.s4,
                ),
                children: [
                  IosSection(
                    rows: lista
                        .map(
                          (t) => IosRow(
                            icon: Icons.build_outlined,
                            iconColor: context.colors.brand,
                            imageUrl: t.ref.fotoUrl,
                            title: t.ref.registroTitulo,
                            subtitle: t.ref.casaNombre,
                            trailing: (t.saldoPendiente ?? 0) > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${t.saldoPendiente!.toStringAsFixed(2)} €',
                                        style: ReparaText.amount(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        color: context.colors.inkMuted,
                                        size: 20,
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: () => _abrirTrabajo(context, t),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ListaPorCliente extends StatelessWidget {
  const _ListaPorCliente({required this.trabajos});

  final List<TrabajoProAgregado> trabajos;

  @override
  Widget build(BuildContext context) {
    final porCasa = <String, List<TrabajoProAgregado>>{};
    for (final t in trabajos) {
      porCasa.putIfAbsent(t.ref.casaId, () => []).add(t);
    }
    final casas = porCasa.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        ReparaSpace.s4,
        0,
        ReparaSpace.s4,
        ReparaSpace.s4,
      ),
      itemCount: casas.length,
      itemBuilder: (context, i) {
        final entry = casas[i];
        final trabajosDeEstaCasa = entry.value;
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
                  color: context.colors.brandTint,
                  borderRadius: BorderRadius.circular(ReparaRadius.sm),
                ),
                child: Icon(
                  Icons.house_outlined,
                  size: 19,
                  color: context.colors.brand,
                ),
              ),
              title: Text(
                trabajosDeEstaCasa.first.ref.casaNombre,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${trabajosDeEstaCasa.length} trabajo${trabajosDeEstaCasa.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              childrenPadding: const EdgeInsets.only(bottom: ReparaSpace.s2),
              children: [
                for (var i = 0; i < trabajosDeEstaCasa.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: context.colors.inkMuted.withValues(alpha: 0.14),
                    ),
                  IosRow(
                    icon: Icons.build_outlined,
                    iconColor: context.colors.brand,
                    imageUrl: trabajosDeEstaCasa[i].ref.fotoUrl,
                    title: trabajosDeEstaCasa[i].ref.registroTitulo,
                    subtitle: nombreColumnaTableroPro(
                      trabajosDeEstaCasa[i].columna,
                    ),
                    onTap: () => _abrirTrabajo(context, trabajosDeEstaCasa[i]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
