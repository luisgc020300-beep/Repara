// lib/widgets/pdf_estilo.dart
//
// Estilo visual compartido por todos los PDF de REPARA (CEO, octubre
// 2026): antes cada generador de PDF (registro_resumen_pdf.dart,
// expediente_vivienda_pdf.dart) repetía sus propios tonos de marca y
// helpers de maquetación -- al añadir un tercer documento (ficha de
// elemento), extraerlos aquí evita triplicar el mismo código y garantiza
// que los tres documentos se vean exactamente igual de "REPARA
// Professional". Mismos tonos que ReparaColors.light (theme/design_tokens.
// dart) -- el paquete pdf no puede leer un ThemeExtension de Flutter, así
// que se repiten aquí como PdfColor.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const pdfBrandStrong = PdfColor.fromInt(0xFF183650);
const pdfBrand = PdfColor.fromInt(0xFF42658B);
const pdfInk = PdfColor.fromInt(0xFF203044);
const pdfInkMuted = PdfColor.fromInt(0xFF687789);
const pdfBorder = PdfColor.fromInt(0xFFE5E3DE);
const pdfSurfaceSunken = PdfColor.fromInt(0xFFE8E5DD);
const pdfSuccess = PdfColor.fromInt(0xFF23856D);
const pdfWarningText = PdfColor.fromInt(0xFF8A5A1F);
const pdfErrorText = PdfColor.fromInt(0xFFC23B3B);

// El símbolo "€" se ve de verdad gracias a la fuente Unicode empaquetada
// como asset del proyecto -- ver cargarTemaPdfUnicode en
// pdf_fuente_unicode.dart (nunca depende de red).
String formatoImportePdf(double v) =>
    '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)} €';

pw.Widget tituloSeccionPdf(String texto) => pw.Text(
  texto,
  style: pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color: pdfBrandStrong,
  ),
);

pw.Widget etiquetaPdf(String texto, PdfColor color) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
  decoration: pw.BoxDecoration(
    color: PdfColor.fromInt(0xFFEFF3F8),
    borderRadius: pw.BorderRadius.circular(10),
  ),
  child: pw.Text(
    texto.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 7.5,
      fontWeight: pw.FontWeight.bold,
      color: color,
    ),
  ),
);

pw.Widget miniaturaPdf(Uint8List? bytes, {double size = 64}) {
  if (bytes == null) return pw.SizedBox(width: size, height: size);
  return pw.ClipRRect(
    horizontalRadius: 6,
    verticalRadius: 6,
    child: pw.Image(
      pw.MemoryImage(bytes),
      width: size,
      height: size,
      fit: pw.BoxFit.cover,
    ),
  );
}
