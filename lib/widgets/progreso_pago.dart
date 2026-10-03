// lib/widgets/progreso_pago.dart
//
// Barra de progreso de cuánto se ha pagado de un trabajo frente a su
// presupuesto -- compartida entre la vista de propietario (editable) y la
// de profesional (solo lectura: se entera del pago sin tener que anotarlo
// él mismo). El precio de referencia es [Trabajo.presupuesto], da igual si
// viene de un presupuesto formal aceptado en la app o de lo que el
// propietario escribió a mano al crear el trabajo.
import 'package:flutter/material.dart';

import '../models/trabajo.dart';
import '../services/trabajo_service.dart';
import '../theme/design_tokens.dart';

class ProgresoPago extends StatelessWidget {
  const ProgresoPago({required this.casaId, required this.trabajo, required this.editable, super.key});

  final String casaId;
  final Trabajo trabajo;
  final bool editable;

  static String _formato(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _editar(BuildContext context) async {
    final ctrl = TextEditingController(text: trabajo.pagado == 0 ? '' : _formato(trabajo.pagado));
    final valor = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cuánto llevas pagado'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Importe pagado (€)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '.'))),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (valor == null || valor.isNaN || valor < 0) return;
    await TrabajoService.actualizar(casaId, trabajo.id, {'pagado': valor});
  }

  @override
  Widget build(BuildContext context) {
    final presupuesto = trabajo.presupuesto;
    if (presupuesto == null) return const SizedBox.shrink();
    final porcentaje = trabajo.porcentajePagado ?? 0;
    final completo = trabajo.pagadoCompleto;
    final colorBarra = completo ? context.colors.success : context.colors.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Pagado: ${_formato(trabajo.pagado)} € de ${_formato(presupuesto)} €',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (editable)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Editar lo pagado',
                onPressed: () => _editar(context),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: porcentaje, minHeight: 8, backgroundColor: context.colors.surfaceMuted, color: colorBarra),
        ),
        const SizedBox(height: 2),
        Text(
          completo ? 'Pagado al completo' : '${(porcentaje * 100).round()} % pagado',
          style: TextStyle(fontSize: 12, color: completo ? context.colors.success : context.colors.inkMuted),
        ),
      ],
    );
  }
}
