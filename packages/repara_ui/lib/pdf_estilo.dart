// packages/repara_ui/lib/pdf_estilo.dart
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
// Tinte muy suave del azul de marca -- fondo de los bloques de estadísticas/
// resumen económico (rediseño de la ficha de elemento, noviembre 2026):
// nunca un color llamativo, solo lo justo para separar visualmente esos
// bloques del resto del documento sin añadir otra tarjeta con borde.
const pdfBrandTint = PdfColor.fromInt(0xFFF1F4F8);

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

// Cabecera de sección con una barra de acento en el color de marca -- mismo
// criterio en todos los documentos de Repara (rediseño del expediente de
// elemento, noviembre 2026): más presencia que un simple texto en negrita,
// sin necesitar una tarjeta ni un fondo de color para marcar el cambio de
// bloque.
pw.Widget tituloBloquePdf(String texto) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.center,
  children: [
    pw.Container(width: 3, height: 13, color: pdfBrandStrong),
    pw.SizedBox(width: 7),
    pw.Text(
      texto,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: pdfBrandStrong,
      ),
    ),
  ],
);

/// Una celda "etiqueta pequeña arriba, valor en negrita abajo" -- pieza base
/// de los bloques de identificación, estadísticas y resumen económico de
/// la ficha de elemento. Reutilizable por cualquier otro documento de
/// Repara que necesite la misma composición (coherencia visual, ver
/// cabecera de este archivo).
pw.Widget celdaDatoPdf({
  required String etiqueta,
  required String valor,
  PdfColor? colorValor,
  double tamanoValor = 11,
  pw.CrossAxisAlignment alineacion = pw.CrossAxisAlignment.start,
}) => pw.Column(
  crossAxisAlignment: alineacion,
  mainAxisSize: pw.MainAxisSize.min,
  children: [
    pw.Text(
      etiqueta.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 7.5,
        color: pdfInkMuted,
        letterSpacing: 0.4,
      ),
    ),
    pw.SizedBox(height: 2),
    pw.Text(
      valor,
      style: pw.TextStyle(
        fontSize: tamanoValor,
        fontWeight: pw.FontWeight.bold,
        color: colorValor ?? pdfInk,
      ),
    ),
  ],
);

/// Una cifra grande de [etiqueta]/[valor] (bloque de resumen económico) --
/// [destacado] la pinta en el color de aviso, para el saldo pendiente
/// cuando es mayor que cero (mismo criterio que el resto de Repara: el
/// color señala lo que requiere atención, nunca decoración porque sí).
pw.Widget cifraResumenPdf({
  required String etiqueta,
  required String valor,
  bool destacado = false,
}) => celdaDatoPdf(
  etiqueta: etiqueta,
  valor: valor,
  colorValor: destacado ? pdfWarningText : pdfBrandStrong,
  tamanoValor: 15,
);

/// Franja de fondo suave con una fila de [celdaDatoPdf]/[cifraResumenPdf]
/// repartidas a partes iguales -- usada tanto por el resumen del estado
/// (Bloque B) como por el resumen económico (Bloque C) de la ficha de
/// elemento, para que ambos bloques se vean como una misma familia visual.
pw.Widget franjaResumenPdf(List<pw.Widget> celdas) {
  if (celdas.isEmpty) return pw.SizedBox();
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: pw.BoxDecoration(
      color: pdfBrandTint,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      children: [
        for (var i = 0; i < celdas.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 14),
          pw.Expanded(child: celdas[i]),
        ],
      ],
    ),
  );
}

// Un documento capturado con la cámara puede llegar con el nombre técnico
// interno que le puso el selector de imagen (p.ej. "image_picker_12345...
// .jpg") en vez de uno escrito por el usuario (rediseño del expediente de
// vivienda, noviembre 2026: "nunca mostrar... cadenas como image_picker_…").
// Nunca se modifica el dato guardado -- esto solo decide qué texto mostrar
// EN EL PDF, sustituyendo por una denominación descriptiva (tipo + fecha)
// cuando el nombre de archivo no parece haberlo escrito una persona.
final RegExp _patronNombreTecnicoPdf = RegExp(
  r'^(image_picker|scaled_|trimmed_|cache|file_picker|tmp|img_\d{10,}|[0-9a-f]{16,}|[0-9]{10,})',
  caseSensitive: false,
);

String nombreDocumentoLegiblePdf(
  String nombreArchivo,
  String etiquetaTipo, {
  String? fechaTexto,
}) {
  final base = nombreArchivo.split('.').first.trim();
  final pareceTecnico = base.isEmpty || _patronNombreTecnicoPdf.hasMatch(base);
  if (!pareceTecnico) return nombreArchivo;
  return fechaTexto != null ? '$etiquetaTipo · $fechaTexto' : etiquetaTipo;
}

/// Igual que [miniaturaPdf] pero sin forzar un cuadrado: la altura se
/// calcula a partir de la proporción real de la imagen decodificada, nunca
/// con `fit: cover` recortando -- "que no aparezcan deformadas ni
/// recortadas de manera inadecuada" (rediseño documental, noviembre 2026).
pw.Widget fotoProporcionalPdf(
  Uint8List bytes,
  double ancho, {
  double bordeRadius = 8,
  double relacionAspectoAlternativa = 0.75,
}) {
  final img = pw.MemoryImage(bytes);
  final anchoNatural = img.width;
  final altoNatural = img.height;
  final alto = (anchoNatural != null && altoNatural != null && anchoNatural > 0)
      ? ancho * altoNatural / anchoNatural
      : ancho * relacionAspectoAlternativa;
  return pw.ClipRRect(
    horizontalRadius: bordeRadius,
    verticalRadius: bordeRadius,
    child: pw.Image(img, width: ancho, height: alto, fit: pw.BoxFit.contain),
  );
}

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
