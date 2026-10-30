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

import '../models/cambio_alcance.dart';
import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/registro.dart';
import '../services/analytics_service.dart';
import '../services/cambio_alcance_service.dart';
import '../services/documento_service.dart';
import '../services/elemento_service.dart';
import '../services/habitacion_service.dart';
import '../services/pago_service.dart';
import '../services/registro_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
import 'expediente_vivienda_pdf.dart';

double? _costeRegistro(Registro r) => montoDebidoRegistro(r);

class ExpedienteViviendaScreen extends StatefulWidget {
  const ExpedienteViviendaScreen({required this.casa, super.key});

  final Casa casa;

  @override
  State<ExpedienteViviendaScreen> createState() =>
      _ExpedienteViviendaScreenState();
}

class _ExpedienteViviendaScreenState extends State<ExpedienteViviendaScreen> {
  Casa get casa => widget.casa;
  bool _generandoPdf = false;

  /// Un registro nunca vive en una colección a nivel de casa (octubre 2026,
  /// fusión Elemento/Trabajo/Evento) -- se agrega aquí leyendo la
  /// subcolección de cada elemento, no con una consulta collectionGroup
  /// (ver firestore.rules: esa vía quedó descartada por limitaciones reales
  /// del propio Firestore, no solo de sintaxis).
  Future<List<Registro>> _todosLosRegistros(List<Elemento> elementos) async {
    final porElemento = await Future.wait(
      elementos.map(
        (e) => RegistroService.streamRegistros(casa.id, e.id).first,
      ),
    );
    return porElemento.expand((lista) => lista).toList();
  }

  Future<void> _compartir(
    BuildContext context,
    List<Elemento> elementos,
    List<Registro> registros,
    int numDocumentos,
  ) async {
    final buffer = StringBuffer()
      ..writeln('EXPEDIENTE DE LA VIVIENDA · ${casa.nombre}')
      ..writeln(
        'Generado el ${DateFormat('d MMMM yyyy', 'es_ES').format(DateTime.now())}',
      )
      ..writeln();

    if (elementos.isNotEmpty) {
      buffer.writeln('ELEMENTOS (${elementos.length})');
      for (final e in elementos) {
        final detalle = [
          if (e.marca != null) '${e.marca} ${e.modelo ?? ''}'.trim(),
          if (e.fechaInstalacion != null)
            'instalado ${DateFormat('MM/yyyy').format(e.fechaInstalacion!)}',
          if (e.garantiaHasta != null)
            'garantía hasta ${DateFormat('MM/yyyy').format(e.garantiaHasta!)}',
          if (e.coste != null) '${e.coste!.toStringAsFixed(0)} €',
        ].join(' · ');
        buffer.writeln(
          '- ${e.nombre}${detalle.isNotEmpty ? ' ($detalle)' : ''}',
        );
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
        buffer.writeln(
          '- ${r.titulo}${detalle.isNotEmpty ? ' ($detalle)' : ''}',
        );
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
      // sharePositionOrigin obligatorio en iOS -- ver nota en
      // contacto_acciones.dart (mismo fallo, mismo arreglo).
      await Share.share(
        buffer.toString(),
        subject: 'Expediente de ${casa.nombre}',
        sharePositionOrigin: Offset.zero & MediaQuery.of(context).size,
      );
      unawaited(AnalyticsService.householdRecordShared());
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st);
      if (context.mounted) {
        AppError.show(context, 'No se pudo abrir el selector para compartir.');
      }
    }
  }

  // "Generar dossier PDF" (CEO, octubre 2026): hoja explicativa breve
  // primero (qué incluye + aviso de privacidad, pedido explícito del
  // encargo) y solo entonces se reúnen los datos que el resumen en
  // pantalla no necesita (pagos y cambios de alcance por cada trabajo,
  // habitaciones para la ubicación de cada elemento) y se genera.
  // ExpedienteViviendaPdf es el mismo motor que ya usa el PDF por trabajo
  // individual (registro_resumen_pdf.dart) -- nada inventado, todo sale de
  // los modelos reales.
  Future<void> _ofrecerDossier(
    BuildContext context,
    List<Elemento> elementos,
  ) async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generar dossier PDF de mi vivienda',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Incluye los elementos registrados, el historial completo de '
                'trabajos (con su estado real, importes y pagos), los '
                'documentos guardados y las garantías. Puede contener '
                'importes y datos de contacto de profesionales -- revísalo '
                'antes de compartirlo con otra persona.',
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Generar PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmar != true || !context.mounted) return;
    await _descargarPdf(context, elementos);
  }

  Future<void> _descargarPdf(
    BuildContext context,
    List<Elemento> elementos,
  ) async {
    setState(() => _generandoPdf = true);
    try {
      final habitaciones = await HabitacionService.streamHabitaciones(
        casa.id,
      ).first;
      final trabajos = await _trabajosConDetalle(elementos);
      final documentos = await DocumentoService.streamTodos(casa.id).first;
      if (!context.mounted) return;
      await ExpedienteViviendaPdf.descargar(
        context,
        casa: casa,
        elementos: elementos,
        habitaciones: habitaciones,
        trabajos: trabajos,
        documentos: documentos,
      );
    } catch (e, st) {
      if (context.mounted) {
        AppError.show(
          context,
          'No se pudo generar el PDF.',
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  // Igual que _todosLosRegistros, pero recorriendo por elemento en vez de
  // aplanar al final (CEO, octubre 2026) -- un Registro no guarda su propio
  // elementoId (solo elementoNombre denormalizado, ver registro.dart), y
  // pedir sus pagos/cambios de alcance sí necesita el elementoId real.
  // Emparejar por nombre en vez de por este recorrido sería incorrecto si
  // dos elementos compartieran nombre -- se volvería a leer la
  // subcolección de registros una segunda vez (ya se lee una para el
  // resumen en pantalla) solo cuando el usuario pide de verdad el dossier,
  // nunca en cada apertura de esta pantalla.
  Future<List<TrabajoConDetalle>> _trabajosConDetalle(
    List<Elemento> elementos,
  ) async {
    final porElemento = await Future.wait(
      elementos.map((elemento) async {
        final registros = await RegistroService.streamRegistros(
          casa.id,
          elemento.id,
        ).first;
        return Future.wait(
          registros.map((r) async {
            final pagos = await PagoService.streamPagos(
              casa.id,
              elemento.id,
              r.id,
            ).first;
            final cambios = r.esConProfesional
                ? await CambioAlcanceService.streamCambios(
                    casa.id,
                    elemento.id,
                    r.id,
                  ).first
                : const <CambioAlcance>[];
            return TrabajoConDetalle(
              registro: r,
              pagos: pagos,
              cambios: cambios,
            );
          }),
        );
      }),
    );
    return porElemento.expand((lista) => lista).toList();
  }

  // "Terminado" ahora exige también estar cobrado (CEO, octubre 2026) -- un
  // registro simple con coste sin pagar vive en pendientePago, no en
  // terminado, así que ya no hace falta el bypass "!esConProfesional" que
  // antes incluía a TODOS los registros simples sin mirar su estado.
  List<Registro> _finalizados(List<Registro> registros) => registros
      .where(
        (r) =>
            r.estado == EstadoRegistro.terminado ||
            r.estado == EstadoRegistro.archivado,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expediente de la vivienda')),
      body: FutureBuilder<List<Elemento>>(
        // incluirArchivados: true (auditoría R5, octubre 2026) -- este
        // expediente es precisamente el resumen histórico/económico
        // completo de la vivienda; archivar un elemento no debe hacer que
        // desaparezca de aquí, solo de los listados de "activos".
        future: ElementoService.streamElementos(
          casa.id,
          incluirArchivados: true,
        ).first,
        builder: (context, elementosSnapshot) {
          if (!elementosSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final elementos = elementosSnapshot.data!;
          return FutureBuilder(
            future: Future.wait([
              _todosLosRegistros(elementos),
              DocumentoService.streamTodos(casa.id).first,
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final registros = snapshot.data![0] as List<Registro>;
              final documentos = snapshot.data![1] as List<Documento>;
              final finalizados = _finalizados(registros);
              final conGarantiaVigente = elementos
                  .where(
                    (e) =>
                        e.garantiaHasta != null &&
                        e.garantiaHasta!.isAfter(DateTime.now()),
                  )
                  .length;
              final costeTotal = finalizados.fold<double>(
                0,
                (acc, r) => acc + (_costeRegistro(r) ?? 0),
              );
              return _cuerpo(
                context,
                elementos,
                finalizados,
                documentos,
                conGarantiaVigente,
                costeTotal,
                registros,
              );
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
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        // Una sola tarjeta para las 5 cifras -- antes eran 2 filas de Cards
        // sueltas (mismo defecto que tenía el resumen de Inicio: piezas
        // independientes en vez de un resumen único).
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _filaEstadisticas(context, [
                _Estadistica(
                  valor: '${elementos.length}',
                  etiqueta: 'Elementos',
                ),
                _Estadistica(
                  valor: '${finalizados.length}',
                  etiqueta: 'Eventos',
                ),
                _Estadistica(
                  valor: '$conGarantiaVigente',
                  etiqueta: 'Garantías vigentes',
                ),
              ]),
              Divider(height: 1, color: context.colors.border),
              _filaEstadisticas(context, [
                _Estadistica(
                  valor: '${documentos.length}',
                  etiqueta: 'Documentos',
                ),
                _Estadistica(
                  valor: '${costeTotal.toStringAsFixed(0)} €',
                  etiqueta: 'Invertido en eventos',
                ),
                const SizedBox(),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (elementos.isNotEmpty)
          IosSection(
            header: 'Elementos',
            rows: elementos
                .map(
                  (e) => _filaResumen(
                    context,
                    titulo: e.nombre,
                    subtitulo: [
                      if (e.marca != null)
                        '${e.marca} ${e.modelo ?? ''}'.trim(),
                      if (e.garantiaHasta != null)
                        'garantía hasta ${DateFormat('MM/yyyy').format(e.garantiaHasta!)}',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    valor: e.coste != null
                        ? '${e.coste!.toStringAsFixed(0)} €'
                        : null,
                  ),
                )
                .toList(),
          ),
        if (finalizados.isNotEmpty)
          IosSection(
            header: 'Eventos',
            rows: finalizados
                .map(
                  (r) => _filaResumen(
                    context,
                    titulo: r.titulo,
                    subtitulo: r.profesionalNombre ?? '',
                    valor: _costeRegistro(r) != null
                        ? '${_costeRegistro(r)!.toStringAsFixed(0)} €'
                        : null,
                  ),
                )
                .toList(),
          ),
        if (elementos.isEmpty && finalizados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.colors.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.summarize_outlined,
                    size: 26,
                    color: context.colors.brand,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Todavía no hay suficientes datos para generar un expediente útil.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                _compartir(context, elementos, registros, documentos.length),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Compartir resumen'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generandoPdf
                ? null
                : () => _ofrecerDossier(context, elementos),
            icon: _generandoPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Generar dossier PDF'),
          ),
        ),
      ],
    );
  }

  Widget _filaResumen(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    String? valor,
  }) => IosRow(
    icon: Icons.description_outlined,
    iconColor: context.colors.brand,
    title: titulo,
    subtitle: subtitulo,
    dense: true,
    trailing: valor != null
        ? Text(valor, style: const TextStyle(fontWeight: FontWeight.w700))
        : null,
  );
}

/// Una fila de hasta 3 cifras dentro de la tarjeta única de estadísticas,
/// separadas por VerticalDivider -- mismo patrón que el resumen de Inicio.
Widget _filaEstadisticas(BuildContext context, List<Widget> celdas) {
  return IntrinsicHeight(
    child: Row(
      children: [
        for (var i = 0; i < celdas.length; i++) ...[
          if (i > 0)
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: context.colors.border,
            ),
          Expanded(child: celdas[i]),
        ],
      ],
    ),
  );
}

class _Estadistica extends StatelessWidget {
  const _Estadistica({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            valor,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colors.brand,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              letterSpacing: 0.2,
              color: context.colors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
