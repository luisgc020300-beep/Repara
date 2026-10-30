// lib/screens/expediente_vivienda_pdf.dart
//
// Dossier PDF de la vivienda (CEO, octubre 2026) -- documento editorial
// completo, no una impresión de la pantalla de resumen: portada, índice,
// resumen, fichas de elementos, historial completo de trabajos (todos los
// estados, no solo los terminados -- más completo que la lista en pantalla
// a propósito, ver _construirBody), documentación, garantías clasificadas
// y galería de fotos de trabajo. Mismos paquetes que registro_resumen_pdf.
// dart (pdf + printing + http, ya en pubspec.yaml) -- no se añade ninguna
// dependencia nueva. Todos los datos vienen de los modelos reales; un campo
// ausente simplemente no aparece, nunca se inventa ni se rellena.
//
// Privacidad (sección 6 del encargo): nunca se imprime un id de Firestore,
// un token ni una URL de Storage como texto visible -- las URLs solo se
// usan para descargar bytes de imagen. El nombre de archivo que el propio
// usuario subió (Documento.nombreArchivo) SÍ se muestra -- no es un
// identificador interno, es un dato que el usuario ya conoce y escribió.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/cambio_alcance.dart';
import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import '../models/pago.dart';
import '../models/registro.dart';
import '../widgets/estado_registro_chip.dart' show nombreEstadoRegistro;
import '../widgets/pdf_fuente_unicode.dart';

// Mismos tonos de marca que registro_resumen_pdf.dart / ReparaColors.light
// (theme/design_tokens.dart) -- el paquete pdf no puede leer un
// ThemeExtension de Flutter, así que se repiten aquí como PdfColor.
const _pdfBrandStrong = PdfColor.fromInt(0xFF183650);
const _pdfBrand = PdfColor.fromInt(0xFF42658B);
const _pdfInk = PdfColor.fromInt(0xFF203044);
const _pdfInkMuted = PdfColor.fromInt(0xFF687789);
const _pdfBorder = PdfColor.fromInt(0xFFE5E3DE);
const _pdfSurfaceSunken = PdfColor.fromInt(0xFFE8E5DD);
const _pdfSuccess = PdfColor.fromInt(0xFF23856D);
const _pdfWarningText = PdfColor.fromInt(0xFF8A5A1F);
const _pdfErrorText = PdfColor.fromInt(0xFFC23B3B);

// El símbolo "€" se ve de verdad gracias a la fuente Unicode empaquetada
// como asset del proyecto -- ver cargarTemaPdfUnicode en
// widgets/pdf_fuente_unicode.dart (nunca depende de red).
String _formatoImporte(double v) =>
    '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)} €';

String _nombreTipoDocumento(TipoDocumento t) => switch (t) {
  TipoDocumento.factura => 'Factura',
  TipoDocumento.presupuesto => 'Presupuesto',
  TipoDocumento.garantia => 'Garantía',
  TipoDocumento.manual => 'Manual',
  TipoDocumento.contrato => 'Contrato',
  TipoDocumento.otro => 'Otro',
};

String _nombreMetodoPago(MetodoPago? m) => switch (m) {
  MetodoPago.bizum => 'Bizum',
  MetodoPago.transferencia => 'Transferencia',
  MetodoPago.efectivo => 'Efectivo',
  MetodoPago.tarjeta => 'Tarjeta',
  MetodoPago.otro => 'Otro',
  null => '',
};

enum _EstadoGarantia { vigente, proxima, vencida, desconocida }

_EstadoGarantia _clasificarGarantia(DateTime? hasta) {
  if (hasta == null) return _EstadoGarantia.desconocida;
  final ahora = DateTime.now();
  if (hasta.isBefore(ahora)) return _EstadoGarantia.vencida;
  if (hasta.isBefore(ahora.add(const Duration(days: 30)))) {
    return _EstadoGarantia.proxima;
  }
  return _EstadoGarantia.vigente;
}

// pdf.Image solo decodifica formatos raster estándar -- un documento subido
// como PDF (o cualquier extensión que no reconozcamos) nunca se "incrusta"
// como si fuera una foto, solo se identifica con una ficha (sección 5 del
// encargo: "no afirmes que se ha incluido un archivo si solo se muestra su
// nombre").
bool _esImagenEmbebible(String nombreArchivo) {
  final ext = nombreArchivo.toLowerCase().split('.').lastOrNull;
  return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
}

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

/// Un trabajo (Registro) con sus pagos y cambios de alcance ya resueltos --
/// agregado por quien llama (ExpedienteViviendaScreen), nunca por este
/// fichero: aquí solo se maqueta, nunca se decide qué leer de Firestore.
class TrabajoConDetalle {
  const TrabajoConDetalle({
    required this.registro,
    this.pagos = const [],
    this.cambios = const [],
  });

  final Registro registro;
  final List<Pago> pagos;
  final List<CambioAlcance> cambios;

  double get totalPagado => pagos.fold(0, (acc, p) => acc + p.importe);
}

class ExpedienteViviendaPdf {
  ExpedienteViviendaPdf._();

  // Límite global de fotos a descargar para todo el dossier (no por
  // sección) -- una vivienda con muchos elementos/trabajos/documentos no
  // debe disparar decenas de descargas; prioriza identificación (portada de
  // cada elemento) sobre detalle (fotos de trabajo, documentos escaneados).
  static const _maxImagenesTotal = 24;
  static const _timeoutImagen = Duration(seconds: 8);
  static const _concurrenciaDescargas = 6;

  static Future<Uint8List?> _descargarImagen(String url) async {
    try {
      final respuesta = await http.get(Uri.parse(url)).timeout(_timeoutImagen);
      if (respuesta.statusCode == 200) return respuesta.bodyBytes;
    } catch (_) {
      // Una foto que falla (red, URL caducada, formato dañado) nunca debe
      // impedir el resto del dossier -- mismo criterio que ya usa
      // registro_resumen_pdf.dart.
    }
    return null;
  }

  /// Descarga en lotes paralelos (no secuencial, a diferencia del único
  /// precedente en registro_resumen_pdf.dart -- ahí bastaba para 4 fotos de
  /// un solo trabajo, aquí puede haber muchas más URLs de toda la
  /// vivienda) con un tope global y timeout por petición, para que una
  /// vivienda con mucho contenido no deje la generación colgada.
  static Future<Map<String, Uint8List>> _descargarImagenes(
    List<String> urls,
  ) async {
    final unicas = urls.toSet().take(_maxImagenesTotal).toList();
    final resultado = <String, Uint8List>{};
    for (var i = 0; i < unicas.length; i += _concurrenciaDescargas) {
      final lote = unicas.skip(i).take(_concurrenciaDescargas).toList();
      final bytesLote = await Future.wait(lote.map(_descargarImagen));
      for (var j = 0; j < lote.length; j++) {
        final bytes = bytesLote[j];
        if (bytes != null) resultado[lote[j]] = bytes;
      }
    }
    return resultado;
  }

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
    final nombreHabitacion = {for (final h in habitaciones) h.id: h.nombre};
    final nombreElemento = {for (final e in elementos) e.id: e.nombre};

    // Documentos todavía sin confirmar (borrador de IA, ver EstadoIA) no son
    // un hecho confirmado -- un dossier que se puede compartir con un
    // tercero no debe presentarlos como si lo fueran.
    final documentosConfirmados = documentos
        .where((d) => d.estadoIA != EstadoIA.pendiente)
        .toList();

    // Recopila, por prioridad (identificación antes que detalle), las URLs
    // a descargar, respetando el tope global -- ver _descargarImagenes.
    final urlsAFetch = <String>[
      for (final e in elementos)
        if (e.fotoUrl != null) e.fotoUrl!,
      for (final t in trabajos)
        for (final f in t.registro.fotos.take(2)) f,
      for (final d in documentosConfirmados)
        if (_esImagenEmbebible(d.nombreArchivo)) d.url,
    ];
    final imagenes = await _descargarImagenes(urlsAFetch);
    final doc = pw.Document(theme: await cargarTemaPdfUnicode());

    // ---- Portada ------------------------------------------------------
    // Casa no tiene ni dirección ni foto propia (solo fotos de miembro) --
    // portada tipográfica, nunca una imagen de relleno inventada.
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (context) => pw.Container(
          width: double.infinity,
          height: double.infinity,
          color: _pdfBrandStrong,
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
                    'Dossier de la vivienda',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    casa.nombre,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Generado el ${formatoFecha.format(DateTime.now())}',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // ---- Cuerpo ---------------------------------------------------------
    final finalizados = trabajos
        .where(
          (t) =>
              t.registro.estado == EstadoRegistro.terminado ||
              t.registro.estado == EstadoRegistro.archivado,
        )
        .toList();
    final costeTotal = finalizados.fold<double>(
      0,
      (acc, t) => acc + (montoDebidoRegistro(t.registro) ?? 0),
    );
    final porGarantia = <_EstadoGarantia, List<Elemento>>{};
    for (final e in elementos) {
      porGarantia.putIfAbsent(_clasificarGarantia(e.garantiaHasta), () => []).add(e);
    }

    final trabajosConFotos = trabajos
        .where((t) => t.registro.fotos.isNotEmpty)
        .toList();

    final secciones = <String>[
      'Resumen de la vivienda',
      if (elementos.isNotEmpty) 'Elementos e instalaciones',
      if (trabajos.isNotEmpty) 'Historial de trabajos',
      if (documentosConfirmados.isNotEmpty) 'Documentación',
      if (elementos.any((e) => e.garantiaHasta != null)) 'Garantías',
      if (trabajosConFotos.isNotEmpty) 'Fotografías de los trabajos',
      'Sobre este documento',
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _pdfBorder, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'REPARA',
                style: pw.TextStyle(
                  color: _pdfBrandStrong,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              pw.Text(
                casa.nombre,
                style: const pw.TextStyle(color: _pdfInkMuted, fontSize: 9),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _pdfBorder, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dossier generado con REPARA',
                style: const pw.TextStyle(color: _pdfInkMuted, fontSize: 8),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(color: _pdfInkMuted, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          // -- Índice (sin numeración -- ver nota en el informe final) --
          pw.Text(
            'Contenido',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _pdfInkMuted,
            ),
          ),
          pw.SizedBox(height: 6),
          for (final s in secciones)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '· $s',
                style: const pw.TextStyle(fontSize: 10, color: _pdfInk),
              ),
            ),
          pw.SizedBox(height: 22),

          // -- Resumen de la vivienda --
          _tituloSeccion('Resumen de la vivienda'),
          pw.SizedBox(height: 10),
          _tarjetaResumen(
            elementos: elementos.length,
            trabajosFinalizados: finalizados.length,
            garantiasVigentes: porGarantia[_EstadoGarantia.vigente]?.length ?? 0,
            documentos: documentosConfirmados.length,
            costeTotal: costeTotal,
          ),

          // -- Elementos --
          if (elementos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            _tituloSeccion('Elementos e instalaciones (${elementos.length})'),
            pw.SizedBox(height: 10),
            for (final e in elementos)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: _fichaElemento(
                  e,
                  ubicacion: e.habitacionId != null
                      ? nombreHabitacion[e.habitacionId]
                      : null,
                  foto: e.fotoUrl != null ? imagenes[e.fotoUrl!] : null,
                  formatoMes: formatoMes,
                ),
              ),
          ],

          // -- Historial de trabajos (TODOS los estados, no solo los
          // terminados -- un dossier es más completo que el resumen rápido
          // en pantalla; el estado real de cada uno se respeta tal cual) --
          if (trabajos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            _tituloSeccion('Historial de trabajos (${trabajos.length})'),
            pw.SizedBox(height: 10),
            for (final t in trabajos)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: _fichaTrabajo(t, formatoFechaCorta: formatoFechaCorta),
              ),
          ],

          // -- Documentación --
          if (documentosConfirmados.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            _tituloSeccion('Documentación (${documentosConfirmados.length})'),
            pw.SizedBox(height: 10),
            for (final d in documentosConfirmados)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: _fichaDocumento(
                  d,
                  elementoNombre: nombreElemento[d.elementoId],
                  foto: _esImagenEmbebible(d.nombreArchivo)
                      ? imagenes[d.url]
                      : null,
                  formatoFechaCorta: formatoFechaCorta,
                ),
              ),
          ],

          // -- Garantías -- (al menos un elemento con garantiaHasta real;
          // si todos la tienen ausente, "desconocida" no cuenta como
          // sección con contenido -- ver _seccionGarantias, que nunca
          // pinta ese grupo).
          if (elementos.any((e) => e.garantiaHasta != null)) ...[
            pw.SizedBox(height: 26),
            _tituloSeccion('Garantías'),
            pw.SizedBox(height: 10),
            _seccionGarantias(porGarantia, formatoMes),
          ],

          // -- Fotografías de los trabajos --
          if (trabajosConFotos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            _tituloSeccion('Fotografías de los trabajos'),
            pw.SizedBox(height: 10),
            for (final t in trabajosConFotos)
              _galeriaTrabajo(t, imagenes),
          ],

          // -- Cierre --
          pw.SizedBox(height: 26),
          _tituloSeccion('Sobre este documento'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Este dossier organiza la información que el propietario ha '
            'registrado en REPARA sobre esta vivienda hasta la fecha de '
            'generación. No constituye por sí mismo una inspección '
            'técnica, una certificación, una tasación ni una garantía '
            'legal, y no confirma que los documentos incluidos sigan '
            'vigentes. REPARA no afirma que la vivienda cumpla ninguna '
            'normativa ni que sus instalaciones estén libres de defectos.',
            style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _tituloSeccion(String texto) => pw.Text(
    texto,
    style: pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: _pdfBrandStrong,
    ),
  );

  static pw.Widget _etiqueta(String texto, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFEFF3F8),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Text(
      texto.toUpperCase(),
      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: color),
    ),
  );

  static pw.Widget _miniatura(Uint8List? bytes, {double size = 64}) {
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

  static pw.Widget _tarjetaResumen({
    required int elementos,
    required int trabajosFinalizados,
    required int garantiasVigentes,
    required int documentos,
    required double costeTotal,
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
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: color ?? _pdfBrandStrong,
                ),
              ),
            ],
          ),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _pdfSurfaceSunken,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              columna('Elementos', '$elementos'),
              columna('Trabajos finalizados', '$trabajosFinalizados'),
              columna('Garantías vigentes', '$garantiasVigentes'),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              columna('Documentos', '$documentos'),
              columna(
                'Invertido en trabajos finalizados',
                _formatoImporte(costeTotal),
                color: _pdfSuccess,
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _fichaElemento(
    Elemento e, {
    required String? ubicacion,
    required Uint8List? foto,
    required DateFormat formatoMes,
  }) {
    final garantia = _clasificarGarantia(e.garantiaHasta);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdfBorder),
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
                    if (e.archivado) _etiqueta('Archivado', _pdfInkMuted),
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
                  style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
                ),
                if (e.profesionalNombre != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Profesional: ${e.profesionalNombre}',
                    style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    if (e.garantiaHasta != null)
                      _etiqueta(
                        switch (garantia) {
                          _EstadoGarantia.vigente => 'Garantía vigente',
                          _EstadoGarantia.proxima => 'Garantía próxima a vencer',
                          _EstadoGarantia.vencida => 'Garantía vencida',
                          _EstadoGarantia.desconocida => 'Garantía',
                        },
                        switch (garantia) {
                          _EstadoGarantia.vigente => _pdfSuccess,
                          _EstadoGarantia.proxima => _pdfWarningText,
                          _EstadoGarantia.vencida => _pdfErrorText,
                          _EstadoGarantia.desconocida => _pdfInkMuted,
                        },
                      ),
                    if (e.coste != null) ...[
                      pw.SizedBox(width: 6),
                      pw.Text(
                        _formatoImporte(e.coste!),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (foto != null) ...[pw.SizedBox(width: 10), _miniatura(foto)],
        ],
      ),
    );
  }

  static pw.Widget _fichaTrabajo(
    TrabajoConDetalle t, {
    required DateFormat formatoFechaCorta,
  }) {
    final r = t.registro;
    final monto = montoDebidoRegistro(r);
    final estadoColor = switch (r.estado) {
      EstadoRegistro.terminado || EstadoRegistro.archivado => _pdfSuccess,
      EstadoRegistro.pendientePago => _pdfWarningText,
      _ => _pdfInkMuted,
    };
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdfBorder),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  r.titulo,
                  style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
              _etiqueta(nombreEstadoRegistro(r.estado), estadoColor),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${r.elementoNombre} · ${formatoFechaCorta.format(r.fecha)}',
            style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
          ),
          if (r.profesionalNombre != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Profesional: ${r.profesionalNombre}',
              style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
            ),
          ],
          if (monto != null || t.pagos.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              [
                if (monto != null) 'Acordado: ${_formatoImporte(monto)}',
                if (t.pagos.isNotEmpty) 'Pagado: ${_formatoImporte(t.totalPagado)}',
                if (monto != null)
                  'Saldo: ${_formatoImporte((monto - t.totalPagado).clamp(0, double.infinity))}',
              ].join('  ·  '),
              style: const pw.TextStyle(fontSize: 9.5, color: _pdfInk),
            ),
          ],
          for (final p in t.pagos) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              '· ${formatoFechaCorta.format(p.fecha)}'
              '${p.concepto != null ? ' -- ${p.concepto}' : ''}'
              '${p.metodo != null ? ' (${_nombreMetodoPago(p.metodo)})' : ''}'
              ': ${_formatoImporte(p.importe)}',
              style: const pw.TextStyle(fontSize: 8.5, color: _pdfInkMuted),
            ),
          ],
          for (final c in t.cambios) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              '+ Cambio de alcance: ${c.titulo}'
              '${c.importeAdicional != null ? ' (${_formatoImporte(c.importeAdicional!)})' : ''}'
              ' -- ${switch (c.estado) {
                EstadoCambioAlcance.aprobado => 'aprobado',
                EstadoCambioAlcance.rechazado => 'rechazado',
                EstadoCambioAlcance.cancelado => 'cancelado',
                EstadoCambioAlcance.pendiente => 'pendiente',
              }}',
              style: const pw.TextStyle(fontSize: 8.5, color: _pdfInkMuted),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _fichaDocumento(
    Documento d, {
    required String? elementoNombre,
    required Uint8List? foto,
    required DateFormat formatoFechaCorta,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdfBorder),
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
                    _etiqueta(_nombreTipoDocumento(d.tipo), _pdfBrand),
                    if (d.fecha != null) ...[
                      pw.SizedBox(width: 6),
                      pw.Text(
                        formatoFechaCorta.format(d.fecha!),
                        style: const pw.TextStyle(fontSize: 8.5, color: _pdfInkMuted),
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  d.nombreArchivo,
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                ),
                if (d.proveedor != null || elementoNombre != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    [
                      if (d.proveedor != null) d.proveedor!,
                      if (elementoNombre != null) 'vinculado a $elementoNombre',
                    ].join(' · '),
                    style: const pw.TextStyle(fontSize: 9, color: _pdfInkMuted),
                  ),
                ],
                if (d.descripcionTrabajo != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    d.descripcionTrabajo!,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          if (d.importe != null) ...[
            pw.SizedBox(width: 10),
            pw.Text(
              _formatoImporte(d.importe!),
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (foto != null) ...[pw.SizedBox(width: 10), _miniatura(foto, size: 48)],
        ],
      ),
    );
  }

  static pw.Widget _seccionGarantias(
    Map<_EstadoGarantia, List<Elemento>> porGarantia,
    DateFormat formatoMes,
  ) {
    pw.Widget grupo(String titulo, PdfColor color, List<Elemento> lista) {
      if (lista.isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$titulo (${lista.length})',
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: color),
            ),
            pw.SizedBox(height: 4),
            for (final e in lista)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2, left: 4),
                child: pw.Text(
                  '${e.nombre}${e.garantiaHasta != null ? ' - hasta ${formatoMes.format(e.garantiaHasta!)}' : ''}',
                  style: const pw.TextStyle(fontSize: 9.5),
                ),
              ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        grupo('Vigentes', _pdfSuccess, porGarantia[_EstadoGarantia.vigente] ?? []),
        grupo('Próximas a vencer', _pdfWarningText, porGarantia[_EstadoGarantia.proxima] ?? []),
        grupo('Vencidas', _pdfErrorText, porGarantia[_EstadoGarantia.vencida] ?? []),
      ],
    );
  }

  static pw.Widget _galeriaTrabajo(
    TrabajoConDetalle t,
    Map<String, Uint8List> imagenes,
  ) {
    final fotos = t.registro.fotos
        .take(2)
        .map((url) => imagenes[url])
        .whereType<Uint8List>()
        .toList();
    if (fotos.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${t.registro.titulo} · ${t.registro.elementoNombre}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
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
                    width: 150,
                    height: 112,
                    fit: pw.BoxFit.cover,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
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
      name: 'Dossier - ${casa.nombre}',
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
