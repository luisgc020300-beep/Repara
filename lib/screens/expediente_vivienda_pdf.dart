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
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/casa.dart';
import '../models/documento.dart';
import '../models/elemento.dart';
import '../models/habitacion.dart';
import '../models/registro.dart';
import '../widgets/pdf_estilo.dart';
import '../widgets/pdf_fuente_unicode.dart';
import '../widgets/pdf_imagenes.dart';
import '../widgets/pdf_trabajo.dart';

String _nombreTipoDocumento(TipoDocumento t) => switch (t) {
  TipoDocumento.factura => 'Factura',
  TipoDocumento.presupuesto => 'Presupuesto',
  TipoDocumento.garantia => 'Garantía',
  TipoDocumento.manual => 'Manual',
  TipoDocumento.contrato => 'Contrato',
  TipoDocumento.otro => 'Otro',
};

class ExpedienteViviendaPdf {
  ExpedienteViviendaPdf._();

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
        if (esImagenEmbebiblePdf(d.nombreArchivo)) d.url,
    ];
    final imagenes = await descargarImagenesPdf(urlsAFetch);
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
          color: pdfBrandStrong,
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
    final porGarantia = <EstadoGarantiaPdf, List<Elemento>>{};
    for (final e in elementos) {
      porGarantia.putIfAbsent(clasificarGarantiaPdf(e.garantiaHasta), () => []).add(e);
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
                casa.nombre,
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
                'Dossier generado con REPARA',
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
          // -- Índice (sin numeración -- ver nota en el informe final) --
          pw.Text(
            'Contenido',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: pdfInkMuted,
            ),
          ),
          pw.SizedBox(height: 6),
          for (final s in secciones)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '· $s',
                style: const pw.TextStyle(fontSize: 10, color: pdfInk),
              ),
            ),
          pw.SizedBox(height: 22),

          // -- Resumen de la vivienda --
          tituloSeccionPdf('Resumen de la vivienda'),
          pw.SizedBox(height: 10),
          _tarjetaResumen(
            elementos: elementos.length,
            trabajosFinalizados: finalizados.length,
            garantiasVigentes: porGarantia[EstadoGarantiaPdf.vigente]?.length ?? 0,
            documentos: documentosConfirmados.length,
            costeTotal: costeTotal,
          ),

          // -- Elementos --
          if (elementos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloSeccionPdf('Elementos e instalaciones (${elementos.length})'),
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
            tituloSeccionPdf('Historial de trabajos (${trabajos.length})'),
            pw.SizedBox(height: 10),
            for (final t in trabajos)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: fichaTrabajoPdf(t, formatoFechaCorta: formatoFechaCorta),
              ),
          ],

          // -- Documentación --
          if (documentosConfirmados.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloSeccionPdf('Documentación (${documentosConfirmados.length})'),
            pw.SizedBox(height: 10),
            for (final d in documentosConfirmados)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: _fichaDocumento(
                  d,
                  elementoNombre: nombreElemento[d.elementoId],
                  foto: esImagenEmbebiblePdf(d.nombreArchivo)
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
            tituloSeccionPdf('Garantías'),
            pw.SizedBox(height: 10),
            _seccionGarantias(porGarantia, formatoMes),
          ],

          // -- Fotografías de los trabajos --
          if (trabajosConFotos.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            tituloSeccionPdf('Fotografías de los trabajos'),
            pw.SizedBox(height: 10),
            for (final t in trabajosConFotos)
              galeriaTrabajoPdf(t, imagenes),
          ],

          // -- Cierre --
          pw.SizedBox(height: 26),
          tituloSeccionPdf('Sobre este documento'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Este dossier organiza la información que el propietario ha '
            'registrado en REPARA sobre esta vivienda hasta la fecha de '
            'generación. No constituye por sí mismo una inspección '
            'técnica, una certificación, una tasación ni una garantía '
            'legal, y no confirma que los documentos incluidos sigan '
            'vigentes. REPARA no afirma que la vivienda cumpla ninguna '
            'normativa ni que sus instalaciones estén libres de defectos.',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
          ),
        ],
      ),
    );

    return doc.save();
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
                style: const pw.TextStyle(fontSize: 8, color: pdfInkMuted),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                valor,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: color ?? pdfBrandStrong,
                ),
              ),
            ],
          ),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: pdfSurfaceSunken,
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
                formatoImportePdf(costeTotal),
                color: pdfSuccess,
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
    final garantia = clasificarGarantiaPdf(e.garantiaHasta);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: pdfBorder),
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
                    if (e.archivado) etiquetaPdf('Archivado', pdfInkMuted),
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
                  style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
                ),
                if (e.profesionalNombre != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Profesional: ${e.profesionalNombre}',
                    style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    if (e.garantiaHasta != null)
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
                    if (e.coste != null) ...[
                      pw.SizedBox(width: 6),
                      pw.Text(
                        formatoImportePdf(e.coste!),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (foto != null) ...[pw.SizedBox(width: 10), miniaturaPdf(foto)],
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
        border: pw.Border.all(color: pdfBorder),
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
                    etiquetaPdf(_nombreTipoDocumento(d.tipo), pdfBrand),
                    if (d.fecha != null) ...[
                      pw.SizedBox(width: 6),
                      pw.Text(
                        formatoFechaCorta.format(d.fecha!),
                        style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
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
                    style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
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
              formatoImportePdf(d.importe!),
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (foto != null) ...[pw.SizedBox(width: 10), miniaturaPdf(foto, size: 48)],
        ],
      ),
    );
  }

  static pw.Widget _seccionGarantias(
    Map<EstadoGarantiaPdf, List<Elemento>> porGarantia,
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
        grupo('Vigentes', pdfSuccess, porGarantia[EstadoGarantiaPdf.vigente] ?? []),
        grupo('Próximas a vencer', pdfWarningText, porGarantia[EstadoGarantiaPdf.proxima] ?? []),
        grupo('Vencidas', pdfErrorText, porGarantia[EstadoGarantiaPdf.vencida] ?? []),
      ],
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
