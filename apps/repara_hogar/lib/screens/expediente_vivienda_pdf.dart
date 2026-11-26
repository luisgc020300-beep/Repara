// lib/screens/expediente_vivienda_pdf.dart
//
// Dossier PDF de la vivienda (CEO, octubre 2026) -- documento editorial
// completo, no una impresión de la pantalla de resumen. Mismos paquetes que
// registro_resumen_pdf.dart (pdf + printing + http, ya en pubspec.yaml) --
// no se añade ninguna dependencia nueva. Todos los datos vienen de los
// modelos reales; un campo ausente simplemente no aparece, nunca se inventa
// ni se rellena.
//
// Rediseño documental (CEO, noviembre 2026, "expediente patrimonial"):
// arquitectura editorial completa -- portada ejecutiva, índice con enlaces
// internos, resumen ejecutivo con indicadores reales y una representación
// gráfica discreta, inventario organizado por estancia, historial agrupado
// por año cuando aporta, archivo documental con nombres siempre legibles
// (nunca un nombre técnico de archivo), garantías como fichas propias
// relacionadas con su documento justificativo, y archivo fotográfico con
// fotos a su proporción real. Reutiliza fichaTrabajoDocumentalPdf (ya
// existente, del expediente de elemento) para el historial -- nunca se
// duplica esa tarjeta -- y añade galeriaTrabajoDocumentalPdf (nueva, junto
// a la galería original que sigue usando el expediente de elemento sin
// cambios) para el archivo fotográfico con proporciones reales.
//
// Privacidad (sección 6 del encargo): nunca se imprime un id de Firestore,
// un token ni una URL de Storage como texto visible -- las URLs solo se
// usan para descargar bytes de imagen. Un nombre de archivo que parezca
// técnico (image_picker_..., un hash, un número largo) nunca se muestra tal
// cual -- ver nombreDocumentoLegiblePdf en pdf_estilo.dart.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:repara_core/documento.dart';
import 'package:repara_core/registro.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import 'package:repara_ui/pdf_estilo.dart';
import 'package:repara_ui/pdf_fuente_unicode.dart';
import '../widgets/pdf_imagenes.dart';
import '../widgets/pdf_trabajo.dart';

const double _margen = 36.0;

class ExpedienteViviendaPdf {
  ExpedienteViviendaPdf._();

  // Topes generosos pero finitos -- una vivienda con años de historial
  // nunca debe colgar la generación ni disparar el consumo de memoria sin
  // límite (sección 6 del encargo: "optimizar memoria... incluso con
  // decenas o cientos de trabajos").
  static const _maxImagenes = 60;
  static const _maxFotosPorTrabajo = 6;

  static Future<Uint8List> construirBytes({
    required Casa casa,
    required List<Elemento> elementos,
    required List<Habitacion> habitaciones,
    required List<TrabajoConDetalle> trabajos,
    required List<Documento> documentos,
  }) async {
    final formatoFecha = DateFormat('d MMMM yyyy', 'es_ES');
    final formatoFechaCorta = DateFormat('d MMM yyyy', 'es_ES');
    final formatoMes = DateFormat('MM/yyyy');
    final nombreElemento = {for (final e in elementos) e.id: e.nombre};

    // -- Clasificaciones base, nunca recalculadas dos veces de formas
    // distintas en el resto del documento --
    final elementosActivos = elementos.where((e) => !e.archivado).toList();
    final elementosArchivados = elementos.where((e) => e.archivado).toList();

    final documentosConfirmados = documentos
        .where((d) => d.estadoIA != EstadoIA.pendiente)
        .toList()
      ..sort((a, b) {
        final fa = a.fecha ?? a.createdAt ?? DateTime(0);
        final fb = b.fecha ?? b.createdAt ?? DateTime(0);
        return fb.compareTo(fa);
      });
    final tituloPorRegistro = {
      for (final t in trabajos) t.registro.id: t.registro.titulo,
    };

    bool esFinalizado(Registro r) =>
        r.estado == EstadoRegistro.terminado || r.estado == EstadoRegistro.archivado;
    bool esPendienteAtencion(Registro r) =>
        r.estado == EstadoRegistro.pendienteConfirmacion ||
        r.estado == EstadoRegistro.pendientePago;

    final trabajosOrdenados = [...trabajos]
      ..sort((a, b) => b.registro.fecha.compareTo(a.registro.fecha));
    final finalizados = trabajosOrdenados.where((t) => esFinalizado(t.registro)).toList();
    final pendientesAtencion =
        trabajosOrdenados.where((t) => esPendienteAtencion(t.registro)).toList();
    final enCurso = trabajosOrdenados.length - finalizados.length - pendientesAtencion.length;

    // -- Economía: acordado/pagado/pendiente de TODOS los trabajos (sección
    // 03), más un segundo indicador de "invertido en trabajos finalizados"
    // (coincide con lo que ya mostraba la versión anterior). Nunca se suma
    // dos veces un mismo importe ni se confunde el coste de adquisición de
    // un elemento (Bloque A/04) con lo acordado en sus trabajos (Bloque 05).
    final acordadoTotal = trabajosOrdenados.fold<double>(
      0,
      (acc, t) => acc + (montoDebidoRegistro(t.registro) ?? 0),
    );
    final pagadoTotal = trabajosOrdenados.fold<double>(0, (acc, t) => acc + t.totalPagado);
    final pendienteTotal = trabajosOrdenados.fold<double>(0, (acc, t) {
      final monto = montoDebidoRegistro(t.registro);
      if (monto == null) return acc;
      return acc + (monto - t.totalPagado).clamp(0, double.infinity);
    });
    final invertidoFinalizados = finalizados.fold<double>(
      0,
      (acc, t) => acc + (montoDebidoRegistro(t.registro) ?? 0),
    );

    final presupuestosDocs =
        documentosConfirmados.where((d) => d.tipo == TipoDocumento.presupuesto).length;
    final facturasDocs =
        documentosConfirmados.where((d) => d.tipo == TipoDocumento.factura).length;
    final otrosDocs = documentosConfirmados.length - presupuestosDocs - facturasDocs;

    final porGarantia = <EstadoGarantiaPdf, List<Elemento>>{};
    for (final e in elementos) {
      if (e.garantiaHasta == null) continue;
      porGarantia.putIfAbsent(clasificarGarantiaPdf(e.garantiaHasta), () => []).add(e);
    }
    // Último documento de garantía confirmado por elemento (si hay varios,
    // el más reciente) -- nunca se inventa, solo se cruza con lo que ya
    // existe.
    final documentoGarantiaPorElemento = <String, Documento>{};
    for (final d in documentosConfirmados.reversed) {
      if (d.tipo == TipoDocumento.garantia && d.elementoId != null) {
        documentoGarantiaPorElemento[d.elementoId!] = d;
      }
    }

    final trabajosConFotos =
        trabajosOrdenados.where((t) => t.registro.fotos.isNotEmpty).toList();

    // -- Descarga de imágenes: identificación de elementos antes que
    // detalle de trabajos antes que documentos, respetando el tope global.
    final urlsAFetch = <String>[
      for (final e in elementos)
        if (e.fotoUrl != null) e.fotoUrl!,
      for (final t in trabajosConFotos)
        for (final f in t.registro.fotos.take(_maxFotosPorTrabajo)) f,
      for (final d in documentosConfirmados)
        if (esImagenEmbebiblePdf(d.nombreArchivo)) d.url,
    ];
    final imagenes = await descargarImagenesPdf(urlsAFetch, maxTotal: _maxImagenes);

    final doc = pw.Document(theme: await cargarTemaPdfUnicode());

    // ========================================================================
    // SECCIÓN 01 -- Portada ejecutiva
    // ========================================================================
    // Casa no tiene ni dirección ni foto propia (solo fotos de miembro) --
    // portada tipográfica, nunca una imagen de relleno inventada ni la foto
    // de un elemento cualquiera haciéndose pasar por "la vivienda".
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Container(
          width: double.infinity,
          height: double.infinity,
          color: pdfBrandStrong,
          padding: const pw.EdgeInsets.all(48),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'REPARA',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EXPEDIENTE DE LA VIVIENDA',
                    style: pw.TextStyle(
                      color: PdfColors.white.shade(0.15),
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2.2,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    casa.nombre,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(width: 56, height: 1.4, color: PdfColors.white.shade(0.4)),
                  pw.SizedBox(height: 16),
                  pw.ConstrainedBox(
                    constraints: const pw.BoxConstraints(maxWidth: 320),
                    child: pw.Text(
                      'Informe patrimonial generado automáticamente a partir de la '
                      'información registrada por el propietario en REPARA.',
                      style: pw.TextStyle(
                        color: PdfColors.white.shade(0.25),
                        fontSize: 9.5,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Generado el ${formatoFecha.format(DateTime.now())}',
                style: pw.TextStyle(color: PdfColors.white.shade(0.2), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );

    // ========================================================================
    // Secciones reales (para el índice, Bloque 02) -- solo las que de
    // verdad van a aparecer con contenido.
    // ========================================================================
    final haySeccionInventario = elementos.isNotEmpty;
    final haySeccionHistorial = trabajosOrdenados.isNotEmpty;
    final haySeccionDocumentos = documentosConfirmados.isNotEmpty;
    final haySeccionGarantias = porGarantia.isNotEmpty;
    final haySeccionFotos = trabajosConFotos.isNotEmpty;

    final secciones = <(String ancla, String titulo)>[
      ('sec_resumen', 'Resumen ejecutivo de la vivienda'),
      if (haySeccionInventario) ('sec_inventario', 'Inventario de elementos e instalaciones'),
      if (haySeccionHistorial) ('sec_historial', 'Historial completo de trabajos'),
      if (haySeccionDocumentos) ('sec_documentos', 'Archivo documental'),
      if (haySeccionGarantias) ('sec_garantias', 'Garantías'),
      if (haySeccionFotos) ('sec_fotos', 'Archivo fotográfico'),
      ('sec_alcance', 'Información y alcance del documento'),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(_margen, 28, _margen, 28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: pdfBorder, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'REPARA',
                style: pw.TextStyle(
                  color: pdfBrandStrong,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              pw.Text(
                'Expediente de ${casa.nombre}',
                style: const pw.TextStyle(color: pdfInkMuted, fontSize: 9),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: pdfBorder, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Expediente patrimonial generado con REPARA',
                style: const pw.TextStyle(color: pdfInkMuted, fontSize: 8),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(color: pdfInkMuted, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          // ====================================================================
          // SECCIÓN 02 -- Índice (con enlaces internos a cada sección; la
          // numeración de página de cada entrada exigiría una pasada previa
          // de maquetación que esta implementación de un solo paso no hace
          // -- limitación documentada en el informe final, no simulada con
          // un número inventado).
          // ====================================================================
          pw.Text(
            'ÍNDICE',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: pdfInkMuted,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 10),
          for (final (ancla, titulo) in secciones)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Link(
                destination: ancla,
                child: pw.Row(
                  children: [
                    pw.Container(width: 3, height: 3, color: pdfBrand),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      titulo,
                      style: const pw.TextStyle(fontSize: 10.5, color: pdfBrand),
                    ),
                  ],
                ),
              ),
            ),
          pw.SizedBox(height: 26),

          // ====================================================================
          // SECCIÓN 03 -- Resumen ejecutivo de la vivienda
          // ====================================================================
          pw.Anchor(name: 'sec_resumen', child: pw.SizedBox()),
          tituloBloquePdf('Resumen ejecutivo de la vivienda'),
          pw.SizedBox(height: 4),
          pw.Text(
            'Estado documental y patrimonial de la vivienda a partir de todo lo '
            'registrado en REPARA hasta la fecha de generación de este informe.',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
          ),
          pw.SizedBox(height: 12),
          _bloqueDashboard(
            titulo: 'Inventario',
            celdas: [
              celdaDatoPdf(etiqueta: 'Elementos totales', valor: '${elementos.length}'),
              celdaDatoPdf(etiqueta: 'Activos', valor: '${elementosActivos.length}'),
              celdaDatoPdf(
                etiqueta: 'Archivados',
                valor: '${elementosArchivados.length}',
                colorValor: elementosArchivados.isNotEmpty ? pdfInkMuted : null,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _bloqueDashboard(
            titulo: 'Actividad',
            celdas: [
              celdaDatoPdf(etiqueta: 'Trabajos totales', valor: '${trabajosOrdenados.length}'),
              celdaDatoPdf(
                etiqueta: 'Finalizados',
                valor: '${finalizados.length}',
                colorValor: pdfSuccess,
              ),
              celdaDatoPdf(etiqueta: 'En curso', valor: '$enCurso', colorValor: pdfBrand),
              celdaDatoPdf(
                etiqueta: 'Requieren atención',
                valor: '${pendientesAtencion.length}',
                colorValor: pendientesAtencion.isNotEmpty ? pdfWarningText : null,
              ),
            ],
            barra: trabajosOrdenados.isEmpty
                ? null
                : _barraProporcionPdf([
                    (finalizados.length.toDouble(), pdfSuccess),
                    (enCurso.toDouble(), pdfBrand),
                    (pendientesAtencion.length.toDouble(), pdfWarningText),
                  ]),
          ),
          pw.SizedBox(height: 10),
          _bloqueDashboard(
            titulo: 'Economía',
            celdas: [
              celdaDatoPdf(etiqueta: 'Acordado', valor: formatoImportePdf(acordadoTotal)),
              celdaDatoPdf(
                etiqueta: 'Pagado',
                valor: formatoImportePdf(pagadoTotal),
                colorValor: pdfSuccess,
              ),
              celdaDatoPdf(
                etiqueta: 'Pendiente',
                valor: formatoImportePdf(pendienteTotal),
                colorValor: pendienteTotal > 0 ? pdfWarningText : null,
              ),
            ],
            barra: acordadoTotal <= 0
                ? null
                : _barraProporcionPdf([
                    (pagadoTotal, pdfSuccess),
                    (pendienteTotal, pdfWarningText),
                  ]),
            notaFinal: finalizados.isEmpty
                ? null
                : 'Invertido en trabajos finalizados: ${formatoImportePdf(invertidoFinalizados)}.',
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _bloqueDashboard(
                  titulo: 'Documentación',
                  celdas: [
                    celdaDatoPdf(
                      etiqueta: 'Total',
                      valor: '${documentosConfirmados.length}',
                    ),
                    celdaDatoPdf(etiqueta: 'Presupuestos', valor: '$presupuestosDocs'),
                    celdaDatoPdf(etiqueta: 'Facturas', valor: '$facturasDocs'),
                    celdaDatoPdf(etiqueta: 'Otros', valor: '$otrosDocs'),
                  ],
                ),
              ),
            ],
          ),
          if (porGarantia.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _bloqueDashboard(
              titulo: 'Garantías',
              celdas: [
                celdaDatoPdf(
                  etiqueta: 'Vigentes',
                  valor: '${porGarantia[EstadoGarantiaPdf.vigente]?.length ?? 0}',
                  colorValor: pdfSuccess,
                ),
                celdaDatoPdf(
                  etiqueta: 'Próximas a vencer',
                  valor: '${porGarantia[EstadoGarantiaPdf.proxima]?.length ?? 0}',
                  colorValor: (porGarantia[EstadoGarantiaPdf.proxima]?.isNotEmpty ?? false)
                      ? pdfWarningText
                      : null,
                ),
                celdaDatoPdf(
                  etiqueta: 'Vencidas',
                  valor: '${porGarantia[EstadoGarantiaPdf.vencida]?.length ?? 0}',
                  colorValor: (porGarantia[EstadoGarantiaPdf.vencida]?.isNotEmpty ?? false)
                      ? pdfErrorText
                      : null,
                ),
              ],
            ),
          ],

          // ====================================================================
          // SECCIÓN 04 -- Inventario de elementos e instalaciones
          // ====================================================================
          if (haySeccionInventario) ...[
            pw.SizedBox(height: 28),
            pw.Anchor(name: 'sec_inventario', child: pw.SizedBox()),
            tituloBloquePdf('Inventario de elementos e instalaciones (${elementos.length})'),
            pw.SizedBox(height: 10),
            ..._seccionInventario(elementos, habitaciones, imagenes, formatoMes),
          ],

          // ====================================================================
          // SECCIÓN 05 -- Historial completo de trabajos
          // ====================================================================
          if (haySeccionHistorial) ...[
            pw.SizedBox(height: 28),
            pw.Anchor(name: 'sec_historial', child: pw.SizedBox()),
            tituloBloquePdf('Historial completo de trabajos (${trabajosOrdenados.length})'),
            pw.SizedBox(height: 10),
            ..._seccionHistorial(trabajosOrdenados, formatoFechaCorta),
          ],

          // ====================================================================
          // SECCIÓN 06 -- Archivo documental
          // ====================================================================
          if (haySeccionDocumentos) ...[
            pw.SizedBox(height: 28),
            pw.Anchor(name: 'sec_documentos', child: pw.SizedBox()),
            tituloBloquePdf('Archivo documental (${documentosConfirmados.length})'),
            pw.SizedBox(height: 10),
            for (final d in documentosConfirmados)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: _fichaDocumento(
                  d,
                  elementoNombre: nombreElemento[d.elementoId],
                  tituloTrabajo: d.registroId != null ? tituloPorRegistro[d.registroId] : null,
                  foto: esImagenEmbebiblePdf(d.nombreArchivo) ? imagenes[d.url] : null,
                  formatoFechaCorta: formatoFechaCorta,
                ),
              ),
          ],

          // ====================================================================
          // SECCIÓN 07 -- Garantías
          // ====================================================================
          if (haySeccionGarantias) ...[
            pw.SizedBox(height: 28),
            pw.Anchor(name: 'sec_garantias', child: pw.SizedBox()),
            tituloBloquePdf('Garantías'),
            pw.SizedBox(height: 10),
            ..._seccionGarantias(
              porGarantia,
              formatoMes,
              documentoGarantiaPorElemento,
              formatoFechaCorta,
            ),
          ],

          // ====================================================================
          // SECCIÓN 08 -- Archivo fotográfico
          // ====================================================================
          if (haySeccionFotos) ...[
            pw.SizedBox(height: 28),
            pw.Anchor(name: 'sec_fotos', child: pw.SizedBox()),
            tituloBloquePdf('Archivo fotográfico'),
            pw.SizedBox(height: 10),
            for (final t in trabajosConFotos)
              ...galeriaTrabajoDocumentalPdf(
                t,
                imagenes,
                formatoFechaCorta: formatoFechaCorta,
                anchoContenido: PdfPageFormat.a4.width - _margen * 2,
                maxFotos: _maxFotosPorTrabajo,
              ),
          ],

          // ====================================================================
          // SECCIÓN 09 -- Información y alcance del documento
          // ====================================================================
          pw.SizedBox(height: 28),
          pw.Anchor(name: 'sec_alcance', child: pw.SizedBox()),
          tituloBloquePdf('Información y alcance del documento'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Este expediente recoge la información que el propietario ha registrado '
            'en REPARA sobre esta vivienda hasta el ${formatoFecha.format(DateTime.now())}, '
            'fecha de generación de este documento.\n\n'
            'No constituye por sí mismo una inspección técnica, una tasación ni una '
            'certificación de ningún tipo. No garantiza la vigencia legal de los '
            'documentos, presupuestos o garantías incluidos, y no certifica el '
            'cumplimiento de ninguna normativa ni la ausencia de defectos en la '
            'vivienda o sus instalaciones.',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted, lineSpacing: 2),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ==========================================================================
  // SECCIÓN 03 -- piezas del resumen ejecutivo
  // ==========================================================================

  /// Un grupo de indicadores con su propio título -- misma franja de fondo
  /// que ya usan el expediente de elemento y el informe de un evento
  /// (franjaResumenPdf), aquí con un título propio encima y, opcionalmente,
  /// una barra proporcional discreta debajo (nunca un gráfico llamativo).
  static pw.Widget _bloqueDashboard({
    required String titulo,
    required List<pw.Widget> celdas,
    pw.Widget? barra,
    String? notaFinal,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: pdfInkMuted,
            letterSpacing: 0.6,
          ),
        ),
        pw.SizedBox(height: 6),
        franjaResumenPdf(celdas),
        if (barra != null) ...[pw.SizedBox(height: 8), barra],
        if (notaFinal != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(notaFinal, style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted)),
        ],
      ],
    );
  }

  /// Barra horizontal proporcional (p.ej. pagado vs. pendiente, o
  /// finalizados vs. en curso vs. requieren atención) -- "representación
  /// gráfica discreta" (sección 03 del encargo), nunca un gráfico de
  /// terceros ni una librería nueva: solo contenedores de ancho
  /// proporcional.
  static pw.Widget _barraProporcionPdf(List<(double valor, PdfColor color)> segmentos) {
    final total = segmentos.fold<double>(0, (a, s) => a + s.$1);
    if (total <= 0) return pw.SizedBox();
    const alto = 8.0;
    return pw.ClipRRect(
      horizontalRadius: alto / 2,
      verticalRadius: alto / 2,
      child: pw.Row(
        children: [
          for (final s in segmentos)
            if (s.$1 > 0)
              pw.Expanded(
                flex: (s.$1 / total * 1000).round().clamp(1, 1000),
                child: pw.Container(height: alto, color: s.$2),
              ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECCIÓN 04 -- inventario agrupado por estancia
  // ==========================================================================

  static List<pw.Widget> _seccionInventario(
    List<Elemento> elementos,
    List<Habitacion> habitaciones,
    Map<String, Uint8List> imagenes,
    DateFormat formatoMes,
  ) {
    final habitacionesOrdenadas = [...habitaciones]
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final porHabitacion = <String?, List<Elemento>>{};
    for (final e in elementos) {
      porHabitacion.putIfAbsent(e.habitacionId, () => []).add(e);
    }
    for (final lista in porHabitacion.values) {
      lista.sort((a, b) {
        if (a.archivado != b.archivado) return a.archivado ? 1 : -1;
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    }

    final grupos = <(String nombre, List<Elemento> lista)>[
      for (final h in habitacionesOrdenadas)
        if (porHabitacion[h.id]?.isNotEmpty ?? false) (h.nombre, porHabitacion[h.id]!),
      if (porHabitacion[null]?.isNotEmpty ?? false) ('Sin ubicación asignada', porHabitacion[null]!),
    ];

    final widgets = <pw.Widget>[];
    for (final (nombreGrupo, lista) in grupos) {
      final fichas = [
        for (final e in lista)
          _fichaElemento(
            e,
            ubicacion: null, // ya agrupado por estancia, no hace falta repetirlo
            foto: e.fotoUrl != null ? imagenes[e.fotoUrl!] : null,
            formatoMes: formatoMes,
          ),
      ];
      widgets.add(
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '$nombreGrupo (${lista.length})',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfBrand,
                  ),
                ),
              ),
              pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: fichas.first),
            ],
          ),
        ),
      );
      for (final f in fichas.skip(1)) {
        widgets.add(pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: f));
      }
      widgets.add(pw.SizedBox(height: 4));
    }
    return widgets;
  }

  static pw.Widget _fichaElemento(
    Elemento e, {
    required String? ubicacion,
    required Uint8List? foto,
    required DateFormat formatoMes,
  }) {
    final garantia = clasificarGarantiaPdf(e.garantiaHasta);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: pdfBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        e.nombre,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    if (e.archivado) etiquetaPdf('Archivado', pdfInkMuted),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  [
                    ?ubicacion,
                    if (e.marca != null) '${e.marca}${e.modelo != null ? ' ${e.modelo}' : ''}',
                    if (e.fechaInstalacion != null)
                      'instalado ${formatoMes.format(e.fechaInstalacion!)}',
                  ].join(' · '),
                  style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
                ),
                if (e.profesionalNombre != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Profesional: ${e.profesionalNombre}',
                    style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    if (e.garantiaHasta != null)
                      etiquetaPdf(
                        switch (garantia) {
                          EstadoGarantiaPdf.vigente => 'Garantía vigente',
                          EstadoGarantiaPdf.proxima => 'Garantía próxima a vencer',
                          EstadoGarantiaPdf.vencida => 'Garantía vencida',
                          EstadoGarantiaPdf.desconocida => 'Garantía',
                        },
                        switch (garantia) {
                          EstadoGarantiaPdf.vigente => pdfSuccess,
                          EstadoGarantiaPdf.proxima => pdfWarningText,
                          EstadoGarantiaPdf.vencida => pdfErrorText,
                          EstadoGarantiaPdf.desconocida => pdfInkMuted,
                        },
                      ),
                    if (e.coste != null) ...[
                      pw.SizedBox(width: 6),
                      pw.Text(
                        formatoImportePdf(e.coste!),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (foto != null) ...[pw.SizedBox(width: 10), miniaturaPdf(foto)],
        ],
      ),
    );
  }

  // ==========================================================================
  // SECCIÓN 05 -- historial agrupado por año (solo cuando el volumen lo
  // justifica -- si todo ocurrió en el mismo año, agrupar no aporta nada).
  // ==========================================================================

  static List<pw.Widget> _seccionHistorial(
    List<TrabajoConDetalle> trabajosOrdenados,
    DateFormat formatoFechaCorta,
  ) {
    final anios = trabajosOrdenados.map((t) => t.registro.fecha.year).toSet();
    final agruparPorAnio = anios.length > 1;

    if (!agruparPorAnio) {
      return [
        for (final t in trabajosOrdenados)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: fichaTrabajoDocumentalPdf(t, formatoFechaCorta: formatoFechaCorta),
          ),
      ];
    }

    final widgets = <pw.Widget>[];
    int? anioActual;
    for (final t in trabajosOrdenados) {
      final anio = t.registro.fecha.year;
      final ficha = pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: fichaTrabajoDocumentalPdf(t, formatoFechaCorta: formatoFechaCorta),
      );
      if (anio != anioActual) {
        anioActual = anio;
        widgets.add(
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
                  child: pw.Text(
                    '$anio',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfBrandStrong,
                    ),
                  ),
                ),
                ficha,
              ],
            ),
          ),
        );
      } else {
        widgets.add(ficha);
      }
    }
    return widgets;
  }

  // ==========================================================================
  // SECCIÓN 06 -- archivo documental
  // ==========================================================================

  static pw.Widget _fichaDocumento(
    Documento d, {
    required String? elementoNombre,
    required String? tituloTrabajo,
    required Uint8List? foto,
    required DateFormat formatoFechaCorta,
  }) {
    final fechaTexto = d.fecha != null ? formatoFechaCorta.format(d.fecha!) : null;
    final nombreLegible = nombreDocumentoLegiblePdf(
      d.nombreArchivo,
      nombreTipoDocumento(d.tipo),
      fechaTexto: fechaTexto,
    );
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: pdfBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    etiquetaPdf(nombreTipoDocumento(d.tipo), pdfBrand),
                    if (fechaTexto != null) ...[
                      pw.SizedBox(width: 6),
                      pw.Text(
                        fechaTexto,
                        style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  nombreLegible,
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                ),
                if (d.proveedor != null || elementoNombre != null || tituloTrabajo != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    [
                      if (d.proveedor != null) d.proveedor!,
                      if (tituloTrabajo != null)
                        'vinculado al trabajo "$tituloTrabajo"'
                      else if (elementoNombre != null)
                        'vinculado a $elementoNombre',
                    ].join(' · '),
                    style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
                  ),
                ],
                if (d.descripcionTrabajo != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(d.descripcionTrabajo!, style: const pw.TextStyle(fontSize: 9)),
                ],
              ],
            ),
          ),
          if (d.importe != null) ...[
            pw.SizedBox(width: 10),
            pw.Text(
              formatoImportePdf(d.importe!),
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (foto != null) ...[pw.SizedBox(width: 10), miniaturaPdf(foto, size: 48)],
        ],
      ),
    );
  }

  // ==========================================================================
  // SECCIÓN 07 -- garantías como fichas propias (no una viñeta suelta)
  // ==========================================================================

  static List<pw.Widget> _seccionGarantias(
    Map<EstadoGarantiaPdf, List<Elemento>> porGarantia,
    DateFormat formatoMes,
    Map<String, Documento> documentoGarantiaPorElemento,
    DateFormat formatoFechaCorta,
  ) {
    pw.Widget ficha(Elemento e, PdfColor color, String etiqueta) {
      final doc = documentoGarantiaPorElemento[e.id];
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdfBorder),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    e.nombre,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                etiquetaPdf(etiqueta, color),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              [
                if (e.marca != null) '${e.marca}${e.modelo != null ? ' ${e.modelo}' : ''}',
                if (e.fechaInstalacion != null)
                  'instalado ${formatoMes.format(e.fechaInstalacion!)}',
                'garantía hasta ${formatoMes.format(e.garantiaHasta!)}',
              ].join(' · '),
              style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
            ),
            if (doc != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Documento justificativo: '
                '${nombreDocumentoLegiblePdf(doc.nombreArchivo, nombreTipoDocumento(doc.tipo), fechaTexto: doc.fecha != null ? formatoFechaCorta.format(doc.fecha!) : null)}',
                style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
              ),
            ],
          ],
        ),
      );
    }

    List<pw.Widget> grupo(String titulo, PdfColor color, String etiqueta, List<Elemento> lista) {
      if (lista.isEmpty) return [];
      final ordenados = [...lista]
        ..sort((a, b) => a.garantiaHasta!.compareTo(b.garantiaHasta!));
      final fichas = [for (final e in ordenados) ficha(e, color, etiqueta)];
      return [
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '$titulo (${lista.length})',
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: color),
                ),
              ),
              pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: fichas.first),
            ],
          ),
        ),
        for (final f in fichas.skip(1))
          pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: f),
        pw.SizedBox(height: 4),
      ];
    }

    return [
      ...grupo(
        'Próximas a vencer',
        pdfWarningText,
        'Próxima a vencer',
        porGarantia[EstadoGarantiaPdf.proxima] ?? [],
      ),
      ...grupo('Vigentes', pdfSuccess, 'Vigente', porGarantia[EstadoGarantiaPdf.vigente] ?? []),
      ...grupo('Vencidas', pdfErrorText, 'Vencida', porGarantia[EstadoGarantiaPdf.vencida] ?? []),
    ];
  }

  /// Abre la vista previa de impresión/guardado del propio sistema
  /// operativo (Printing.layoutPdf) -- igual que registro_resumen_pdf.dart:
  /// desde ahí se guarda, imprime o comparte con los mecanismos nativos de
  /// cada plataforma, sin rutas de archivo ni permisos a mano.
  static Future<void> descargar(
    BuildContext context, {
    required Casa casa,
    required List<Elemento> elementos,
    required List<Habitacion> habitaciones,
    required List<TrabajoConDetalle> trabajos,
    required List<Documento> documentos,
  }) async {
    await Printing.layoutPdf(
      name: 'Expediente - ${casa.nombre}',
      onLayout: (_) => construirBytes(
        casa: casa,
        elementos: elementos,
        habitaciones: habitaciones,
        trabajos: trabajos,
        documentos: documentos,
      ),
    );
  }
}
