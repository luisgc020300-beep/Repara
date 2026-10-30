// lib/widgets/pdf_imagenes.dart
//
// Descarga de fotos para un PDF (CEO, octubre 2026) -- extraído de
// expediente_vivienda_pdf.dart para que la ficha de elemento lo reutilice
// igual. En lotes paralelos (no secuencial, a diferencia del único
// precedente en registro_resumen_pdf.dart -- ahí bastaba para 4 fotos de
// un solo trabajo), con un tope global y timeout por petición, para que un
// documento con muchas fotos no deje la generación colgada. Una foto que
// falla (red, URL caducada, formato dañado) nunca debe impedir el resto
// del documento.
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const pdfMaxImagenesPorDefecto = 24;
const pdfTimeoutImagen = Duration(seconds: 8);
const pdfConcurrenciaDescargas = 6;

Future<Uint8List?> _descargarImagen(String url) async {
  try {
    final respuesta = await http.get(Uri.parse(url)).timeout(pdfTimeoutImagen);
    if (respuesta.statusCode == 200) return respuesta.bodyBytes;
  } catch (_) {
    // Decorativo -- ver nota de cabecera.
  }
  return null;
}

Future<Map<String, Uint8List>> descargarImagenesPdf(
  List<String> urls, {
  int maxTotal = pdfMaxImagenesPorDefecto,
}) async {
  final unicas = urls.toSet().take(maxTotal).toList();
  final resultado = <String, Uint8List>{};
  for (var i = 0; i < unicas.length; i += pdfConcurrenciaDescargas) {
    final lote = unicas.skip(i).take(pdfConcurrenciaDescargas).toList();
    final bytesLote = await Future.wait(lote.map(_descargarImagen));
    for (var j = 0; j < lote.length; j++) {
      final bytes = bytesLote[j];
      if (bytes != null) resultado[lote[j]] = bytes;
    }
  }
  return resultado;
}
