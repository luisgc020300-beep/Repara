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

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/registro.dart';
import '../services/analytics_service.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';

double? _costeRegistro(Registro r) => r.esConProfesional ? r.presupuesto : r.coste;

class ExpedienteViviendaScreen extends StatelessWidget {
  const ExpedienteViviendaScreen({required this.casa, super.key});

  final Casa casa;

  /// Un registro nunca vive en una colección a nivel de casa (octubre 2026,
  /// fusión Elemento/Trabajo/Evento) -- se agrega aquí leyendo la
  /// subcolección de cada elemento, no con una consulta collectionGroup
  /// (ver firestore.rules: esa vía quedó descartada por limitaciones reales
  /// del propio Firestore, no solo de sintaxis).
  Future<List<Registro>> _todosLosRegistros(List<Elemento> elementos) async {
    final porElemento = await Future.wait(elementos.map((e) => RegistroService.streamRegistros(casa.id, e.id).first));
    return porElemento.expand((lista) => lista).toList();
  }

  Future<void> _compartir(BuildContext context, List<Elemento> elementos, List<Registro> registros, int numDocumentos) async {
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

    final finalizados = _finalizados(registros);
    if (finalizados.isNotEmpty) {
      buffer.writeln('REGISTROS (${finalizados.length})');
      for (final r in finalizados) {
        final coste = _costeRegistro(r);
        final detalle = [
          if (r.profesionalNombre != null) r.profesionalNombre!,
          if (coste != null) '${coste.toStringAsFixed(0)} €',
        ].join(' · ');
        buffer.writeln('- ${r.titulo}${detalle.isNotEmpty ? ' ($detalle)' : ''}');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('DOCUMENTOS GUARDADOS: $numDocumentos')
      ..writeln()
      ..writeln('Generado con Repara.');

    try {
      // A diferencia del "compartir" decorativo de otras pantallas (invitar
      // a un amigo, donde que falle es indiferente), aquí el botón ES la
      // función principal de esta pantalla -- si falla, el usuario no tiene
      // otra forma de sacar el expediente del teléfono, así que un catch
      // silencioso lo dejaba sin saber que no había pasado nada (auditoría
      // de producto, octubre 2026: "le he dado al botón y no hace nada").
      // ShareResultStatus.unavailable NO se trata como fallo -- según la
      // propia documentación del paquete significa que la plataforma SÍ
      // compartió el contenido, solo que no se puede saber qué eligió el
      // usuario; tratarlo como error habría disparado un aviso falso en
      // cada el uso normal donde esa información no está disponible.
      await Share.share(buffer.toString(), subject: 'Expediente de ${casa.nombre}');
      unawaited(AnalyticsService.householdRecordShared());
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (context.mounted) AppError.show(context, 'No se pudo abrir el selector para compartir.');
    }
  }

  List<Registro> _finalizados(List<Registro> registros) =>
      registros.where((r) => !r.esConProfesional || r.estado == EstadoRegistro.terminado || r.estado == EstadoRegistro.archivado).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expediente de la vivienda')),
      body: FutureBuilder<List<Elemento>>(
        future: ElementoService.streamElementos(casa.id).first,
        builder: (context, elementosSnapshot) {
          if (!elementosSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final elementos = elementosSnapshot.data!;
          return FutureBuilder(
            future: Future.wait([_todosLosRegistros(elementos), DocumentoService.streamTodos(casa.id).first]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final registros = snapshot.data![0] as List<Registro>;
              final documentos = snapshot.data![1] as List<Documento>;
              final finalizados = _finalizados(registros);
              final conGarantiaVigente = elementos.where((e) => e.garantiaHasta != null && e.garantiaHasta!.isAfter(DateTime.now())).length;
              final costeTotal = finalizados.fold<double>(0, (acc, r) => acc + (_costeRegistro(r) ?? 0));
              return _cuerpo(context, elementos, finalizados, documentos, conGarantiaVigente, costeTotal, registros);
            },
          );
        },
      ),
    );
  }

  Widget _cuerpo(
    BuildContext context,
    List<Elemento> elementos,
    List<Registro> finalizados,
    List<Documento> documentos,
    int conGarantiaVigente,
    double costeTotal,
    List<Registro> registros,
  ) {
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
            Expanded(child: _Estadistica(valor: '${finalizados.length}', etiqueta: 'Registros')),
            Expanded(child: _Estadistica(valor: '$conGarantiaVigente', etiqueta: 'Garantías vigentes')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Estadistica(valor: '${documentos.length}', etiqueta: 'Documentos')),
            Expanded(child: _Estadistica(valor: '${costeTotal.toStringAsFixed(0)} €', etiqueta: 'Invertido en registros')),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 8),
        if (elementos.isNotEmpty)
          IosSection(
            header: 'Elementos',
            rows: elementos
                .map((e) => _filaResumen(
                      context,
                      titulo: e.nombre,
                      subtitulo: [
                        if (e.marca != null) '${e.marca} ${e.modelo ?? ''}'.trim(),
                        if (e.garantiaHasta != null) 'garantía hasta ${DateFormat('MM/yyyy').format(e.garantiaHasta!)}',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      valor: e.coste != null ? '${e.coste!.toStringAsFixed(0)} €' : null,
                    ))
                .toList(),
          ),
        if (finalizados.isNotEmpty)
          IosSection(
            header: 'Registros',
            rows: finalizados
                .map((r) => _filaResumen(
                      context,
                      titulo: r.titulo,
                      subtitulo: r.profesionalNombre ?? '',
                      valor: _costeRegistro(r) != null ? '${_costeRegistro(r)!.toStringAsFixed(0)} €' : null,
                    ))
                .toList(),
          ),
        if (elementos.isEmpty && finalizados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Todavía no hay suficientes datos para generar un expediente útil.', style: TextStyle(color: context.colors.inkMuted)),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _compartir(context, elementos, registros, documentos.length),
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Compartir resumen'),
        ),
      ],
    );
  }

  Widget _filaResumen(BuildContext context, {required String titulo, required String subtitulo, String? valor}) => IosRow(
        icon: Icons.description_outlined,
        iconColor: context.colors.brand,
        title: titulo,
        subtitle: subtitulo,
        dense: true,
        trailing: valor != null ? Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)) : null,
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
            Text(valor, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: context.colors.brand)),
            const SizedBox(height: 2),
            Text(etiqueta, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: context.colors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
