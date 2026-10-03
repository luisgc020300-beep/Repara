// lib/screens/pagos_section.dart
//
// Lista de pagos de un trabajo, con fecha e importe a simple vista -- tocar
// uno lleva al detalle completo (PagoDetailScreen). Apartado propio dentro
// del trabajo, separado del resumen de progreso (ver widgets/progreso_pago.dart).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pago.dart';
import '../services/pago_service.dart';
import '../theme/design_tokens.dart';
import 'pago_detail_screen.dart';
import 'presupuestos_section.dart' show RolEnTrabajo;

class PagosSection extends StatelessWidget {
  const PagosSection({required this.casaId, required this.trabajoId, required this.rol, super.key});

  final String casaId;
  final String trabajoId;
  final RolEnTrabajo rol;

  @override
  Widget build(BuildContext context) {
    final editable = rol == RolEnTrabajo.propietario;
    return StreamBuilder<List<Pago>>(
      stream: PagoService.streamPagos(casaId, trabajoId),
      builder: (context, snapshot) {
        final pagos = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pagos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (editable)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PagoDetailScreen(casaId: casaId, trabajoId: trabajoId, editable: true)),
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
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text('${p.importe.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        p.concepto?.isNotEmpty == true
                            ? '${DateFormat('d MMM yyyy', 'es_ES').format(p.fecha)} · ${p.concepto}'
                            : DateFormat('d MMM yyyy', 'es_ES').format(p.fecha),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PagoDetailScreen(casaId: casaId, trabajoId: trabajoId, editable: editable, pago: p),
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
