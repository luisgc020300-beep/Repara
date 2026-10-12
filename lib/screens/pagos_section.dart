// lib/screens/pagos_section.dart
//
// Lista de pagos de un registro, con fecha e importe a simple vista --
// tocar uno lleva al detalle completo (PagoDetailScreen). Apartado propio
// dentro del registro, separado del resumen de progreso (ver
// widgets/progreso_pago.dart).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pago.dart';
import '../services/pago_service.dart';
import '../theme/design_tokens.dart';
import 'pago_detail_screen.dart';
import 'presupuestos_section.dart' show RolEnTrabajo;

class PagosSection extends StatelessWidget {
  const PagosSection({
    required this.casaId,
    required this.elementoId,
    required this.registroId,
    required this.registroTitulo,
    required this.presupuesto,
    required this.rol,
    super.key,
  });

  final String casaId;
  final String elementoId;
  final String registroId;
  final String registroTitulo;
  final double? presupuesto;
  final RolEnTrabajo rol;

  @override
  Widget build(BuildContext context) {
    final editable = rol == RolEnTrabajo.propietario;
    return StreamBuilder<List<Pago>>(
      stream: PagoService.streamPagos(casaId, elementoId, registroId),
      builder: (context, snapshot) {
        final pagos = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pagos', style: Theme.of(context).textTheme.headlineSmall),
                if (editable)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagoDetailScreen(
                          casaId: casaId,
                          elementoId: elementoId,
                          registroId: registroId,
                          registroTitulo: registroTitulo,
                          presupuesto: presupuesto,
                          editable: true,
                          conceptoSugerido: 'Pago ${pagos.length + 1}',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir pago'),
                  ),
              ],
            ),
            if (pagos.isEmpty)
              Text('Sin pagos registrados todavía.', style: TextStyle(color: context.colors.inkMuted))
            else
              ...pagos.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ReparaRadius.md),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PagoDetailScreen(
                            casaId: casaId,
                            elementoId: elementoId,
                            registroId: registroId,
                            registroTitulo: registroTitulo,
                            presupuesto: presupuesto,
                            editable: editable,
                            pago: p,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: context.colors.brandTint, borderRadius: BorderRadius.circular(ReparaRadius.sm)),
                              child: Icon(Icons.payments_outlined, size: 20, color: context.colors.brand),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.concepto?.isNotEmpty == true ? p.concepto! : DateFormat('d MMM yyyy', 'es_ES').format(p.fecha),
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (p.concepto?.isNotEmpty == true) Text(DateFormat('d MMM yyyy', 'es_ES').format(p.fecha), style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            Text('${p.importe.toStringAsFixed(2)} €', style: ReparaText.amount(context)),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
