// lib/screens/elemento_resumen_pdf.dart
//
// Ficha PDF de un elemento (CEO, octubre 2026) -- más completa que el PDF
// de un solo trabajo (registro_resumen_pdf.dart): todos los datos propios
// del elemento (ubicación, marca/modelo, fecha de instalación, coste,
// profesional, garantía) y su historial COMPLETO de trabajos, cada uno con
// su estado real, pagos y cambios de alcance, igual de detallado que en el
// dossier de toda la vivienda (expediente_vivienda_pdf.dart) pero acotado
// a este elemento -- mismas piezas compartidas (widgets/pdf_*.dart), nada
// duplicado. Mismos paquetes que el resto de PDF de Repara (pdf + printing
// + http, ya en pubspec.yaml) -- no se añade ninguna dependencia nueva.
//
// Rediseño documental (CEO, noviembre 2026, "expediente completo de un
// elemento"): deja de ser una ficha plana para tener estructura real --
// identificación (A), resumen del estado (B), resumen económico (C),
// historial como unidades documentales (D, ver fichaTrabajoDocumentalPdf),
// archivo fotográfico agrupado (E) y documentación vinculada (F). Nunca
// toca registro_resumen_pdf.dart ni expediente_vivienda_pdf.dart -- sus
// piezas compartidas (pdf_estilo.dart, pdf_trabajo.dart) se ampliaron de
// forma retrocompatible, nunca con una ruptura para esos otros documentos.
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
import 'package:repara_ui/pdf_estilo.dart';
import 'package:repara_ui/pdf_fuente_unicode.dart';
import '../widgets/pdf_imagenes.dart';
import '../widgets/pdf_trabajo.dart';

class ElementoResumenPdf {
  ElementoResumenPdf._();

  // Tope más bajo que el dossier de toda la vivienda (24) -- el alcance
  // aquí es un único elemento, no hace falta tanto margen. Subido de 16 a
  // 20 (rediseño noviembre 2026) porque el archivo fotográfico ahora
  // permite más de 2 fotos por intervención (ver _maxFotosPorTrabajo).
  static const _maxImagenes = 20;
  static const _maxFotosPorTrabajo = 6;

  static Future<Uint8List> construirBytes({
    required Casa casa,
    required Elemento elemento,
    required String? ubicacion,
    required List<TrabajoConDetalle> trabajos,
    List<Documento> documentos = const [],
  }) async {
    final formatoFecha = DateFormat('d MMMM yyyy', 'es_ES');
    final formatoFechaCorta = DateFormat('d MMM yyyy', 'es_ES');
    final formatoMes = DateFormat('MM/yyyy');
    final garantia = clasificarGarantiaPdf(elemento.garantiaHasta);

    // Documentos vinculados realmente (Bloque F): nunca un borrador sin
    // confirmar por el usuario -- un expediente documental no puede incluir
    // un dato que ni siquiera el propio usuario ha dado por bueno todavía.
    final documentosConfirmados = documentos
        .where((d) => d.estadoIA != EstadoIA.pendiente)
        .toList()
      ..sort((a, b) {
        final fa = a.fecha ?? a.createdAt ?? DateTime(0);
        final fb = b.fecha ?? b.createdAt ?? DateTime(0);
        return fb.compareTo(fa);
      });
    // Título del trabajo al que pertenece cada documento, cuando aplica --
    // nunca se inventa, solo se cruza con los trabajos que ya tenemos.
    final tituloPorRegistro = {
      for (final t in trabajos) t.registro.id: t.registro.titulo,
    };

    final trabajosOrdenados = [...trabajos]
      ..sort((a, b) => b.registro.fecha.compareTo(a.registro.fecha));
    final trabajosConFotos = trabajosOrdenados
        .where((t) => t.registro.fotos.isNotEmpty)
        .toList();
    final urlsAFetch = <String>[
      if (elemento.fotoUrl != null) elemento.fotoUrl!,
      for (final t in trabajosConFotos)
        for (final f in t.registro.fotos.take(_maxFotosPorTrabajo)) f,
    ];
    final imagenes = await descargarImagenesPdf(urlsAFetch, maxTotal: _maxImagenes);
    final fotoElemento = elemento.fotoUrl != null ? imagenes[elemento.fotoUrl!] : null;

    // -- Bloque B: resumen del estado -- a partir de los trabajos reales,
    // nunca un indicador inventado. Un trabajo "requiere atención" si no
    // está ni terminado/archivado ni simplemente en marcha sin pendientes
    // -- mismo agrupamiento de tres colores que colorEstadoRegistroPdf.
    final terminados = trabajosOrdenados
        .where(
          (t) =>
              t.registro.estado == EstadoRegistro.terminado ||
              t.registro.estado == EstadoRegistro.archivado,
        )
        .length;
    final requierenAtencion = trabajosOrdenados
        .where(
          (t) =>
              t.registro.estado == EstadoRegistro.pendienteConfirmacion ||
              t.registro.estado == EstadoRegistro.pendientePago,
        )
        .length;
    final enCurso = trabajosOrdenados.length - terminados - requierenAtencion;
    final profesionalesDistintos = <String>{
      for (final t in trabajosOrdenados)
        for (final p in t.registro.listaProfesionales)
          if (p.nombre.trim().isNotEmpty) p.nombre.trim(),
    };
    final ultimaActuacion = trabajosOrdenados.isEmpty
        ? null
        : trabajosOrdenados
              .map((t) => t.registro.fecha)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    // -- Bloque C: resumen económico -- el saldo pendiente se calcula
    // trabajo a trabajo y LUEGO se suma (nunca una resta global), para que
    // un trabajo cobrado de más nunca compense el saldo pendiente real de
    // otro. El coste de adquisición del elemento (elemento.coste, Bloque A)
    // nunca entra en esta suma -- son conceptos distintos.
    final trabajosConEconomia = trabajosOrdenados
        .where((t) => montoDebidoRegistro(t.registro) != null || t.pagos.isNotEmpty)
        .toList();
    final acordadoTotal = trabajosOrdenados.fold<double>(
      0,
      (acc, t) => acc + (montoDebidoRegistro(t.registro) ?? 0),
    );
    final pagadoTotal = trabajosOrdenados.fold<double>(
      0,
      (acc, t) => acc + t.totalPagado,
    );
    final pendienteTotal = trabajosOrdenados.fold<double>(0, (acc, t) {
      final monto = montoDebidoRegistro(t.registro);
      if (monto == null) return acc;
      return acc + (monto - t.totalPagado).clamp(0, double.infinity);
    });

    final doc = pw.Document(theme: await cargarTemaPdfUnicode());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
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
                      elemento.nombre,
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
                'REPARA · Expediente de ${elemento.nombre}',
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
          // -- Cabecera (REPARA + casa + fecha, solo en la primera página,
          // el header de arriba ya hace ese papel en el resto) --
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPARA',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfBrandStrong,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Expediente del elemento',
                    style: const pw.TextStyle(fontSize: 11, color: pdfInkMuted),
                  ),
                ],
              ),
              pw.Text(
                formatoFecha.format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 10, color: pdfInkMuted),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Divider(color: pdfBorder),
          pw.SizedBox(height: 16),

          // ============================================================
          // BLOQUE A -- Identificación del elemento
          // ============================================================
          if (fotoElemento != null) ...[
            pw.ClipRRect(
              horizontalRadius: 10,
              verticalRadius: 10,
              child: pw.Image(
                pw.MemoryImage(fotoElemento),
                width: double.infinity,
                height: 160,
                fit: pw.BoxFit.cover,
              ),
            ),
            pw.SizedBox(height: 16),
          ],
          if (ubicacion != null) ...[
            pw.Text(
              ubicacion.toUpperCase(),
              style: const pw.TextStyle(
                fontSize: 9,
                color: pdfInkMuted,
                letterSpacing: 0.6,
              ),
            ),
            pw.SizedBox(height: 3),
          ],
          pw.Text(
            elemento.nombre,
            style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              if (elemento.archivado) ...[
                etiquetaPdf('Archivado', pdfInkMuted),
                pw.SizedBox(width: 6),
              ],
              if (elemento.garantiaHasta != null)
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
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Inseparable(child: _datosElemento(casa, elemento, formatoMes)),

          // ============================================================
          // BLOQUE B -- Resumen del estado
          // ============================================================
          if (trabajosOrdenados.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            pw.Inseparable(
              child: franjaResumenPdf([
                celdaDatoPdf(
                  etiqueta: 'Intervenciones',
                  valor: '${trabajosOrdenados.length}',
                ),
                celdaDatoPdf(etiqueta: 'Terminadas', valor: '$terminados'),
                celdaDatoPdf(etiqueta: 'En curso', valor: '$enCurso'),
                if (requierenAtencion > 0)
                  celdaDatoPdf(
                    etiqueta: 'Requieren atención',
                    valor: '$requierenAtencion',
                    colorValor: pdfWarningText,
                  ),
                if (profesionalesDistintos.isNotEmpty)
                  celdaDatoPdf(
                    etiqueta: 'Profesionales',
                    valor: '${profesionalesDistintos.length}',
                  ),
              ]),
            ),
            if (ultimaActuacion != null || elemento.proximoMantenimiento != null) ...[
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (ultimaActuacion != null)
                    pw.Text(
                      'Última actuación: ${formatoFechaCorta.format(ultimaActuacion)}',
                      style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
                    ),
                  if (elemento.proximoMantenimiento != null)
                    pw.Text(
                      'Próxima revisión: ${formatoFechaCorta.format(elemento.proximoMantenimiento!)}',
                      style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
                    ),
                ],
              ),
            ],
          ],

          // ============================================================
          // BLOQUE C -- Resumen económico
          // ============================================================
          if (trabajosConEconomia.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            tituloBloquePdf('Resumen económico'),
            pw.SizedBox(height: 10),
            pw.Inseparable(
              child: franjaResumenPdf([
                cifraResumenPdf(
                  etiqueta: 'Acordado',
                  valor: formatoImportePdf(acordadoTotal),
                ),
                cifraResumenPdf(
                  etiqueta: 'Pagado',
                  valor: formatoImportePdf(pagadoTotal),
                ),
                cifraResumenPdf(
                  etiqueta: 'Pendiente',
                  valor: formatoImportePdf(pendienteTotal),
                  destacado: pendienteTotal > 0,
                ),
              ]),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              trabajosConEconomia.length == 1
                  ? '1 intervención con información económica.'
                  : '${trabajosConEconomia.length} intervenciones con información económica.',
              style: const pw.TextStyle(fontSize: 8, color: pdfInkMuted),
            ),
          ],

          // ============================================================
          // BLOQUE D -- Historial completo
          // ============================================================
          if (trabajosOrdenados.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloBloquePdf('Historial completo (${trabajosOrdenados.length})'),
            pw.SizedBox(height: 10),
            for (final t in trabajosOrdenados)
              // Inseparable (CEO, noviembre 2026: "evitar dividir tarjetas o
              // bloques de información de forma poco estética") -- Column,
              // dentro del paquete `pdf`, SÍ puede partirse entre páginas
              // por defecto (es como fluye el contenido largo), así que un
              // Container normal no basta para proteger una tarjeta.
              pw.Inseparable(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: fichaTrabajoDocumentalPdf(
                    t,
                    formatoFechaCorta: formatoFechaCorta,
                    mostrarElemento: false,
                  ),
                ),
              ),
          ] else ...[
            pw.SizedBox(height: 26),
            tituloBloquePdf('Historial'),
            pw.SizedBox(height: 10),
            pw.Text(
              'Todavía no hay ningún evento registrado para este elemento.',
              style: const pw.TextStyle(fontSize: 10, color: pdfInkMuted),
            ),
          ],

          // ============================================================
          // BLOQUE E -- Archivo fotográfico
          // ============================================================
          if (trabajosConFotos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloBloquePdf('Archivo fotográfico'),
            pw.SizedBox(height: 10),
            for (final t in trabajosConFotos)
              // Mismo motivo que el Inseparable del historial -- una
              // intervención con varias fotos nunca debe quedar partida
              // entre dos páginas (requisito explícito del Bloque E).
              pw.Inseparable(
                child: galeriaTrabajoPdf(
                  t,
                  imagenes,
                  mostrarElemento: false,
                  maxFotos: _maxFotosPorTrabajo,
                  formatoFechaCorta: formatoFechaCorta,
                ),
              ),
          ],

          // ============================================================
          // BLOQUE F -- Documentación vinculada
          // ============================================================
          if (documentosConfirmados.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloBloquePdf('Documentación vinculada (${documentosConfirmados.length})'),
            pw.SizedBox(height: 10),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: pdfBorder, width: 0.5),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1.4),
              },
              children: [
                pw.TableRow(
                  children: [
                    _celdaTablaDoc('DOCUMENTO', cabecera: true),
                    _celdaTablaDoc('TIPO', cabecera: true),
                    _celdaTablaDoc('FECHA', cabecera: true),
                    _celdaTablaDoc('INTERVENCIÓN', cabecera: true),
                  ],
                ),
                for (final d in documentosConfirmados)
                  pw.TableRow(
                    children: [
                      _celdaTablaDoc(d.nombreArchivo),
                      _celdaTablaDoc(nombreTipoDocumento(d.tipo)),
                      _celdaTablaDoc(
                        d.fecha != null ? formatoFechaCorta.format(d.fecha!) : '--',
                      ),
                      _celdaTablaDoc(
                        d.registroId != null
                            ? (tituloPorRegistro[d.registroId] ?? '--')
                            : '--',
                      ),
                    ],
                  ),
              ],
            ),
          ],

          pw.SizedBox(height: 26),
          pw.Divider(color: pdfBorder),
          pw.SizedBox(height: 6),
          pw.Text(
            'Expediente generado con REPARA a partir de los datos registrados por el propietario.',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _datosElemento(Casa casa, Elemento e, DateFormat formatoMes) {
    final filas = <(String, String)>[
      ('Vivienda', casa.nombre),
      if (e.marca != null)
        ('Marca / modelo', '${e.marca}${e.modelo != null ? ' ${e.modelo}' : ''}'),
      if (e.fechaInstalacion != null)
        ('Instalado', formatoMes.format(e.fechaInstalacion!)),
      if (e.coste != null) ('Coste de adquisición', formatoImportePdf(e.coste!)),
      if (e.profesionalNombre != null) ('Profesional', e.profesionalNombre!),
      if (e.garantiaHasta != null)
        ('Garantía hasta', formatoMes.format(e.garantiaHasta!)),
      if (e.intervaloMantenimientoMeses != null)
        ('Revisión cada', '${e.intervaloMantenimientoMeses} meses'),
    ];
    // Rejilla de dos columnas (CEO, noviembre 2026: "una composición que
    // permita identificar rápidamente el elemento", en vez de una lista
    // vertical de una sola columna) -- aprovecha mejor el ancho de la
    // página sin necesitar una tarjeta con borde.
    final pares = <(( String, String), (String, String)?)>[];
    for (var i = 0; i < filas.length; i += 2) {
      pares.add((filas[i], i + 1 < filas.length ? filas[i + 1] : null));
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: pdfSurfaceSunken,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          for (var i = 0; i < pares.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 11),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: celdaDatoPdf(
                    etiqueta: pares[i].$1.$1,
                    valor: pares[i].$1.$2,
                    tamanoValor: 10.5,
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pares[i].$2 != null
                      ? celdaDatoPdf(
                          etiqueta: pares[i].$2!.$1,
                          valor: pares[i].$2!.$2,
                          tamanoValor: 10.5,
                        )
                      : pw.SizedBox(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _celdaTablaDoc(String texto, {bool cabecera = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(
      texto,
      style: cabecera
          ? pw.TextStyle(
              fontSize: 7.5,
              color: pdfInkMuted,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.4,
            )
          : const pw.TextStyle(fontSize: 9),
    ),
  );

  /// Abre la vista previa de impresión/guardado del propio sistema
  /// operativo (Printing.layoutPdf) -- igual que el resto de PDF de
  /// Repara: desde ahí se guarda, imprime o comparte con los mecanismos
  /// nativos de cada plataforma.
  static Future<void> descargar(
    BuildContext context, {
    required Casa casa,
    required Elemento elemento,
    required String? ubicacion,
    required List<TrabajoConDetalle> trabajos,
    List<Documento> documentos = const [],
  }) async {
    await Printing.layoutPdf(
      name: 'Ficha - ${elemento.nombre}',
      onLayout: (_) => construirBytes(
        casa: casa,
        elemento: elemento,
        ubicacion: ubicacion,
        trabajos: trabajos,
        documentos: documentos,
      ),
    );
  }
}
