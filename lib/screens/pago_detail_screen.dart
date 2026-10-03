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
        children: [
          soloLectura ? _cabeceraSoloLectura(context) : _cabeceraEditable(context),
          const SizedBox(height: 24),
          _seccion(context, 'Detalles'),
          const SizedBox(height: 8),
          soloLectura ? _tarjetaSoloLectura(context) : _tarjetaEditable(context),
        ],
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

  // Tarjeta tipo "recibo" -- el importe es lo primero que se ve, como en un
  // justificante real, en vez de un campo de texto más entre otros.
  Widget _cabeceraEditable(BuildContext context) {
    return _TarjetaRecibo(
      child: Column(
        children: [
          Icon(Icons.payments_outlined, color: context.colors.brandOn, size: 26),
          const SizedBox(height: 10),
          IntrinsicWidth(
            child: TextField(
              controller: _importeCtrl,
              autofocus: widget.pago == null,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: context.colors.brandOn, fontSize: 40, fontWeight: FontWeight.w800, height: 1),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: context.colors.brandOn.withValues(alpha: 0.4)),
                suffixText: ' €',
                suffixStyle: TextStyle(color: context.colors.brandOn.withValues(alpha: 0.85), fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _elegirFecha,
            style: TextButton.styleFrom(foregroundColor: context.colors.brandOn.withValues(alpha: 0.9)),
            icon: const Icon(Icons.calendar_today_outlined, size: 14),
            label: Text(DateFormat('d MMMM yyyy', 'es_ES').format(_fecha), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _cabeceraSoloLectura(BuildContext context) {
    final p = widget.pago!;
    return _TarjetaRecibo(
      child: Column(
        children: [
          Icon(Icons.payments_outlined, color: context.colors.brandOn, size: 26),
          const SizedBox(height: 10),
          Text('${_formato(p.importe)} €', style: TextStyle(color: context.colors.brandOn, fontSize: 40, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            DateFormat('d MMMM yyyy', 'es_ES').format(p.fecha),
            style: TextStyle(color: context.colors.brandOn.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaEditable(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _filaConIcono(
            context,
            icono: Icons.account_balance_wallet_outlined,
            child: DropdownButtonFormField<MetodoPago?>(
              initialValue: _metodo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Método', border: InputBorder.none, filled: false, isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin especificar')),
                ...MetodoPago.values.map((m) => DropdownMenuItem(value: m, child: Text(_nombreMetodo(m)))),
              ],
              onChanged: (v) => setState(() => _metodo = v),
            ),
          ),
          Divider(height: 1, indent: 52, color: context.colors.inkMuted.withValues(alpha: 0.15)),
          _filaConIcono(
            context,
            icono: Icons.short_text_outlined,
            child: TextField(
              controller: _conceptoCtrl,
              decoration: const InputDecoration(
                labelText: 'Concepto',
                hintText: 'p.ej. Primer pago · 50%',
                border: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          Divider(height: 1, indent: 52, color: context.colors.inkMuted.withValues(alpha: 0.15)),
          _filaConIcono(
            context,
            icono: Icons.notes_outlined,
            child: TextField(
              controller: _descripcionCtrl,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: InputBorder.none, filled: false, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSoloLectura(BuildContext context) {
    final p = widget.pago!;
    return Card(
      child: Column(
        children: [
          _filaConIcono(context, icono: Icons.account_balance_wallet_outlined, child: _textoFila(context, 'Método', p.metodo != null ? _nombreMetodo(p.metodo!) : 'Sin especificar')),
          Divider(height: 1, indent: 52, color: context.colors.inkMuted.withValues(alpha: 0.15)),
          _filaConIcono(context, icono: Icons.short_text_outlined, child: _textoFila(context, 'Concepto', p.concepto ?? 'Sin concepto')),
          Divider(height: 1, indent: 52, color: context.colors.inkMuted.withValues(alpha: 0.15)),
          _filaConIcono(context, icono: Icons.notes_outlined, child: _textoFila(context, 'Descripción', p.descripcion ?? 'Sin descripción')),
        ],
      ),
    );
  }

  Widget _filaConIcono(BuildContext context, {required IconData icono, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icono, size: 20, color: context.colors.inkMuted),
          const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _textoFila(BuildContext context, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.colors.inkMuted)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TarjetaRecibo extends StatelessWidget {
  const _TarjetaRecibo({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(color: context.colors.brand, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}

Widget _seccion(BuildContext context, String titulo) => Text(
      titulo,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: context.colors.brand),
    );

String _nombreMetodo(MetodoPago m) => switch (m) {
      MetodoPago.bizum => 'Bizum',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.tarjeta => 'Tarjeta',
      MetodoPago.otro => 'Otro',
    };
