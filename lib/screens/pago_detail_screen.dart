// lib/screens/pago_detail_screen.dart
//
// Detalle de un pago concreto de un trabajo -- editable para el propietario
// (quien registra lo que ha pagado), solo lectura para el profesional
// asignado a ese trabajo (se entera de todo el detalle sin poder tocarlo).
// Ver screens/pagos_section.dart para el listado que abre esta pantalla.
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
    required this.editable,
    this.pago,
    super.key,
  });

  final String casaId;
  final String trabajoId;
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
    final soloLectura = !widget.editable;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pago == null ? 'Nuevo pago' : 'Detalle del pago'),
        actions: [
          if (widget.editable && widget.pago != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _eliminar),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: soloLectura ? _vistaSoloLectura(context) : _formularioEditable(),
      ),
      bottomNavigationBar: soloLectura
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

  List<Widget> _formularioEditable() => [
        OutlinedButton.icon(
          onPressed: _elegirFecha,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text('${_fecha.day}/${_fecha.month}/${_fecha.year}'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _importeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.w700),
          decoration: const InputDecoration(labelText: 'Importe pagado (€)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MetodoPago?>(
          initialValue: _metodo,
          decoration: const InputDecoration(labelText: 'Método (opcional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin especificar')),
            ...MetodoPago.values.map((m) => DropdownMenuItem(value: m, child: Text(_nombreMetodo(m)))),
          ],
          onChanged: (v) => setState(() => _metodo = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: _conceptoCtrl, decoration: const InputDecoration(labelText: 'Concepto (p.ej. Primer pago · 50%)')),
        const SizedBox(height: 12),
        TextField(
          controller: _descripcionCtrl,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
        ),
      ];

  List<Widget> _vistaSoloLectura(BuildContext context) {
    final p = widget.pago!;
    return [
      _Fila(label: 'Fecha', valor: DateFormat('d MMMM yyyy', 'es_ES').format(p.fecha)),
      _Fila(label: 'Importe', valor: '${_formato(p.importe)} €'),
      if (p.metodo != null) _Fila(label: 'Método', valor: _nombreMetodo(p.metodo!)),
      if (p.concepto != null) _Fila(label: 'Concepto', valor: p.concepto!),
      if (p.descripcion != null) _Fila(label: 'Descripción', valor: p.descripcion!),
    ];
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.colors.inkMuted)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _nombreMetodo(MetodoPago m) => switch (m) {
      MetodoPago.bizum => 'Bizum',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.tarjeta => 'Tarjeta',
      MetodoPago.otro => 'Otro',
    };
