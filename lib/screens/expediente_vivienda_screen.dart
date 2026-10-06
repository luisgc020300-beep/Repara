// lib/screens/expediente_vivienda_screen.dart
//
// Expediente de la vivienda (auditoría de producto, octubre 2026): un
// resumen generado en el momento -- no una pantalla que se consulta a
// diario -- pensado para los momentos de verdadero valor (vender la casa,
// renovar el seguro, pedir financiación para una reforma). Prototipo v1:
// resumen en pantalla + compartir como texto. La exportación a PDF real
// queda para cuando haya demanda real de pagar por ella (ver sección de
// monetización de la auditoría) -- no se ha añadido ninguna dependencia
// nueva solo para esto.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/trabajo.dart';
import '../services/analytics_service.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';

class ExpedienteViviendaScreen extends StatelessWidget {
  const ExpedienteViviendaScreen({required this.casa, super.key});

  final Casa casa;

  Future<void> _compartir(BuildContext context, List<Elemento> elementos, List<Trabajo> trabajos, int numDocumentos) async {
    final buffer = StringBuffer()
      ..writeln('EXPEDIENTE DE LA VIVIENDA · ${casa.nombre}')
      ..writeln('Generado el ${DateFormat('d MMMM yyyy', 'es_ES').format(DateTime.now())}')
      ..writeln();

    if (elementos.isNotEmpty) {
      buffer.writeln('ELEMENTOS (${elementos.length})');
      for (final e in elementos) {
        final detalle = [
          if (e.marca != null) '${e.marca} ${e.modelo ?? ''}'.trim(),
          if (e.fechaInstalacion != null) 'instalado ${DateFormat('MM/yyyy').format(e.fechaInstalacion!)}',
          if (e.garantiaHasta != null) 'garantía hasta ${DateFormat('MM/yyyy').format(e.garantiaHasta!)}',
          if (e.coste != null) '${e.coste!.toStringAsFixed(0)} €',
        ].join(' · ');
        buffer.writeln('- ${e.nombre}${detalle.isNotEmpty ? ' ($detalle)' : ''}');
      }
      buffer.writeln();
    }

    final finalizados = trabajos.where((t) => t.estado == EstadoTrabajo.terminado || t.estado == EstadoTrabajo.archivado).toList();
    if (finalizados.isNotEmpty) {
      buffer.writeln('TRABAJOS REALIZADOS (${finalizados.length})');
      for (final t in finalizados) {
        final detalle = [
          if (t.profesionalNombre != null) t.profesionalNombre!,
          if (t.presupuesto != null) '${t.presupuesto!.toStringAsFixed(0)} €',
        ].join(' · ');
        buffer.writeln('- ${t.titulo}${detalle.isNotEmpty ? ' ($detalle)' : ''}');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('DOCUMENTOS GUARDADOS: $numDocumentos')
      ..writeln()
      ..writeln('Generado con Repara.');

    try {
      await Share.share(buffer.toString(), subject: 'Expediente de ${casa.nombre}');
      unawaited(AnalyticsService.householdRecordShared());
    } catch (e) {
      // El resumen ya se ve en pantalla -- que falle el selector de
      // compartir no debe parecer que algo se ha roto.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expediente de la vivienda')),
      body: FutureBuilder(
        future: Future.wait([
          ElementoService.streamElementos(casa.id).first,
          TrabajoService.streamTrabajos(casa.id).first,
          DocumentoService.streamTodos(casa.id).first,
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final elementos = snapshot.data![0] as List<Elemento>;
          final trabajos = snapshot.data![1] as List<Trabajo>;
          final documentos = snapshot.data![2] as List<Documento>;
          final finalizados = trabajos.where((t) => t.estado == EstadoTrabajo.terminado || t.estado == EstadoTrabajo.archivado).toList();
          final conGarantiaVigente = elementos.where((e) => e.garantiaHasta != null && e.garantiaHasta!.isAfter(DateTime.now())).length;
          final costeTotal = finalizados.fold<double>(0, (acc, t) => acc + (t.presupuesto ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Un resumen de todo lo que hay registrado en Repara sobre esta vivienda -- útil para vender la casa, renovar el seguro o pedir financiación para una reforma.',
                style: TextStyle(color: context.colors.inkMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _Estadistica(valor: '${elementos.length}', etiqueta: 'Elementos')),
                  Expanded(child: _Estadistica(valor: '${finalizados.length}', etiqueta: 'Trabajos')),
                  Expanded(child: _Estadistica(valor: '$conGarantiaVigente', etiqueta: 'Garantías vigentes')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _Estadistica(valor: '${documentos.length}', etiqueta: 'Documentos')),
                  Expanded(child: _Estadistica(valor: '${costeTotal.toStringAsFixed(0)} €', etiqueta: 'Invertido en trabajos')),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 24),
              if (elementos.isNotEmpty) ...[
                _seccion(context, 'Elementos'),
                ...elementos.map((e) => _FilaResumen(
                      titulo: e.nombre,
                      subtitulo: [
                        if (e.marca != null) '${e.marca} ${e.modelo ?? ''}'.trim(),
                        if (e.garantiaHasta != null) 'garantía hasta ${DateFormat('MM/yyyy').format(e.garantiaHasta!)}',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      valor: e.coste != null ? '${e.coste!.toStringAsFixed(0)} €' : null,
                    )),
                const SizedBox(height: 16),
              ],
              if (finalizados.isNotEmpty) ...[
                _seccion(context, 'Trabajos realizados'),
                ...finalizados.map((t) => _FilaResumen(
                      titulo: t.titulo,
                      subtitulo: t.profesionalNombre ?? '',
                      valor: t.presupuesto != null ? '${t.presupuesto!.toStringAsFixed(0)} €' : null,
                    )),
                const SizedBox(height: 16),
              ],
              if (elementos.isEmpty && finalizados.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Todavía no hay suficientes datos para generar un expediente útil.', style: TextStyle(color: context.colors.inkMuted)),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _compartir(context, elementos, trabajos, documentos.length),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Compartir resumen'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seccion(BuildContext context, String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Estadistica extends StatelessWidget {
  const _Estadistica({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.brand)),
            const SizedBox(height: 2),
            Text(etiqueta, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: context.colors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.titulo, required this.subtitulo, this.valor});

  final String titulo;
  final String subtitulo;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitulo.isNotEmpty ? Text(subtitulo) : null,
        trailing: valor != null ? Text(valor!, style: const TextStyle(fontWeight: FontWeight.w700)) : null,
      ),
    );
  }
}
