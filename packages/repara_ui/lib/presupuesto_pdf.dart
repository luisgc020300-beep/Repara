// packages/repara_ui/lib/presupuesto_pdf.dart
//
// Documento de presupuesto en PDF (ampliación REPARA Pro, Fase 3 -- CEO,
// noviembre 2026): "apariencia profesional, con identidad visual REPARA"
// para lo que recibe el cliente -- mismos helpers compartidos que el resto
// de PDFs de la app (pdf_estilo.dart, pdf_fuente_unicode.dart), ningún
// paquete nuevo. Todos los datos vienen directos del Presupuesto ya
// calculado en servidor -- aquí solo se maqueta, nunca se recalcula nada.
import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:repara_core/presupuesto.dart';

import 'pdf_estilo.dart';
import 'pdf_fuente_unicode.dart';

String nombreEstadoPresupuestoPdf(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.borrador => 'Borrador',
  EstadoPresupuesto.enviado => 'Enviado',
  EstadoPresupuesto.aceptado => 'Aceptado',
  EstadoPresupuesto.rechazado => 'Rechazado',
  EstadoPresupuesto.cancelado => 'Cancelado',
};

PdfColor _colorEstadoPresupuestoPdf(EstadoPresupuesto e) => switch (e) {
  EstadoPresupuesto.borrador => pdfInkMuted,
  EstadoPresupuesto.enviado => pdfWarningText,
  EstadoPresupuesto.aceptado => pdfSuccess,
  EstadoPresupuesto.rechazado => pdfErrorText,
  EstadoPresupuesto.cancelado => pdfInkMuted,
};

pw.Widget _celda(
  String texto, {
  bool negrita = false,
  pw.TextAlign align = pw.TextAlign.left,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 5),
  child: pw.Text(
    texto,
    textAlign: align,
    style: pw.TextStyle(
      fontSize: negrita ? 9.5 : 9,
      fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: negrita ? pdfInk : pdfInk,
    ),
  ),
);

class PresupuestoPdf {
  PresupuestoPdf._();

  static Future<Uint8List> construirBytes({
    required Presupuesto presupuesto,
    required String registroTitulo,
    String? elementoNombre,
    String? casaNombre,
    String? profesionalNombre,
  }) async {
    final formatoFecha = DateFormat('d MMMM yyyy', 'es_ES');
    final doc = pw.Document(theme: await cargarTemaPdfUnicode());
    final fecha = presupuesto.fechaEnvio ?? presupuesto.fechaCreacion;
    final contexto = [
      elementoNombre,
      casaNombre,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'REPARA',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfBrandStrong,
                  ),
                ),
                etiquetaPdf(
                  nombreEstadoPresupuestoPdf(presupuesto.estado),
                  _colorEstadoPresupuestoPdf(presupuesto.estado),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Presupuesto nº${presupuesto.numero}${presupuesto.version > 1 ? ' · versión ${presupuesto.version}' : ''}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: pdfInk,
              ),
            ),
            if (fecha != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                formatoFecha.format(fecha),
                style: const pw.TextStyle(fontSize: 9.5, color: pdfInkMuted),
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pdfBorder),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    registroTitulo,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (contexto.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      contexto,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: pdfInkMuted,
                      ),
                    ),
                  ],
                  if (profesionalNombre != null &&
                      profesionalNombre.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Profesional: $profesionalNombre',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: pdfInkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            tituloSeccionPdf('Partidas'),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: pdfBorder, width: 1),
                    ),
                  ),
                  children: [
                    _celda('Descripción', negrita: true),
                    _celda('Cant.', negrita: true),
                    _celda('Precio', negrita: true, align: pw.TextAlign.right),
                    _celda('Importe', negrita: true, align: pw.TextAlign.right),
                  ],
                ),
                for (final l in presupuesto.lineas)
                  pw.TableRow(
                    children: [
                      _celda(l.descripcion),
                      _celda(
                        l.cantidad.toStringAsFixed(
                          l.cantidad == l.cantidad.roundToDouble() ? 0 : 1,
                        ),
                      ),
                      _celda(
                        formatoImportePdf(l.precioUnitario),
                        align: pw.TextAlign.right,
                      ),
                      _celda(
                        formatoImportePdf(l.importeSinIva),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Subtotal: ${formatoImportePdf(presupuesto.subtotal)}',
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: pdfInkMuted,
                    ),
                  ),
                  pw.Text(
                    'IVA: ${formatoImportePdf(presupuesto.iva)}',
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: pdfInkMuted,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Total: ${formatoImportePdf(presupuesto.total)}',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfBrandStrong,
                    ),
                  ),
                ],
              ),
            ),
            if (presupuesto.notas != null &&
                presupuesto.notas!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              tituloSeccionPdf('Observaciones'),
              pw.SizedBox(height: 6),
              pw.Text(
                presupuesto.notas!.trim(),
                style: const pw.TextStyle(fontSize: 9.5, color: pdfInk),
              ),
            ],
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// Abre la vista previa de impresión/guardado del propio sistema
  /// operativo (Printing.layoutPdf) -- mismo patrón que
  /// expediente_vivienda_pdf.dart.
  static Future<void> descargar(
    BuildContext context, {
    required Presupuesto presupuesto,
    required String registroTitulo,
    String? elementoNombre,
    String? casaNombre,
    String? profesionalNombre,
  }) async {
    await Printing.layoutPdf(
      name: 'Presupuesto ${presupuesto.numero} - $registroTitulo',
      onLayout: (_) => construirBytes(
        presupuesto: presupuesto,
        registroTitulo: registroTitulo,
        elementoNombre: elementoNombre,
        casaNombre: casaNombre,
        profesionalNombre: profesionalNombre,
      ),
    );
  }
}
