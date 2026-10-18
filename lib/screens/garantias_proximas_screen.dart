// lib/screens/garantias_proximas_screen.dart
//
// Lista de garantías -- puede ser solo las que vencen en los próximos 30
// días (desde el aviso de Inicio) o todas las que hay guardadas (desde la
// tarjeta "Garantías" de Inicio, título "Todas las garantías"). En el
// segundo caso cada fila distingue su propio estado (próxima a vencer /
// vigente sin prisa / ya caducada) en vez de pintarlas todas igual de
// urgentes -- si no, un listado de "todas" parece confirmar que las 6 están
// a punto de caducar cuando solo 3 lo están de verdad (CEO, octubre 2026).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../theme/design_tokens.dart';
import '../widgets/ios_list.dart';
import 'elemento_detail_screen.dart';

enum _EstadoGarantia { proxima, vigente, caducada }

class GarantiasProximasScreen extends StatelessWidget {
  const GarantiasProximasScreen({required this.casa, required this.elementos, this.titulo = 'Garantías a punto de terminar', super.key});

  final Casa casa;
  final List<Elemento> elementos;
  final String titulo;

  static _EstadoGarantia _estado(Elemento e) {
    if (e.garantiaProximaAVencer) return _EstadoGarantia.proxima;
    if (e.garantiaHasta != null && e.garantiaHasta!.isBefore(DateTime.now())) return _EstadoGarantia.caducada;
    return _EstadoGarantia.vigente;
  }

  List<Elemento> get _ordenados {
    final copia = [...elementos];
    copia.sort((a, b) {
      final estadoA = _estado(a).index;
      final estadoB = _estado(b).index;
      if (estadoA != estadoB) return estadoA.compareTo(estadoB);
      if (a.garantiaHasta == null || b.garantiaHasta == null) return 0;
      return a.garantiaHasta!.compareTo(b.garantiaHasta!);
    });
    return copia;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo, style: Theme.of(context).textTheme.displaySmall)),
      body: elementos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(Icons.shield_outlined, size: 32, color: context.colors.warning),
                    ),
                    const SizedBox(height: 16),
                    Text('Ningún elemento tiene una garantía guardada todavía.', textAlign: TextAlign.center, style: TextStyle(color: context.colors.inkMuted)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [IosSection(rows: _ordenados.map((e) => _FilaGarantia(casa: casa, elemento: e, estado: _estado(e))).toList())],
            ),
    );
  }
}

class _FilaGarantia extends StatelessWidget {
  const _FilaGarantia({required this.casa, required this.elemento, required this.estado});

  final Casa casa;
  final Elemento elemento;
  final _EstadoGarantia estado;

  @override
  Widget build(BuildContext context) {
    final (Color color, String etiqueta) = switch (estado) {
      _EstadoGarantia.proxima => (context.colors.warningText, 'Termina el'),
      _EstadoGarantia.vigente => (context.colors.brand, 'Vigente hasta'),
      _EstadoGarantia.caducada => (context.colors.inkMuted, 'Caducó el'),
    };
    final colorInsignia = estado == _EstadoGarantia.proxima ? context.colors.warning : context.colors.brand;
    return IosRow(
      icon: Icons.shield_outlined,
      iconColor: colorInsignia,
      title: elemento.nombre,
      subtitle: elemento.garantiaHasta != null ? '$etiqueta ${DateFormat('d MMMM yyyy', 'es_ES').format(elemento.garantiaHasta!)}' : null,
      subtitleColor: elemento.garantiaHasta != null ? color : null,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElementoDetailScreen(casa: casa, elementoId: elemento.id))),
    );
  }
}
