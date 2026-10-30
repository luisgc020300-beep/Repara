// lib/widgets/pdf_trabajo.dart
//
// Ficha de un trabajo (Registro) dentro de un PDF (CEO, octubre 2026) --
// extraído de expediente_vivienda_pdf.dart para que la ficha de un
// elemento (su propio historial completo) reutilice exactamente la misma
// tarjeta: estado real, importe acordado/pagado/saldo, cada pago
// individual y los cambios de alcance. Nunca confunde un presupuesto con
// un pago ni un pago con que el trabajo esté terminado -- cada dato sale
// directo del modelo real.
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cambio_alcance.dart';
import '../models/pago.dart';
import '../models/registro.dart';
import 'estado_registro_chip.dart' show nombreEstadoRegistro;
import 'pdf_estilo.dart';

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

pw.Widget galeriaTrabajoPdf(
  TrabajoConDetalle t,
  Map<String, Uint8List> imagenes, {
  bool mostrarElemento = true,
  int maxFotos = 2,
}) {
  final fotos = t.registro.fotos
      .take(maxFotos)
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
          mostrarElemento
              ? '${t.registro.titulo} · ${t.registro.elementoNombre}'
              : t.registro.titulo,
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
