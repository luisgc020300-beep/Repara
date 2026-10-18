// lib/widgets/progreso_pago.dart
//
// Barra de progreso de cuánto se ha pagado de un registro frente a su
// presupuesto -- compartida entre la vista de propietario y la de
// profesional. El total pagado es la suma en vivo de la subcolección de
// pagos (ver widgets/pagos_section.dart, que es donde se editan uno a
// uno); esta barra es solo un resumen visual, nunca editable aquí. El
// precio de referencia es [Registro.presupuesto], da igual si viene de un
// presupuesto formal aceptado en la app o de lo que el propietario
// escribió a mano al crear el registro.
import 'package:flutter/material.dart';

import '../models/pago.dart';
import '../services/pago_service.dart';
import '../theme/design_tokens.dart';

class ProgresoPago extends StatelessWidget {
  const ProgresoPago({required this.casaId, required this.elementoId, required this.registroId, required this.presupuesto, super.key});

  final String casaId;
  final String elementoId;
  final String registroId;
  final double presupuesto;

  static String _formato(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pago>>(
      stream: PagoService.streamPagos(casaId, elementoId, registroId),
      builder: (context, snapshot) {
        final pagos = snapshot.data ?? [];
        final totalPagado = pagos.fold<double>(0, (acc, p) => acc + p.importe);
        final porcentaje = presupuesto <= 0 ? 0.0 : (totalPagado / presupuesto).clamp(0, 1).toDouble();
        final completo = totalPagado >= presupuesto;
        final colorEstado = completo ? context.colors.success : context.colors.brand;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Pagado', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.inkMuted)),
                const Spacer(),
                Icon(completo ? Icons.check_circle_outline : Icons.circle_outlined, size: 13, color: colorEstado),
                const SizedBox(width: 4),
                Text(
                  completo ? 'Pagado al completo' : '${(porcentaje * 100).round()} % pagado',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorEstado, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${_formato(totalPagado)} €', style: ReparaText.amount(context)),
                const SizedBox(width: 6),
                Text('de ${_formato(presupuesto)} €', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            // surfaceSunken, no surfaceMuted -- es el token pensado para la
            // pista vacía de una barra de progreso (ver design_tokens.dart),
            // antes sin usar aquí.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: porcentaje, minHeight: 8, backgroundColor: context.colors.surfaceSunken, color: colorEstado),
            ),
          ],
        );
      },
    );
  }
}
