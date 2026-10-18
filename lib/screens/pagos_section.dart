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
import '../widgets/app_error.dart';
import '../widgets/ios_list.dart';
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
              const EmptyHint(message: 'Sin pagos registrados todavía.', icon: Icons.payments_outlined)
            else
              IosSection(
                rows: pagos
                    .map((p) => IosRow(
                          icon: Icons.payments_outlined,
                          iconColor: context.colors.brand,
                          title: p.concepto?.isNotEmpty == true ? p.concepto! : DateFormat('d MMM yyyy', 'es_ES').format(p.fecha),
                          subtitle: p.concepto?.isNotEmpty == true ? DateFormat('d MMM yyyy', 'es_ES').format(p.fecha) : null,
                          trailing: Text('${p.importe.toStringAsFixed(2)} €', style: ReparaText.amount(context)),
                          showChevron: false,
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
                        ))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}
