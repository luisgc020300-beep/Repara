// lib/screens/registro_simple/registro_resumen_pdf.dart
//
// PDF de resumen de un registro simple (CEO, octubre 2026) -- paquetes
// `pdf` (construye el documento) + `printing` (vista previa + guardar/
// compartir con los mecanismos propios de cada plataforma, el mismo
// patrón que ya usa Share.share en registro_detail_screen.dart/
// expediente_vivienda_screen.dart, solo que aquí el contenido es un PDF
// real en vez de texto). Todos los datos vienen del modelo real -- nunca
// un número escrito a mano aquí.
import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/casa.dart';
import '../../models/pago.dart';
import '../../models/registro.dart';
import '../../widgets/estado_registro_chip.dart';
import '../../widgets/pdf_fuente_unicode.dart';

// Mismos tonos de marca que ReparaColors.light (theme/design_tokens.dart)
// -- el paquete pdf no puede leer un ThemeExtension de Flutter, así que se
// repiten aquí como PdfColor. Si la paleta de marca cambia alguna vez,
// este es el único otro sitio que hay que tocar.
const _pdfBrandStrong = PdfColor.fromInt(0xFF183650);
const _pdfBrand = PdfColor.fromInt(0xFF42658B);
const _pdfSuccess = PdfColor.fromInt(0xFF23856D);
const _pdfInkMuted = PdfColor.fromInt(0xFF687789);
const _pdfBorder = PdfColor.fromInt(0xFFE5E3DE);

class RegistroResumenPdf {
  RegistroResumenPdf._();

  /// Descarga las fotos como bytes antes de montar el documento -- el
  /// paquete pdf no puede pedirlas por su cuenta durante el build. Una
  /// foto que falle al descargar simplemente no sale en el PDF -- nunca
  /// bloquea el resto del documento por un fallo de red puntual.
  static Future<List<Uint8List>> _descargarFotos(List<String> urls) async {
    final resultado = <Uint8List>[];
    for (final url in urls.take(4)) {
      try {
        final respuesta = await http.get(Uri.parse(url));
        if (respuesta.statusCode == 200) {
          resultado.add(respuesta.bodyBytes);
        }
      } catch (_) {
        // Decorativo -- una foto que no carga no debe impedir el resto
        // del PDF, igual que errorBuilder ya hace en pantalla.
      }
    }
    return resultado;
  }

  static Future<Uint8List> _construir({
    required Registro registro,
    required Casa casa,
    required List<Pago> pagos,
    required double totalPagado,
  }) async {
    // Fuente Unicode empaquetada como asset (CEO, octubre 2026) -- sin
    // esto, el "€" de cada importe se veía como un hueco en blanco: la
    // fuente base del PDF estándar (Helvetica) no tiene ese glifo. Ver
    // cargarTemaPdfUnicode en widgets/pdf_fuente_unicode.dart.
    final doc = pw.Document(theme: await cargarTemaPdfUnicode());
    final deuda = montoDebidoRegistro(registro);
    final saldo = deuda == null
        ? null
        : (deuda - totalPagado).clamp(0, double.infinity).toDouble();
    final fotos = await _descargarFotos(registro.fotos);
    final formatoFecha = DateFormat('d MMMM yyyy', 'es_ES');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
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
                      color: _pdfBrandStrong,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Resumen del trabajo',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: _pdfInkMuted,
                    ),
                  ),
                ],
              ),
              pw.Text(
                formatoFecha.format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 10, color: _pdfInkMuted),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Divider(color: _pdfBorder),
          pw.SizedBox(height: 14),
          pw.Text(
            registro.titulo,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${casa.nombre} · ${registro.elementoNombre} · ${nombreTipoRegistro(registro.tipo)}',
            style: const pw.TextStyle(fontSize: 11, color: _pdfInkMuted),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _etiquetaEstado(nombreEstadoRegistro(registro.estado)),
              pw.SizedBox(width: 10),
              pw.Text(
                formatoFecha.format(registro.fecha),
                style: const pw.TextStyle(fontSize: 10, color: _pdfInkMuted),
              ),
            ],
          ),
          if (registro.descripcion != null) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              registro.descripcion!,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
          if (registro.profesionalNombre != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Profesional: ${registro.profesionalNombre}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
          pw.SizedBox(height: 20),
          _tarjetaEconomica(deuda: deuda, pagado: totalPagado, saldo: saldo),
          if (pagos.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Pagos registrados',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _pdfBorder, width: 0.5),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                for (final p in pagos)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          DateFormat('d MMM yyyy', 'es_ES').format(p.fecha),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          p.concepto ?? '--',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          '${p.importe.toStringAsFixed(2)} €',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (fotos.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Fotografías',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in fotos)
                  pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(
                      pw.MemoryImage(f),
                      width: 120,
                      height: 90,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ],
          pw.SizedBox(height: 28),
          pw.Divider(color: _pdfBorder),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generado con REPARA.',
            style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _etiquetaEstado(String texto) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFEFF3F8),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Text(
      texto.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: _pdfBrand,
      ),
    ),
  );

  static pw.Widget _tarjetaEconomica({
    required double? deuda,
    required double pagado,
    required double? saldo,
  }) {
    pw.Widget columna(String etiqueta, String valor, {PdfColor? color}) =>
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                etiqueta.toUpperCase(),
                style: const pw.TextStyle(fontSize: 8, color: _pdfInkMuted),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                valor,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdfBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          columna(
            'Coste total',
            deuda == null ? '--' : '${deuda.toStringAsFixed(2)} €',
          ),
          columna(
            'Pagado',
            '${pagado.toStringAsFixed(2)} €',
            color: _pdfSuccess,
          ),
          columna(
            'Saldo pendiente',
            saldo == null ? '--' : '${saldo.toStringAsFixed(2)} €',
          ),
        ],
      ),
    );
  }

  /// Abre la vista previa de impresión/guardado del propio sistema
  /// operativo (Printing.layoutPdf) -- es el mecanismo real de "descargar"
  /// un PDF en iOS/Android sin añadir permisos ni rutas de archivo a
  /// mano: desde ahí el usuario ya puede guardar, imprimir o compartir.
  static Future<void> descargar(
    BuildContext context, {
    required Registro registro,
    required Casa casa,
    required List<Pago> pagos,
    required double totalPagado,
  }) async {
    await Printing.layoutPdf(
      name: 'Resumen - ${registro.titulo}',
      onLayout: (_) => _construir(
        registro: registro,
        casa: casa,
        pagos: pagos,
        totalPagado: totalPagado,
      ),
    );
  }
}
