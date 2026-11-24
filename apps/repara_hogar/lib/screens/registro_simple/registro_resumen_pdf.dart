// lib/screens/registro_simple/registro_resumen_pdf.dart
//
// PDF de un evento individual (CEO, octubre 2026 -- rediseño documental,
// noviembre 2026: "Informe de intervención") -- el más acotado de los tres
// documentos de REPARA: se centra solo en ESTA intervención y su
// trazabilidad (identificación, descripción, profesional, economía, pagos,
// fotos), nunca reproduce el historial completo del elemento ni de la
// vivienda -- eso ya lo cubren registro_resumen_pdf.dart's hermanos mayores
// (elemento_resumen_pdf.dart / expediente_vivienda_pdf.dart). Mismo sistema
// visual que esos dos (packages/repara_ui/lib/pdf_estilo.dart +
// widgets/pdf_trabajo.dart para el color de estado/nombre de método de
// pago + widgets/pdf_imagenes.dart para la descarga de fotos) -- ninguno de
// los otros dos documentos se toca en este rediseño.
//
// Paquetes `pdf` (construye el documento) + `printing` (vista previa +
// guardar/compartir con los mecanismos propios de cada plataforma, el mismo
// patrón que ya usa Share.share en registro_detail_screen.dart/
// expediente_vivienda_screen.dart, solo que aquí el contenido es un PDF
// real en vez de texto). Todos los datos vienen del modelo real -- nunca
// un número escrito a mano aquí.
import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/registro.dart';

import '../../models/casa.dart';
import '../../widgets/pdf_imagenes.dart';
import '../../widgets/pdf_trabajo.dart' show colorEstadoRegistroPdf, nombreMetodoPagoPdf;
import 'package:repara_ui/estado_registro_chip.dart' show nombreEstadoRegistro;
import 'package:repara_ui/pdf_estilo.dart';
import 'package:repara_ui/pdf_fuente_unicode.dart';

class RegistroResumenPdf {
  RegistroResumenPdf._();

  // Un solo evento rara vez tiene más fotos que esto -- tope generoso (antes
  // eran solo 4, ver nota de _descargarFotos más abajo) que evita a la vez
  // un documento desproporcionado y problemas de memoria.
  static const _maxFotos = 16;
  static const _margen = 36.0;

  /// Construye los bytes del PDF -- público (igual que
  /// ElementoResumenPdf.construirBytes) para que [descargar] y la
  /// verificación visual de prueba (registro_resumen_pdf_visual_test.dart)
  /// usen exactamente el mismo camino de generación, sin un segundo método
  /// paralelo solo para pruebas.
  static Future<Uint8List> construirBytes({
    required Registro registro,
    required Casa casa,
    required List<Pago> pagos,
    required double totalPagado,
  }) async {
    // Fuente Unicode empaquetada como asset (CEO, octubre 2026) -- sin
    // esto, el "€" de cada importe se veía como un hueco en blanco: la
    // fuente base del PDF estándar (Helvetica) no tiene ese glifo. Ver
    // cargarTemaPdfUnicode en pdf_fuente_unicode.dart.
    final doc = pw.Document(theme: await cargarTemaPdfUnicode());
    final coste = montoDebidoRegistro(registro);
    final saldo = coste == null
        ? null
        : (coste - totalPagado).clamp(0, double.infinity).toDouble();
    final formatoFecha = DateFormat('d MMMM yyyy', 'es_ES');
    final formatoFechaCorta = DateFormat('d MMM yyyy', 'es_ES');
    final profesionales = registro.listaProfesionales;

    // Descarga en lotes paralelos con timeout (CEO: "evitar bloqueos
    // durante la generación") -- el precedente de este archivo descargaba
    // secuencialmente sin timeout y limitaba a 4 fotos; ahora reutiliza el
    // mismo helper que ya usan los otros dos documentos de REPARA, así que
    // una foto caída nunca cuelga la generación y sí se incluyen todas las
    // fotos reales del evento (hasta _maxFotos).
    final imagenes = await descargarImagenesPdf(registro.fotos, maxTotal: _maxFotos);
    final fotos = [
      for (final url in registro.fotos)
        if (imagenes[url] != null) imagenes[url]!,
    ];

    final pagosOrdenados = [...pagos]..sort((a, b) => a.fecha.compareTo(b.fecha));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(_margen, 28, _margen, 28),
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
                      registro.titulo,
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
                'REPARA · Informe de ${registro.titulo}',
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
          // ============================================================
          // BLOQUE A -- Cabecera corporativa (solo primera página, el
          // header de arriba ya hace ese papel en el resto).
          // ============================================================
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
                    'Informe de intervención',
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
          // BLOQUE B -- Identificación de la intervención
          // ============================================================
          pw.Text(
            registro.titulo,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: pdfInk,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${casa.nombre} · ${registro.elementoNombre} · ${nombreTipoRegistro(registro.tipo)}',
            style: const pw.TextStyle(fontSize: 11, color: pdfInkMuted),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              etiquetaPdf(
                nombreEstadoRegistro(registro.estado),
                colorEstadoRegistroPdf(registro.estado),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                formatoFecha.format(registro.fecha),
                style: const pw.TextStyle(fontSize: 10, color: pdfInkMuted),
              ),
            ],
          ),

          // ============================================================
          // BLOQUE C -- Descripción del trabajo (solo si existe)
          // ============================================================
          if (registro.descripcion != null && registro.descripcion!.trim().isNotEmpty)
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 22),
                  tituloBloquePdf('Descripción del trabajo'),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    registro.descripcion!.trim(),
                    style: const pw.TextStyle(fontSize: 10.5, color: pdfInk, lineSpacing: 2),
                  ),
                ],
              ),
            ),

          // ============================================================
          // BLOQUE D -- Profesional (solo si hay alguno registrado)
          // ============================================================
          if (profesionales.isNotEmpty)
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 22),
                  tituloBloquePdf(
                    profesionales.length > 1 ? 'Profesionales' : 'Profesional',
                  ),
                  pw.SizedBox(height: 8),
                  for (var i = 0; i < profesionales.length; i++) ...[
                    if (i > 0) pw.SizedBox(height: 8),
                    pw.Text(
                      profesionales[i].nombre,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    if ((profesionales[i].telefono ?? '').isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        profesionales[i].telefono!,
                        style: const pw.TextStyle(fontSize: 9.5, color: pdfInkMuted),
                      ),
                    ],
                  ],
                ],
              ),
            ),

          // ============================================================
          // BLOQUE E -- Resumen económico
          // ============================================================
          if (coste != null || totalPagado > 0)
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 24),
                  tituloBloquePdf('Resumen económico'),
                  pw.SizedBox(height: 10),
                  franjaResumenPdf([
                    if (coste != null)
                      celdaDatoPdf(
                        etiqueta: 'Coste total',
                        valor: formatoImportePdf(coste),
                        tamanoValor: 16,
                      ),
                    celdaDatoPdf(
                      etiqueta: 'Pagado',
                      valor: formatoImportePdf(totalPagado),
                      tamanoValor: 16,
                      colorValor: pdfSuccess,
                    ),
                    if (saldo != null)
                      celdaDatoPdf(
                        etiqueta: 'Saldo pendiente',
                        valor: formatoImportePdf(saldo),
                        tamanoValor: 16,
                        colorValor: saldo > 0 ? pdfWarningText : pdfInkMuted,
                      ),
                  ]),
                  // "Si el trabajo está completamente pagado, debe quedar
                  // visualmente claro" -- una insignia discreta, no otra
                  // tarjeta ni un color de fondo distinto.
                  if (saldo != null && saldo <= 0) ...[
                    pw.SizedBox(height: 8),
                    etiquetaPdf('Pagado por completo', pdfSuccess),
                  ],
                ],
              ),
            ),

          // ============================================================
          // BLOQUE F -- Historial de pagos (solo si hay alguno)
          // ============================================================
          if (pagosOrdenados.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            tituloBloquePdf('Historial de pagos'),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: const ['FECHA', 'CONCEPTO', 'MÉTODO', 'IMPORTE'],
              data: [
                for (final p in pagosOrdenados)
                  [
                    formatoFechaCorta.format(p.fecha),
                    p.concepto ?? '--',
                    p.metodo != null ? nombreMetodoPagoPdf(p.metodo) : '--',
                    formatoImportePdf(p.importe),
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: pdfBrandStrong,
              ),
              headerDecoration: const pw.BoxDecoration(color: pdfBrandTint),
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              cellStyle: const pw.TextStyle(fontSize: 9.5, color: pdfInk),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
              columnWidths: const {
                0: pw.FixedColumnWidth(70),
                1: pw.FlexColumnWidth(),
                2: pw.FixedColumnWidth(75),
                3: pw.FixedColumnWidth(65),
              },
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: pdfBorder, width: 0.5),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  '${pagosOrdenados.length} ${pagosOrdenados.length == 1 ? 'pago registrado' : 'pagos registrados'} · Total ${formatoImportePdf(totalPagado)}',
                  style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
                ),
              ],
            ),
          ],

          // ============================================================
          // BLOQUE G -- Documentación fotográfica (solo si hay fotos)
          // ============================================================
          ..._bloqueFotos(fotos),

          // ============================================================
          // BLOQUE H -- Cierre documental
          // ============================================================
          pw.SizedBox(height: 26),
          pw.Divider(color: pdfBorder),
          pw.SizedBox(height: 6),
          pw.Text(
            'Informe generado con REPARA a partir de los datos registrados por el propietario.',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
          ),
        ],
      ),
    );
    return doc.save();
  }

  // -- Bloque G: cuadrícula de 2 columnas con proporciones naturales (CEO:
  // "mantengan sus proporciones originales... no aparezcan deformadas").
  // Cada fila es su propio elemento de nivel superior (nunca un único
  // Column con todo dentro) para que MultiPage pueda partir ENTRE filas si
  // hay muchas fotos -- nunca DENTRO de una fila, así que ninguna foto
  // queda nunca cortada a la mitad entre dos páginas. El título va unido a
  // la primera fila (pw.Inseparable) para que nunca quede solo al final de
  // una página sin ninguna foto debajo.
  static List<pw.Widget> _bloqueFotos(List<Uint8List> fotos) {
    if (fotos.isEmpty) return const [];
    const espaciado = 14.0;
    final anchoContenido = PdfPageFormat.a4.width - _margen * 2;
    final anchoFoto = (anchoContenido - espaciado) / 2;

    final filas = <pw.Widget>[];
    for (var i = 0; i < fotos.length; i += 2) {
      final par = fotos.skip(i).take(2).toList();
      filas.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < par.length; j++) ...[
              if (j > 0) pw.SizedBox(width: espaciado),
              _fotoProporcional(par[j], anchoFoto),
            ],
          ],
        ),
      );
      if (i + 2 < fotos.length) filas.add(pw.SizedBox(height: espaciado));
    }

    return [
      pw.SizedBox(height: 24),
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            tituloBloquePdf('Documentación fotográfica'),
            pw.SizedBox(height: 10),
            filas.first,
          ],
        ),
      ),
      ...filas.skip(1),
    ];
  }

  // Alto calculado a partir de la proporción real de la imagen decodificada
  // -- nunca una altura fija con fit:cover, que es justo lo que recortaba
  // las fotos de forma inadecuada en el documento anterior.
  static pw.Widget _fotoProporcional(Uint8List bytes, double ancho) {
    final img = pw.MemoryImage(bytes);
    final anchoNatural = img.width;
    final altoNatural = img.height;
    final alto = (anchoNatural != null && altoNatural != null && anchoNatural > 0)
        ? ancho * altoNatural / anchoNatural
        : ancho * 0.75;
    return pw.ClipRRect(
      horizontalRadius: 8,
      verticalRadius: 8,
      child: pw.Image(img, width: ancho, height: alto, fit: pw.BoxFit.contain),
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
      name: 'Informe - ${registro.titulo}',
      onLayout: (_) => construirBytes(
        registro: registro,
        casa: casa,
        pagos: pagos,
        totalPagado: totalPagado,
      ),
    );
  }
}
