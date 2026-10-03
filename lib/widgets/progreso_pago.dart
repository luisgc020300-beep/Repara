// lib/widgets/progreso_pago.dart
//
// Barra de progreso de cuánto se ha pagado de un trabajo frente a su
// presupuesto -- compartida entre la vista de propietario y la de
// profesional. El total pagado es la suma en vivo de la subcolección de
// pagos (ver widgets/pagos_section.dart, que es donde se editan uno a
// uno); esta barra es solo un resumen visual, nunca editable aquí. El
// precio de referencia es [Trabajo.presupuesto], da igual si viene de un
// presupuesto formal aceptado en la app o de lo que el propietario
// escribió a mano al crear el trabajo.
import 'package:flutter/material.dart';

import '../models/pago.dart';
import '../services/pago_service.dart';
import '../theme/design_tokens.dart';

class ProgresoPago extends StatelessWidget {
  const ProgresoPago({required this.casaId, required this.trabajoId, required this.presupuesto, super.key});

  final String casaId;
  final String trabajoId;
  final double presupuesto;

  static String _formato(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pago>>(
      stream: PagoService.streamPagos(casaId, trabajoId),
      builder: (context, snapshot) {
        final pagos = snapshot.data ?? [];
        final totalPagado = pagos.fold<double>(0, (acc, p) => acc + p.importe);
        final porcentaje = presupuesto <= 0 ? 0.0 : (totalPagado / presupuesto).clamp(0, 1).toDouble();
        final completo = totalPagado >= presupuesto;
        final colorBarra = completo ? context.colors.success : context.colors.brand;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pagado: ${_formato(totalPagado)} € de ${_formato(presupuesto)} €',
              style: const TextStyle(fontWeight: FontWeight.w600),
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
      },
    );
  }
}
