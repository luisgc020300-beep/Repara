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
                      'Todavía no has creado ningún presupuesto.\nCréalo desde el detalle de un trabajo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.inkMuted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final estado in _ordenGrupos)
                      if (grupos[estado]!.isNotEmpty) ...[
                        _CabeceraGrupo(estado: estado, cantidad: grupos[estado]!.length),
                        const SizedBox(height: 8),
                        ...grupos[estado]!.map((item) => _PresupuestoTile(
                              item: item,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TrabajoProDetailScreen(casaId: item.trabajo.casaId, trabajoId: item.trabajo.trabajoId),
                                ),
                              ),
                            )),
                        const SizedBox(height: 16),
                      ],
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

class _CabeceraGrupo extends StatelessWidget {
  const _CabeceraGrupo({required this.estado, required this.cantidad});

  final EstadoPresupuesto estado;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final (texto, color, icono) = switch (estado) {
      EstadoPresupuesto.enviado => ('Esperando respuesta', context.colors.brand, Icons.hourglass_top_outlined),
      EstadoPresupuesto.borrador => ('Borradores sin enviar', context.colors.inkMuted, Icons.edit_note_outlined),
      EstadoPresupuesto.aceptado => ('Aceptados', context.colors.success, Icons.check_circle_outline),
      EstadoPresupuesto.rechazado => ('Rechazados', context.colors.error, Icons.cancel_outlined),
      EstadoPresupuesto.cancelado => ('Cancelados', context.colors.inkMuted, Icons.block_outlined),
    };
    return Row(
      children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 8),
        Text('$texto ($cantidad)', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _PresupuestoTile extends StatelessWidget {
  const _PresupuestoTile({required this.item, required this.onTap});

  final _PresupuestoConTrabajo item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = item.presupuesto;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.request_quote_outlined),
        title: Text(item.trabajo.trabajoTitulo),
        subtitle: Text('${item.trabajo.casaNombre} · Presupuesto nº${p.numero}${p.version > 1 ? ' (v${p.version})' : ''}'),
        trailing: Text('${p.total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
