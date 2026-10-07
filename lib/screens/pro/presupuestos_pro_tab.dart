// lib/screens/pro/presupuestos_pro_tab.dart
//
// Vista agregada de TODOS los presupuestos del profesional, agrupados por
// estado -- a diferencia de "Trabajos" (que lista los trabajos en sí), aquí
// se ve de un vistazo qué presupuestos están esperando respuesta del
// cliente, cuáles son borradores sin enviar y cuáles ya se cerraron.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/presupuesto.dart';
import '../../models/profesional.dart';
import '../../services/presupuesto_service.dart';
import '../../services/profesional_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/boton_ajustes.dart';
import '../../widgets/ios_list.dart';
import 'trabajo_pro_detail_screen.dart';

class PresupuestosProTab extends StatefulWidget {
  const PresupuestosProTab({super.key});

  @override
  State<PresupuestosProTab> createState() => _PresupuestosProTabState();
}

class _PresupuestoConTrabajo {
  const _PresupuestoConTrabajo({required this.presupuesto, required this.trabajo});
  final Presupuesto presupuesto;
  final TrabajoProRef trabajo;
}

class _PresupuestosProTabState extends State<PresupuestosProTab> {
  StreamSubscription<List<TrabajoProRef>>? _trabajosSub;
  final Map<String, StreamSubscription<List<Presupuesto>>> _presupuestoSubs = {};
  final Map<String, TrabajoProRef> _trabajosPorId = {};
  final Map<String, List<Presupuesto>> _presupuestosPorTrabajo = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _trabajosSub = ProfesionalService.streamTrabajosProRefs().listen(_onTrabajos);
  }

  // Cada trabajo tiene su propia subcolección de presupuestos -- no existe
  // una consulta única "todos mis presupuestos" (el profesional no es
  // miembro de ninguna casa, ver firestore.rules), así que se escucha un
  // stream de presupuestos por cada trabajo asignado y se combinan aquí.
  void _onTrabajos(List<TrabajoProRef> trabajos) {
    final idsActuales = trabajos.map((t) => t.trabajoId).toSet();
    for (final id in _presupuestoSubs.keys.toList()) {
      if (!idsActuales.contains(id)) {
        _presupuestoSubs.remove(id)?.cancel();
        _presupuestosPorTrabajo.remove(id);
        _trabajosPorId.remove(id);
      }
    }
    for (final t in trabajos) {
      _trabajosPorId[t.trabajoId] = t;
      _presupuestoSubs.putIfAbsent(t.trabajoId, () {
        return PresupuestoService.streamPresupuestos(t.casaId, t.trabajoId).listen((lista) {
          if (!mounted) return;
          setState(() => _presupuestosPorTrabajo[t.trabajoId] = lista);
        });
      });
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _trabajosSub?.cancel();
    for (final sub in _presupuestoSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todos = <_PresupuestoConTrabajo>[];
    _presupuestosPorTrabajo.forEach((trabajoId, lista) {
      final trabajo = _trabajosPorId[trabajoId];
      if (trabajo == null) return;
      for (final p in lista) {
        todos.add(_PresupuestoConTrabajo(presupuesto: p, trabajo: trabajo));
      }
    });

    final grupos = <EstadoPresupuesto, List<_PresupuestoConTrabajo>>{
      for (final e in EstadoPresupuesto.values) e: [],
    };
    for (final item in todos) {
      grupos[item.presupuesto.estado]!.add(item);
    }
    for (final lista in grupos.values) {
      lista.sort((a, b) => _fechaOrden(b.presupuesto).compareTo(_fechaOrden(a.presupuesto)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos'), actions: const [BotonAjustes(modoPro: true)]),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : todos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aquí verás, de un vistazo, el estado de TODOS tus presupuestos (esperando respuesta, aceptados, rechazados...) sin entrar trabajo por trabajo.\nCréalo desde el detalle de un trabajo, en la pestaña Trabajos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.inkMuted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final estado in _ordenGrupos)
                      if (grupos[estado]!.isNotEmpty)
                        IosSection(
                          header: '${_nombreGrupo(estado)} (${grupos[estado]!.length})',
                          rows: grupos[estado]!
                              .map((item) => _PresupuestoTile(
                                    item: item,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrabajoProDetailScreen(casaId: item.trabajo.casaId, trabajoId: item.trabajo.trabajoId),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                  ],
                ),
    );
  }
}

// Esperando respuesta primero (lo más accionable para el profesional),
// luego lo que aún no se ha enviado, y por último lo ya cerrado.
const _ordenGrupos = [
  EstadoPresupuesto.enviado,
  EstadoPresupuesto.borrador,
  EstadoPresupuesto.aceptado,
  EstadoPresupuesto.rechazado,
  EstadoPresupuesto.cancelado,
];

DateTime _fechaOrden(Presupuesto p) => p.fechaRespuesta ?? p.fechaEnvio ?? p.fechaCreacion ?? DateTime(2000);

String _nombreGrupo(EstadoPresupuesto e) => switch (e) {
      EstadoPresupuesto.enviado => 'Esperando respuesta',
      EstadoPresupuesto.borrador => 'Borradores sin enviar',
      EstadoPresupuesto.aceptado => 'Aceptados',
      EstadoPresupuesto.rechazado => 'Rechazados',
      EstadoPresupuesto.cancelado => 'Cancelados',
    };

Color _colorGrupo(BuildContext context, EstadoPresupuesto e) => switch (e) {
      EstadoPresupuesto.enviado => context.colors.brand,
      EstadoPresupuesto.borrador => context.colors.inkMuted,
      EstadoPresupuesto.aceptado => context.colors.success,
      EstadoPresupuesto.rechazado => context.colors.error,
      EstadoPresupuesto.cancelado => context.colors.inkMuted,
    };

IconData _iconoGrupo(EstadoPresupuesto e) => switch (e) {
      EstadoPresupuesto.enviado => Icons.hourglass_top_outlined,
      EstadoPresupuesto.borrador => Icons.edit_note_outlined,
      EstadoPresupuesto.aceptado => Icons.check_circle_outline,
      EstadoPresupuesto.rechazado => Icons.cancel_outlined,
      EstadoPresupuesto.cancelado => Icons.block_outlined,
    };

class _PresupuestoTile extends StatelessWidget {
  const _PresupuestoTile({required this.item, required this.onTap});

  final _PresupuestoConTrabajo item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = item.presupuesto;
    return IosRow(
      icon: _iconoGrupo(p.estado),
      iconColor: _colorGrupo(context, p.estado),
      title: item.trabajo.trabajoTitulo,
      subtitle: '${item.trabajo.casaNombre} · Presupuesto nº${p.numero}${p.version > 1 ? ' (v${p.version})' : ''}',
      trailing: Text('${p.total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: onTap,
    );
  }
}
