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
import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/casa.dart';
import '../models/elemento.dart';
import '../widgets/pdf_estilo.dart';
import '../widgets/pdf_fuente_unicode.dart';
import '../widgets/pdf_imagenes.dart';
import '../widgets/pdf_trabajo.dart';

class ElementoResumenPdf {
  ElementoResumenPdf._();

  // Tope más bajo que el dossier de toda la vivienda (24) -- el alcance
  // aquí es un único elemento, no hace falta tanto margen.
  static const _maxImagenes = 16;

  static Future<Uint8List> construirBytes({
    required Casa casa,
    required Elemento elemento,
    required String? ubicacion,
    required List<TrabajoConDetalle> trabajos,
  }) async {
    final formatoFecha = DateFormat('d MMMM yyyy', 'es_ES');
    final formatoFechaCorta = DateFormat('d MMM yyyy', 'es_ES');
    final formatoMes = DateFormat('MM/yyyy');
    final garantia = clasificarGarantiaPdf(elemento.garantiaHasta);

    final trabajosConFotos = trabajos
        .where((t) => t.registro.fotos.isNotEmpty)
        .toList();
    final urlsAFetch = <String>[
      if (elemento.fotoUrl != null) elemento.fotoUrl!,
      for (final t in trabajosConFotos) for (final f in t.registro.fotos.take(2)) f,
    ];
    final imagenes = await descargarImagenesPdf(urlsAFetch, maxTotal: _maxImagenes);
    final fotoElemento = elemento.fotoUrl != null ? imagenes[elemento.fotoUrl!] : null;

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
                'Ficha generada con REPARA',
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
                    'Ficha del elemento · ${casa.nombre}',
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

          // -- Foto de portada del elemento, si tiene --
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

          // -- Nombre, ubicación, estado de garantía --
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
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
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
          pw.SizedBox(height: 18),

          // -- Datos del elemento -- (mismas filas que ya se ven en
          // pantalla: Instalado/Coste/Profesional, ver elemento_detail_
          // screen.dart; un campo ausente simplemente no sale, nunca un
          // hueco en blanco "Sin datos").
          _datosElemento(elemento, formatoMes),

          // -- Historial completo -- (TODOS los estados, no solo
          // terminados -- misma filosofía que el dossier de toda la
          // vivienda: el estado real de cada trabajo se respeta tal cual).
          if (trabajos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloSeccionPdf('Historial completo (${trabajos.length})'),
            pw.SizedBox(height: 10),
            for (final t in trabajos)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: fichaTrabajoPdf(
                  t,
                  formatoFechaCorta: formatoFechaCorta,
                  mostrarElemento: false,
                ),
              ),
          ] else ...[
            pw.SizedBox(height: 26),
            tituloSeccionPdf('Historial'),
            pw.SizedBox(height: 10),
            pw.Text(
              'Todavía no hay ningún evento registrado para este elemento.',
              style: const pw.TextStyle(fontSize: 10, color: pdfInkMuted),
            ),
          ],

          // -- Fotografías de los trabajos --
          if (trabajosConFotos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloSeccionPdf('Fotografías de los trabajos'),
            pw.SizedBox(height: 10),
            for (final t in trabajosConFotos)
              galeriaTrabajoPdf(t, imagenes, mostrarElemento: false),
          ],

          pw.SizedBox(height: 26),
          pw.Divider(color: pdfBorder),
          pw.SizedBox(height: 6),
          pw.Text(
            'Ficha generada con REPARA a partir de los datos registrados por el propietario.',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _datosElemento(Elemento e, DateFormat formatoMes) {
    final filas = <(String, String)>[
      if (e.marca != null)
        ('Marca / modelo', '${e.marca}${e.modelo != null ? ' ${e.modelo}' : ''}'),
      if (e.fechaInstalacion != null)
        ('Instalado', formatoMes.format(e.fechaInstalacion!)),
      if (e.coste != null) ('Coste', formatoImportePdf(e.coste!)),
      if (e.profesionalNombre != null) ('Profesional', e.profesionalNombre!),
      if (e.garantiaHasta != null)
        ('Garantía hasta', formatoMes.format(e.garantiaHasta!)),
      if (e.intervaloMantenimientoMeses != null)
        ('Revisión cada', '${e.intervaloMantenimientoMeses} meses'),
    ];
    if (filas.isEmpty) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: pw.BoxDecoration(
        color: pdfSurfaceSunken,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) pw.Divider(color: pdfBorder, height: 1),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 9),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    filas[i].$1,
                    style: const pw.TextStyle(fontSize: 10, color: pdfInkMuted),
                  ),
                  pw.Text(
                    filas[i].$2,
                    style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
  }) async {
    await Printing.layoutPdf(
      name: 'Ficha - ${elemento.nombre}',
      onLayout: (_) => construirBytes(
        casa: casa,
        elemento: elemento,
        ubicacion: ubicacion,
        trabajos: trabajos,
      ),
    );
  }
}
