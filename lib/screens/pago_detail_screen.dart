// lib/screens/pago_detail_screen.dart
//
// Detalle de un pago concreto de un registro, con aspecto de recibo formal
// (número, fecha, filas con regla) -- editable para el propietario (quien
// registra lo que ha pagado), solo lectura para el profesional asignado a
// ese registro (se entera de todo el detalle sin poder tocarlo). Ver
// screens/pagos_section.dart para el listado que abre esta pantalla.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pago.dart';
import '../services/analytics_service.dart';
import '../services/pago_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error.dart';

class PagoDetailScreen extends StatefulWidget {
  const PagoDetailScreen({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.registroTitulo,
    required this.presupuesto,
    required this.editable,
    this.pago,
    this.conceptoSugerido,
    super.key,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final String registroTitulo;
  /// null si el registro todavía no tiene un precio fijado -- en ese caso
  /// no hay límite contra el que comparar y se deja pagar libremente.
  final double? presupuesto;
  final bool editable;

  /// null = se está creando un pago nuevo.
  final Pago? pago;

  /// Autosugerencia de concepto ("Pago 2") al crear uno nuevo -- menos
  /// tecleo repetido, siempre editable antes de guardar (auditoría de
  /// producto, octubre 2026). Se ignora si ya se está editando un pago
  /// existente con su propio concepto.
  final String? conceptoSugerido;

  @override
  State<PagoDetailScreen> createState() => _PagoDetailScreenState();
}

class _PagoDetailScreenState extends State<PagoDetailScreen> {
  late DateTime _fecha = widget.pago?.fecha ?? DateTime.now();
  late final _importeCtrl = TextEditingController(text: widget.pago == null ? '' : _formato(widget.pago!.importe));
  late final _conceptoCtrl = TextEditingController(text: widget.pago?.concepto ?? widget.conceptoSugerido ?? '');
  late final _descripcionCtrl = TextEditingController(text: widget.pago?.descripcion ?? '');
  late MetodoPago? _metodo = widget.pago?.metodo;
  bool _guardando = false;

  static String _formato(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String get _numeroRecibo => widget.pago == null ? '—' : widget.pago!.id.substring(widget.pago!.id.length - 6).toUpperCase();

  @override
  void dispose() {
    _importeCtrl.dispose();
    _conceptoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    final importe = double.tryParse(_importeCtrl.text.replaceAll(',', '.'));
    if (importe == null || importe <= 0) {
      AppError.show(context, 'Introduce un importe válido.');
      return;
    }

    // No se puede pagar más de lo presupuestado -- si el profesional sube
    // el presupuesto (o se acepta uno nuevo), ese límite sube solo, porque
    // aquí siempre se compara contra el valor en vivo de trabajo.presupuesto.
    final presupuesto = widget.presupuesto;
    if (presupuesto != null) {
      final totalActual = await PagoService.totalPagado(widget.casaId, widget.elementoId, widget.registroId);
      final totalSinEste = totalActual - (widget.pago?.importe ?? 0);
      final nuevoTotal = totalSinEste + importe;
      if (nuevoTotal > presupuesto + 0.01) {
        final disponible = (presupuesto - totalSinEste).clamp(0, presupuesto);
        if (mounted) {
          AppError.show(
            context,
            'Ese importe supera el presupuesto (${presupuesto.toStringAsFixed(2)} €). '
            'Como mucho puedes registrar ${disponible.toStringAsFixed(2)} € en este pago.',
          );
        }
        return;
      }
    }

    setState(() => _guardando = true);
    final pago = Pago(
      id: widget.pago?.id ?? '',
      fecha: _fecha,
      importe: importe,
      concepto: _conceptoCtrl.text.trim().isEmpty ? null : _conceptoCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
      metodo: _metodo,
    );
    try {
      if (widget.pago == null) {
        await PagoService.crear(widget.casaId, widget.elementoId, widget.registroId, pago);
        unawaited(AnalyticsService.paymentCreated(importe: importe));
      } else {
        await PagoService.actualizar(widget.casaId, widget.elementoId, widget.registroId, widget.pago!.id, pago);
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo guardar el pago.', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await AppDialog.confirmText(context, title: '¿Eliminar este pago?', confirmLabel: 'Eliminar');
    if (!confirmar) return;
    try {
      await PagoService.eliminar(widget.casaId, widget.elementoId, widget.registroId, widget.pago!.id);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) AppError.show(context, 'No se pudo eliminar el pago.', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(widget.pago == null ? 'Nuevo pago' : 'Detalle del pago'),
        actions: [
          if (widget.editable && widget.pago != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar pago', onPressed: _eliminar),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [_tarjetaRecibo(context)],
      ),
      bottomNavigationBar: !widget.editable
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ),
            ),
    );
  }

  // Borde superior perforado, como un tique arrancado de un talonario
  // (octubre 2026, pasada de craft) -- el detalle de marca más literal que
  // tiene la app: Repara es un documento real, no un dato suelto.
  Widget _tarjetaRecibo(BuildContext context) {
    return PhysicalShape(
      clipper: const _ReciboScallopClipper(),
      color: context.colors.surface,
      elevation: 10,
      shadowColor: context.colors.ink,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: título "RECIBO" + icono a la izquierda, número y fecha
            // a la derecha -- mismo esquema que un recibo de papel real.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.receipt_long_outlined, color: context.colors.brand, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECIBO',
                        style: TextStyle(fontFamily: ReparaText.fontFamily, color: context.colors.brand, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 0.4),
                      ),
                      Text(widget.registroTitulo, style: TextStyle(color: context.colors.inkMuted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Nº $_numeroRecibo', style: TextStyle(color: context.colors.inkMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    widget.editable
                        ? InkWell(
                            onTap: _elegirFecha,
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('d MMM yyyy', 'es_ES').format(_fecha),
                                  style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.edit_calendar_outlined, size: 14, color: context.colors.inkMuted),
                              ],
                            ),
                          )
                        : Text(
                            DateFormat('d MMM yyyy', 'es_ES').format(_fecha),
                            style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _LineaPunteada(),
            const SizedBox(height: 18),

            // Cantidad recibida -- la fila más importante del recibo.
            _filaEtiqueta(context, 'CANTIDAD RECIBIDA'),
            const SizedBox(height: 6),
            widget.editable
                ? TextField(
                    controller: _importeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontFamily: ReparaText.fontFamily, color: context.colors.brand, fontSize: 40, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      hintText: '0',
                      suffixText: ' €',
                      suffixStyle: TextStyle(fontFamily: ReparaText.fontFamily, color: context.colors.brand, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  )
                : Text(
                    '${_formato(widget.pago!.importe)} €',
                    style: TextStyle(fontFamily: ReparaText.fontFamily, color: context.colors.brand, fontSize: 40, fontWeight: FontWeight.w700),
                  ),
            const SizedBox(height: 14),
            const _LineaPunteada(),
            const SizedBox(height: 14),

            _filaEtiqueta(context, 'PARA EL PAGO DE'),
            const SizedBox(height: 6),
            widget.editable
                ? TextField(
                    controller: _conceptoCtrl,
                    decoration: const InputDecoration(isDense: true, filled: false, border: InputBorder.none, hintText: 'p.ej. Primer pago · 50%'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  )
                : Text(
                    widget.pago!.concepto?.isNotEmpty == true ? widget.pago!.concepto! : 'Sin concepto',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
            const SizedBox(height: 14),
            const _LineaPunteada(),
            const SizedBox(height: 14),

            _filaEtiqueta(context, 'MÉTODO DE PAGO'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MetodoPago.values.map((m) {
                final seleccionado = _metodo == m;
                return ChoiceChip(
                  label: Text(_nombreMetodo(m)),
                  selected: seleccionado,
                  onSelected: widget.editable ? (_) => setState(() => _metodo = seleccionado ? null : m) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const _LineaPunteada(),
            const SizedBox(height: 14),

            _filaEtiqueta(context, 'DESCRIPCIÓN (OPCIONAL)'),
            const SizedBox(height: 6),
            widget.editable
                ? TextField(
                    controller: _descripcionCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(isDense: true, filled: false, border: InputBorder.none, hintText: 'Notas sobre este pago'),
                  )
                : Text(
                    widget.pago!.descripcion?.isNotEmpty == true ? widget.pago!.descripcion! : 'Sin descripción',
                    style: TextStyle(color: context.colors.inkMuted),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _filaEtiqueta(BuildContext context, String texto) {
    return Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.inkMuted, letterSpacing: 0.6));
  }
}

/// Separador punteado -- el recibo de papel real usa líneas de puntos para
/// marcar dónde se dobla o se corta, nunca una regla sólida continua.
class _LineaPunteada extends StatelessWidget {
  const _LineaPunteada();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashedPainter(color: context.colors.surfaceSunken)),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dashWidth = 5.0;
    const dashGap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) => oldDelegate.color != color;
}

/// Recorta el borde superior de la tarjeta en pequeñas muescas semicirculares
/// -- el "diente de sello" de un tique real arrancado de un talonario.
/// PhysicalShape (no solo ClipPath) para que la sombra siga también la
/// silueta recortada en vez de ser un rectángulo.
class _ReciboScallopClipper extends CustomClipper<Path> {
  const _ReciboScallopClipper();

  static const double notchRadius = 7;
  static const double notchSpacing = 22;
  static const double cornerRadius = 20;

  @override
  Path getClip(Size size) {
    final notchCount = (size.width / notchSpacing).floor().clamp(3, 200);
    final spacing = size.width / notchCount;
    final path = Path()..moveTo(0, 0);
    for (var i = 0; i < notchCount; i++) {
      final cx = spacing * i + spacing / 2;
      path
        ..lineTo(cx - notchRadius, 0)
        ..quadraticBezierTo(cx, notchRadius * 1.6, cx + notchRadius, 0);
    }
    path
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cornerRadius)
      ..arcToPoint(Offset(size.width - cornerRadius, size.height), radius: Radius.circular(cornerRadius))
      ..lineTo(cornerRadius, size.height)
      ..arcToPoint(Offset(0, size.height - cornerRadius), radius: Radius.circular(cornerRadius))
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

String _nombreMetodo(MetodoPago m) => switch (m) {
      MetodoPago.bizum => 'Bizum',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.tarjeta => 'Tarjeta',
      MetodoPago.otro => 'Otro',
    };
