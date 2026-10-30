// lib/widgets/pdf_fuente_unicode.dart
//
// Fuente Unicode compartida por todos los PDF de REPARA (CEO, octubre
// 2026): la fuente base de cualquier PDF (Helvetica estándar) no tiene el
// glifo de "€" -- un primer intento usó PdfGoogleFonts (paquete printing)
// para traer Noto Sans por red, pero esa vía demostró no ser fiable: ante
// un fallo de descarga, el propio paquete cae en silencio a Helvetica sin
// lanzar ninguna excepción detectable, así que no hay forma de saber desde
// aquí si el símbolo se va a ver o no. La fuente se empaqueta ahora como
// asset del propio proyecto (TTF de Noto Sans, licencia SIL Open Font
// License, libre de redistribuir) -- funciona siempre, sin red, sin
// depender de que un CDN externo responda en el momento justo de generar
// un documento.
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

pw.ThemeData? _temaUnicodeCache;

/// Carga perezosa, una sola vez por sesión de la app (o por proceso de
/// test) -- generar varios PDF seguidos no vuelve a leer los TTF del
/// paquete de assets cada vez.
Future<pw.ThemeData> cargarTemaPdfUnicode() async {
  final cacheado = _temaUnicodeCache;
  if (cacheado != null) return cacheado;
  final regularBytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final boldBytes = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final tema = pw.ThemeData.withFont(
    base: pw.Font.ttf(regularBytes),
    bold: pw.Font.ttf(boldBytes),
  );
  _temaUnicodeCache = tema;
  return tema;
}
