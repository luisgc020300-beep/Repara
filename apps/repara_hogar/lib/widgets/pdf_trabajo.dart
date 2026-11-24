// lib/widgets/pdf_trabajo.dart
//
// Ficha de un trabajo (Registro) dentro de un PDF (CEO, octubre 2026) --
// extraído de expediente_vivienda_pdf.dart para que la ficha de un
// elemento (su propio historial completo) reutilice exactamente la misma
// tarjeta: estado real, importe acordado/pagado/saldo, cada pago
// individual y los cambios de alcance. Nunca confunde un presupuesto con
// un pago ni un pago con que el trabajo esté terminado -- cada dato sale
// directo del modelo real.
//
// Rediseño documental (CEO, noviembre 2026, "PDF de expediente completo de
// un elemento"): la tarjeta pasa de una única línea de texto con los
// importes separados por "·" a una composición con jerarquía real --
// descripción propia, mini-resumen económico de tres cifras y los pagos
// como una tabla, no como viñetas sueltas. Mismo criterio en todo:
// ningún campo vacío se muestra, nunca se inventa nada que no esté en el
// modelo.
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:repara_core/cambio_alcance.dart';
import 'package:repara_core/pago.dart';
import 'package:repara_core/registro.dart';

import 'package:repara_ui/estado_registro_chip.dart' show nombreEstadoRegistro;
import 'package:repara_ui/pdf_estilo.dart';

String nombreMetodoPagoPdf(MetodoPago? m) => switch (m) {
  MetodoPago.bizum => 'Bizum',
  MetodoPago.transferencia => 'Transferencia',
  MetodoPago.efectivo => 'Efectivo',
  MetodoPago.tarjeta => 'Tarjeta',
  MetodoPago.otro => 'Otro',
  null => '',
};

enum EstadoGarantiaPdf { vigente, proxima, vencida, desconocida }

EstadoGarantiaPdf clasificarGarantiaPdf(DateTime? hasta) {
  if (hasta == null) return EstadoGarantiaPdf.desconocida;
  final ahora = DateTime.now();
  if (hasta.isBefore(ahora)) return EstadoGarantiaPdf.vencida;
  if (hasta.isBefore(ahora.add(const Duration(days: 30)))) {
    return EstadoGarantiaPdf.proxima;
  }
  return EstadoGarantiaPdf.vigente;
}

// pdf.Image solo decodifica formatos raster estándar -- un documento subido
// como PDF (o cualquier extensión que no reconozcamos) nunca se "incrusta"
// como si fuera una foto, solo se identifica con una ficha.
bool esImagenEmbebiblePdf(String nombreArchivo) {
  final partes = nombreArchivo.toLowerCase().split('.');
  final ext = partes.isEmpty ? null : partes.last;
  return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
}

/// Tres grupos de estado (CEO, noviembre 2026: "debe poder distinguirse
/// rápidamente entre un trabajo terminado, uno en curso y uno que todavía
/// requiere alguna actuación") -- nunca un estado nuevo, solo una
/// agrupación visual de los ya existentes en [EstadoRegistro]. Mismo
/// criterio que [montoDebidoRegistro]: una sola función, nunca un switch
/// repetido en cada sitio que pinta un estado.
PdfColor colorEstadoRegistroPdf(EstadoRegistro e) => switch (e) {
  EstadoRegistro.terminado || EstadoRegistro.archivado => pdfSuccess,
  EstadoRegistro.pendienteConfirmacion ||
  EstadoRegistro.pendientePago => pdfWarningText,
  EstadoRegistro.nuevo ||
  EstadoRegistro.presupuestado ||
  EstadoRegistro.enCurso => pdfBrand,
};

/// Un trabajo (Registro) con sus pagos y cambios de alcance ya resueltos --
/// agregado por quien llama (la pantalla, nunca este fichero): aquí solo se
/// maqueta, nunca se decide qué leer de Firestore.
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

pw.Widget _filaEtiquetaValor(String etiqueta, String valor) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 70,
        child: pw.Text(
          etiqueta,
          style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
        ),
      ),
      pw.Expanded(
        child: pw.Text(valor, style: const pw.TextStyle(fontSize: 9)),
      ),
    ],
  ),
);

/// Tarjeta ORIGINAL -- intacta, sigue siendo la que usa
/// expediente_vivienda_pdf.dart (no tocado en este rediseño: alcance
/// acotado al expediente de un elemento, ver fichaTrabajoDocumentalPdf más
/// abajo para la versión rediseñada).
pw.Widget fichaTrabajoPdf(
  TrabajoConDetalle t, {
  required DateFormat formatoFechaCorta,
  bool mostrarElemento = true,
}) {
  final r = t.registro;
  final monto = montoDebidoRegistro(r);
  final estadoColor = switch (r.estado) {
    EstadoRegistro.terminado || EstadoRegistro.archivado => pdfSuccess,
    EstadoRegistro.pendientePago => pdfWarningText,
    _ => pdfInkMuted,
  };
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: pdfBorder),
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
            etiquetaPdf(nombreEstadoRegistro(r.estado), estadoColor),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          mostrarElemento
              ? '${r.elementoNombre} · ${formatoFechaCorta.format(r.fecha)}'
              : formatoFechaCorta.format(r.fecha),
          style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
        ),
        if (r.profesionalNombre != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'Profesional: ${r.profesionalNombre}',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
          ),
        ],
        if (monto != null || t.pagos.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            [
              if (monto != null) 'Acordado: ${formatoImportePdf(monto)}',
              if (t.pagos.isNotEmpty) 'Pagado: ${formatoImportePdf(t.totalPagado)}',
              if (monto != null)
                'Saldo: ${formatoImportePdf((monto - t.totalPagado).clamp(0, double.infinity))}',
            ].join('  ·  '),
            style: const pw.TextStyle(fontSize: 9.5, color: pdfInk),
          ),
        ],
        for (final p in t.pagos) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            '· ${formatoFechaCorta.format(p.fecha)}'
            '${p.concepto != null ? ' -- ${p.concepto}' : ''}'
            '${p.metodo != null ? ' (${nombreMetodoPagoPdf(p.metodo)})' : ''}'
            ': ${formatoImportePdf(p.importe)}',
            style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
          ),
        ],
        for (final c in t.cambios) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            '+ Cambio de alcance: ${c.titulo}'
            '${c.importeAdicional != null ? ' (${formatoImportePdf(c.importeAdicional!)})' : ''}'
            ' -- ${switch (c.estado) {
              EstadoCambioAlcance.aprobado => 'aprobado',
              EstadoCambioAlcance.rechazado => 'rechazado',
              EstadoCambioAlcance.cancelado => 'cancelado',
              EstadoCambioAlcance.pendiente => 'pendiente',
            }}',
            style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
          ),
        ],
      ],
    ),
  );
}

/// Tarjeta REDISEÑADA (CEO, noviembre 2026, expediente de elemento) -- solo
/// la usa elemento_resumen_pdf.dart. Descripción propia, mini-resumen
/// económico de tres cifras y pagos como tabla en vez de una línea de texto
/// con todo junto.
pw.Widget fichaTrabajoDocumentalPdf(
  TrabajoConDetalle t, {
  required DateFormat formatoFechaCorta,
  bool mostrarElemento = true,
}) {
  final r = t.registro;
  final monto = montoDebidoRegistro(r);
  final hayEconomia = monto != null || t.pagos.isNotEmpty;
  final saldo = monto == null
      ? null
      : (monto - t.totalPagado).clamp(0, double.infinity).toDouble();
  final profesionales = r.listaProfesionales.map((p) => p.nombre).join(', ');

  return pw.Container(
    padding: const pw.EdgeInsets.all(13),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: pdfBorder),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // -- Cabecera: tipo + título a la izquierda, estado a la derecha --
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    nombreTipoRegistro(r.tipo).toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: pdfInkMuted,
                      letterSpacing: 0.6,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    r.titulo,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            etiquetaPdf(
              nombreEstadoRegistro(r.estado),
              colorEstadoRegistroPdf(r.estado),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          mostrarElemento
              ? '${r.elementoNombre} · ${formatoFechaCorta.format(r.fecha)}'
              : formatoFechaCorta.format(r.fecha),
          style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
        ),
        if (profesionales.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'Profesional: $profesionales',
            style: const pw.TextStyle(fontSize: 9, color: pdfInkMuted),
          ),
        ],

        // -- Descripción del trabajo, si la hay (antes nunca se mostraba) --
        if (r.descripcion != null && r.descripcion!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 7),
          pw.Text(
            r.descripcion!.trim(),
            style: const pw.TextStyle(fontSize: 9, color: pdfInk),
          ),
        ],

        // -- Mini-resumen económico de tres cifras, nunca una sola línea de
        // texto con los tres importes pegados (CEO, noviembre 2026). --
        if (hayEconomia) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: pdfBrandTint,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                if (monto != null)
                  pw.Expanded(
                    child: celdaDatoPdf(
                      etiqueta: 'Acordado',
                      valor: formatoImportePdf(monto),
                      tamanoValor: 10,
                    ),
                  ),
                if (t.pagos.isNotEmpty)
                  pw.Expanded(
                    child: celdaDatoPdf(
                      etiqueta: 'Pagado',
                      valor: formatoImportePdf(t.totalPagado),
                      tamanoValor: 10,
                      colorValor: pdfSuccess,
                    ),
                  ),
                if (saldo != null)
                  pw.Expanded(
                    child: celdaDatoPdf(
                      etiqueta: 'Saldo',
                      valor: formatoImportePdf(saldo),
                      tamanoValor: 10,
                      colorValor: saldo > 0 ? pdfWarningText : pdfInkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],

        // -- Pagos, como tabla (fecha · concepto/método · importe) en vez
        // de una viñeta de texto por pago. --
        if (t.pagos.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(62),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(60),
            },
            children: [
              for (final p in t.pagos)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text(
                        formatoFechaCorta.format(p.fecha),
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: pdfInkMuted,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text(
                        [
                          if (p.concepto != null) p.concepto!,
                          if (p.metodo != null) nombreMetodoPagoPdf(p.metodo),
                        ].join(' · '),
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: pdfInkMuted,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text(
                        formatoImportePdf(p.importe),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],

        // -- Cambios de alcance --
        if (t.cambios.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          for (final c in t.cambios)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _filaEtiquetaValor(
                      'Cambio',
                      '${c.titulo}'
                          '${c.importeAdicional != null ? ' (${formatoImportePdf(c.importeAdicional!)})' : ''}',
                    ),
                  ),
                  etiquetaPdf(
                    switch (c.estado) {
                      EstadoCambioAlcance.aprobado => 'Aprobado',
                      EstadoCambioAlcance.rechazado => 'Rechazado',
                      EstadoCambioAlcance.cancelado => 'Cancelado',
                      EstadoCambioAlcance.pendiente => 'Pendiente',
                    },
                    switch (c.estado) {
                      EstadoCambioAlcance.aprobado => pdfSuccess,
                      EstadoCambioAlcance.rechazado => pdfErrorText,
                      EstadoCambioAlcance.cancelado => pdfInkMuted,
                      EstadoCambioAlcance.pendiente => pdfWarningText,
                    },
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

/// Grupo fotográfico de un trabajo. [formatoFechaCorta] es opcional y
/// **deliberadamente retrocompatible**: si no se pasa (como sigue haciendo
/// expediente_vivienda_pdf.dart, sin tocar), se renderiza exactamente igual
/// que antes -- solo el nombre del trabajo, sin línea de fecha/profesional
/// ni separador inferior. Al pasarlo (ficha de elemento, rediseño CEO
/// noviembre 2026) se añade esa línea de contexto y un separador sutil
/// entre intervenciones, envuelto en un único [pw.Container] para que el
/// motor de paginación nunca separe la cabecera de sus fotos entre páginas.
pw.Widget galeriaTrabajoPdf(
  TrabajoConDetalle t,
  Map<String, Uint8List> imagenes, {
  bool mostrarElemento = true,
  int maxFotos = 6,
  DateFormat? formatoFechaCorta,
}) {
  final fotos = t.registro.fotos
      .take(maxFotos)
      .map((url) => imagenes[url])
      .whereType<Uint8List>()
      .toList();
  if (fotos.isEmpty) return pw.SizedBox();
  final profesionales = t.registro.listaProfesionales
      .map((p) => p.nombre)
      .join(', ');
  final titulo = pw.Text(
    mostrarElemento
        ? '${t.registro.titulo} · ${t.registro.elementoNombre}'
        : t.registro.titulo,
    style: pw.TextStyle(
      fontSize: formatoFechaCorta != null ? 10.5 : 10,
      fontWeight: pw.FontWeight.bold,
    ),
  );
  final fotosWrap = pw.Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final f in fotos)
        pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: pw.Image(
            pw.MemoryImage(f),
            width: 157,
            height: 118,
            fit: pw.BoxFit.cover,
          ),
        ),
    ],
  );
  if (formatoFechaCorta == null) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [titulo, pw.SizedBox(height: 6), fotosWrap],
      ),
    );
  }
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    padding: const pw.EdgeInsets.only(bottom: 14),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: pdfBorder, width: 0.5)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        titulo,
        pw.SizedBox(height: 2),
        pw.Text(
          [
            formatoFechaCorta.format(t.registro.fecha),
            if (profesionales.isNotEmpty) profesionales,
          ].join(' · '),
          style: const pw.TextStyle(fontSize: 8.5, color: pdfInkMuted),
        ),
        pw.SizedBox(height: 7),
        fotosWrap,
      ],
    ),
  );
}
