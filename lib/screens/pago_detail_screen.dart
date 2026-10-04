// lib/screens/pago_detail_screen.dart
//
// Detalle de un pago concreto de un trabajo, con aspecto de recibo formal
// (número, fecha, filas con regla) -- editable para el propietario (quien
// registra lo que ha pagado), solo lectura para el profesional asignado a
// ese trabajo (se entera de todo el detalle sin poder tocarlo). Ver
// screens/pagos_section.dart para el listado que abre esta pantalla.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pago.dart';
import '../services/pago_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';

class PagoDetailScreen extends StatefulWidget {
  const PagoDetailScreen({
    required this.casaId,
    required this.trabajoId,
    required this.trabajoTitulo,
    required this.editable,
    this.pago,
    super.key,
  });

  final String casaId;
  final String trabajoId;
  final String trabajoTitulo;
  final bool editable;

  /// null = se está creando un pago nuevo.
  final Pago? pago;

  @override
  State<PagoDetailScreen> createState() => _PagoDetailScreenState();
}

class _PagoDetailScreenState extends State<PagoDetailScreen> {
  late DateTime _fecha = widget.pago?.fecha ?? DateTime.now();
  late final _importeCtrl = TextEditingController(text: widget.pago == null ? '' : _formato(widget.pago!.importe));
  late final _conceptoCtrl = TextEditingController(text: widget.pago?.concepto ?? '');
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
        await PagoService.crear(widget.casaId, widget.trabajoId, pago);
      } else {
        await PagoService.actualizar(widget.casaId, widget.trabajoId, widget.pago!.id, pago);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo guardar el pago.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar este pago?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await PagoService.eliminar(widget.casaId, widget.trabajoId, widget.pago!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppError.show(context, 'No se pudo eliminar el pago.');
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
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _eliminar),
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

  Widget _tarjetaRecibo(BuildContext context) {
    final lineaColor = context.colors.inkMuted.withValues(alpha: 0.18);
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lineaColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: título "RECIBO" + icono a la izquierda, número y fecha
          // a la derecha -- mismo esquema que un recibo de papel real.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.receipt_long_outlined, color: context.colors.brand, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECIBO',
                      style: TextStyle(color: context.colors.brand, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.2),
                    ),
                    Text(widget.trabajoTitulo, style: TextStyle(color: context.colors.inkMuted, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Nº $_numeroRecibo', style: TextStyle(color: context.colors.inkMuted, fontSize: 12, fontWeight: FontWeight.w600)),
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
          Divider(height: 1, thickness: 1.2, color: lineaColor),
          const SizedBox(height: 18),

          // Cantidad recibida -- la fila más importante del recibo.
          _filaEtiqueta(context, 'CANTIDAD RECIBIDA'),
          const SizedBox(height: 6),
          widget.editable
              ? TextField(
                  controller: _importeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colors.brand, fontSize: 32, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    hintText: '0',
                    suffixText: ' €',
                    suffixStyle: TextStyle(color: context.colors.brand, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                )
              : Text('${_formato(widget.pago!.importe)} €', style: TextStyle(color: context.colors.brand, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Divider(height: 1, color: lineaColor),
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
          Divider(height: 1, color: lineaColor),
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
          Divider(height: 1, color: lineaColor),
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
    );
  }

  Widget _filaEtiqueta(BuildContext context, String texto) {
    return Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.inkMuted, letterSpacing: 0.6));
  }
}

String _nombreMetodo(MetodoPago m) => switch (m) {
      MetodoPago.bizum => 'Bizum',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.tarjeta => 'Tarjeta',
      MetodoPago.otro => 'Otro',
    };
